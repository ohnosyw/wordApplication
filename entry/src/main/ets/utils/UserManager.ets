// entry/src/main/ets/utils/UserManager.ets
import preferences from '@ohos.data.preferences';
import promptAction from '@ohos.promptAction';
import { PlanData } from '../model/StudyPlan';
import { ProgressManager } from './ProgressManager';

// 已完成词书的数据结构
export interface CompletedBookInfo {
  bookId: string;
  bookName: string;
  totalWords: number;
}

// 用户全量信息表
export interface UserInfo {
  userId: string;
  username: string;
  password: string;
  checkInDays: number;
  totalWords: number;
  lastStudyDate?: string;// 记录最后一次背词的日期
  todayStudiedCount?: number;// 今日已背总数
  todayTarget?: number;// 今日目标总数
  todayTargetNew?: number;// 今日目标新词
  todayTargetReview?: number;// 今日目标复习
  todayStudiedNew?: number;// 今日已背新词
  todayStudiedReview?: number;// 今日已重复习

  continuousCheckInDays?: number;// 连续打卡天数
  lastCheckInDate?: string;// 最后一次打卡的日期
  completedBooks?: CompletedBookInfo[];// 完本记录字典

  currentStudyBookId?: string;// 当前正在背的词书
}

export class UserManager {

  // 定义各种 Preferences 数据库的文件名和常量 Key
  private static PREF_NAME = 'UserDatabase';
  private static PROGRESS_DB_NAME = 'WordMemoryDB';
  private static COLLECTION_DB_NAME = 'UserCollections';
  private static KEY_USERS = 'AllUsers';
  private static KEY_CURRENT = 'CurrentUserId';

  // 同步用户信息到全局缓存（AppStorage）
  static syncUserToAppStorage(user: UserInfo | null): void {
    if (user) {
      let safeUserStr = JSON.stringify(user);
      let safeUser = JSON.parse(safeUserStr) as UserInfo;
      AppStorage.setOrCreate('currentUser', safeUser);
      // 计算并缓存已完成的词书数量
      let booksCount = safeUser.completedBooks ? safeUser.completedBooks.length : 0;
      AppStorage.setOrCreate('completedBooksCount', booksCount);
    } else {
      AppStorage.setOrCreate('currentUser', null);
      AppStorage.setOrCreate('completedBooksCount', 0);
    }
  }

  // 获取数据库中所有的注册用户
  static async getAllUsers(context: Context): Promise<Record<string, UserInfo>> {
    try {
      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      // 读取键为 KEY_USERS 的数据
      let dataStr = await pref.get(UserManager.KEY_USERS, '{}') as string;
      return JSON.parse(dataStr) as Record<string, UserInfo>;
    } catch (e) {
      let emptyUsers: Record<string, UserInfo> = {};
      return emptyUsers;
    }
  }

  // 用户注册
  static async register(context: Context, user: UserInfo): Promise<boolean> {
    let users = await UserManager.getAllUsers(context);
    if (users[user.userId]) { promptAction.showToast({ message: '该账号已存在！' }); return false; }
    // 初始化新用户数据
    user.completedBooks = [];
    // 把新用户添加到用户列表中
    users[user.userId] = user;

    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
    await pref.flush();
    return true;
  }

  // 用户登录
  static async login(context: Context, userId: string, pass: string): Promise<boolean> {
    let users = await UserManager.getAllUsers(context);
    // 根据输入的 userId 查找对应用户
    let targetUser = users[userId];

    if (!targetUser) { promptAction.showToast({ message: '账号不存在！' }); return false; }
    if (targetUser.password !== pass) { promptAction.showToast({ message: '密码错误！' }); return false; }
    // 保存当前登录的用户ID到本地存储
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(UserManager.KEY_CURRENT, userId);
    await pref.flush();

    // 同步用户信息到全局缓存
    UserManager.syncUserToAppStorage(targetUser);

    // 获取用户的学习计划，并同步到全局缓存
    let plan = await UserManager.getUserPlan(context, targetUser.userId);
    AppStorage.setOrCreate('studyPlan', plan);
    return true;
  }

  // 用户登出
  static async logout(context: Context): Promise<void> {
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.delete(UserManager.KEY_CURRENT);
    await pref.flush();

    // 清空进度管理器的内存缓存
    ProgressManager.clearMemoryCache();

    UserManager.syncUserToAppStorage(null);
    AppStorage.setOrCreate('studyPlan', null);
    AppStorage.setOrCreate('totalLearnedInBook', 0);
  }

  // 应用启动时自动登录
  static async autoLogin(context: Context): Promise<void> {
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);

    // 读取上次登录的用户ID
    let currentId = await pref.get(UserManager.KEY_CURRENT, '') as string;

    // 如果有保存的用户ID,尝试自动登录
    if (currentId !== '') {
      let users = await UserManager.getAllUsers(context);
      // 如果这个用户确实存在
      if (users[currentId]) {
        UserManager.syncUserToAppStorage(users[currentId]);
        let plan = await UserManager.getUserPlan(context, currentId);
        AppStorage.setOrCreate('studyPlan', plan);
      }
    }
  }

  // 更新用户昵称
  static async updateNickname(context: Context, newName: string): Promise<boolean> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return false;
    let users = await UserManager.getAllUsers(context);
    if (users[currentUser.userId]) {
      users[currentUser.userId].username = newName;
      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
      await pref.flush();
      currentUser.username = newName;
      UserManager.syncUserToAppStorage(currentUser);
      return true;
    }
    return false;
  }

  // 账号注销
  static async deleteAccount(context: Context): Promise<boolean> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return false;
    let userId = currentUser.userId;
    let users = await UserManager.getAllUsers(context);

    if (users[userId]) {

      // 从用户列表中删除当前账号
      let newUsers: Record<string, UserInfo> = {};
      let keys = Object.keys(users) as string[];
      for (let i = 0; i < keys.length; i++) {
        let key = keys[i];
        if (key !== userId) newUsers[key] = users[key];
      }
      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(newUsers));

      // 删除该用户的所有临时队列、会话
      let allData = await pref.getAll() as Record<string, Object>;
      let allKeys = Object.keys(allData) as string[];
      // 遍历所有key，删除以 queue_{userId}_ 或 session_{userId} 开头的数据
      for (let i = 0; i < allKeys.length; i++) {
        let k = allKeys[i];
        if (k.startsWith(`queue_${userId}_`) || k.startsWith(`session_${userId}`)) {
          await pref.delete(k);
        }
      }

      // 删除学习计划 + 当前登录态
      await pref.delete(`plan_${userId}`);
      await pref.delete(UserManager.KEY_CURRENT);
      await pref.flush();

      // 删除学习进度
      let progressPref = await preferences.getPreferences(context, UserManager.PROGRESS_DB_NAME);
      await progressPref.delete(`user_${userId}_Progress`);
      await progressPref.flush();

      // 清除内存缓存
      ProgressManager.clearMemoryCache();

      // 删除收藏数据 + 收藏会话
      let colPref = await preferences.getPreferences(context, UserManager.COLLECTION_DB_NAME);
      let colDataStr = await colPref.get(`col_${userId}`, '{}') as string;

      let colData = JSON.parse(colDataStr) as Record<string, string>;
      let colKeys = Object.keys(colData) as string[];
      for (let i = 0; i < colKeys.length; i++) {
        let bookId = colKeys[i];
        await colPref.delete(`col_session_${userId}_${bookId}`);
      }
      await colPref.delete(`col_${userId}`);
      await colPref.flush();

      // 清空全局状态
      UserManager.syncUserToAppStorage(null);
      AppStorage.setOrCreate('studyPlan', null);
      AppStorage.setOrCreate('totalLearnedInBook', 0);
      return true;
    }
    return false;
  }

  // 获取用户个人学习计划
  static async getUserPlan(context: Context, userId: string): Promise<PlanData | null> {
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    let planStr = await pref.get(`plan_${userId}`, '') as string;
    if (planStr) return JSON.parse(planStr) as PlanData;
    return null;
  }

  // 保存用户的学习计划到本地
  static async saveUserPlan(context: Context, userId: string, plan: PlanData): Promise<void> {
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(`plan_${userId}`, JSON.stringify(plan));
    await pref.flush();
  }

  // 更新用户学习统计
  static async updateUserStats(context: Context, addedNew: number, addedReview: number): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      // 本次总共学了多少
      let totalAdded = addedNew + addedReview;
      u.totalWords += totalAdded;
      let today = new Date().toDateString();

      // 如果上次学习日期不是今天
      if (u.lastStudyDate !== today) {
        u.lastStudyDate = today;
        u.todayStudiedCount = totalAdded;
        u.todayStudiedNew = addedNew;
        u.todayStudiedReview = addedReview;
      } else {
        // 如果上次学习日期是今天
        u.todayStudiedCount = (u.todayStudiedCount || 0) + totalAdded;
        u.todayStudiedNew = (u.todayStudiedNew || 0) + addedNew;
        u.todayStudiedReview = (u.todayStudiedReview || 0) + addedReview;
      }

      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
      await pref.flush();

      UserManager.syncUserToAppStorage(u);
    }
  }

  // 追加今日学习目标
  static async addExtraTarget(context: Context, plan: PlanData, currentAvailableNew: number, currentAvailableReview: number): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];

    if (u) {
      let studiedNew = u.todayStudiedNew || 0;
      let studiedReview = u.todayStudiedReview || 0;

      let maxPossibleNew = studiedNew + currentAvailableNew;
      let maxPossibleReview = studiedReview + currentAvailableReview;

      let targetNew = u.todayTargetNew || 0;
      let targetReview = u.todayTargetReview || 0;

      let addNew = plan.dailyNew;
      if (targetNew + addNew > maxPossibleNew) {
        addNew = Math.max(0, maxPossibleNew - targetNew);
      }

      // 计算实际能追加多少
      let addReview = plan.dailyReview;
      if (targetReview + addReview > maxPossibleReview) {
        addReview = Math.max(0, maxPossibleReview - targetReview);
      }

      u.todayTargetNew = targetNew + addNew;
      u.todayTargetReview = targetReview + addReview;
      u.todayTarget = u.todayTargetNew + u.todayTargetReview;

      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
      await pref.flush();

      UserManager.syncUserToAppStorage(u);
    }
  }

  // 保存用户当前活跃会话
  static async saveActiveSession(context: Context, sessionStr: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(`session_${currentUser.userId}`, sessionStr);
    await pref.flush();
  }

  // 读取用户当前活跃会话
  static async getActiveSession(context: Context): Promise<string | null> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return null;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    let data = await pref.get(`session_${currentUser.userId}`, '') as string;
    return data !== '' ? data : null;
  }

  // 清除用户当前活跃会话
  static async clearActiveSession(context: Context): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.delete(`session_${currentUser.userId}`);
    await pref.flush();
  }

  // 保存今日单词队列
  static async saveDailyQueue(context: Context, bookId: string, date: string, queueStr: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(`queue_${currentUser.userId}_${bookId}_${date}`, queueStr);
    await pref.flush();
  }

  // 读取今日单词队列
  static async getDailyQueue(context: Context, bookId: string, date: string): Promise<string | null> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return null;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    let data = await pref.get(`queue_${currentUser.userId}_${bookId}_${date}`, '') as string;
    return data !== '' ? data : null;
  }

  // 清除今日单词队列
  static async clearDailyQueue(context: Context, bookId: string, date: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.delete(`queue_${currentUser.userId}_${bookId}_${date}`);
    await pref.flush();
  }

  // 记录用户签到（计算连续天数）
  static async recordCheckIn(context: Context): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      let today = new Date().toDateString();
      let yesterdayDate = new Date(Date.now() - 86400000).toDateString();// 昨天日期

      if (u.lastCheckInDate === today) {// 已经签过，不处理
      } else if (u.lastCheckInDate === yesterdayDate) {
        // 昨天签过
        u.continuousCheckInDays = (u.continuousCheckInDays || 0) + 1;
        u.lastCheckInDate = today;
      } else {
        // 断签了
        u.continuousCheckInDays = 1;
        u.lastCheckInDate = today;
      }

      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
      await pref.flush();

      UserManager.syncUserToAppStorage(u);
    }
  }

  // 自动检查：如果用户断签了，就重置连续天数为 0
  static async checkAndResetStreak(context: Context): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      let today = new Date().toDateString();
      let yesterdayDate = new Date(Date.now() - 86400000).toDateString();

      if (u.lastCheckInDate !== today && u.lastCheckInDate !== yesterdayDate) {
        // 如果连续天数 > 0
        if ((u.continuousCheckInDays || 0) > 0) {
          u.continuousCheckInDays = 0;
          let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
          await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
          await pref.flush();

          UserManager.syncUserToAppStorage(u);
        }
      }
    }
  }

  // 记录用户完成的词书
  static async recordCompletedBook(context: Context, plan: PlanData): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      if (!u.completedBooks) u.completedBooks = [];
      if (u.completedBooks.length > 0 && typeof u.completedBooks[0] === 'string') {
        u.completedBooks = [];
      }
      // 检查这本书是否已经在完成列表里了
      let exists = u.completedBooks.some((b: CompletedBookInfo) => b.bookId === plan.bookId);
      // 如果这本书没完成过
      if (!exists) {
        let newBook: CompletedBookInfo = { bookId: plan.bookId, bookName: plan.bookName, totalWords: plan.totalWords };
        let newBooksArray: CompletedBookInfo[] = [...u.completedBooks, newBook];
        u.completedBooks = newBooksArray;

        let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
        await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
        await pref.flush();

        UserManager.syncUserToAppStorage(u);
      }
    }
  }
}