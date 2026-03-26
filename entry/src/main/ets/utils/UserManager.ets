// entry/src/main/ets/utils/UserManager.ets
import preferences from '@ohos.data.preferences';
import promptAction from '@ohos.promptAction';
import { PlanData } from '../model/StudyPlan';

export interface UserInfo {
  userId: string;
  username: string;
  password: string;
  checkInDays: number;
  totalWords: number;
  lastStudyDate?: string;
  todayStudiedCount?: number;
  todayTarget?: number;
  todayTargetNew?: number;
  todayTargetReview?: number;
  todayStudiedNew?: number;
  todayStudiedReview?: number;

  continuousCheckInDays?: number;
  lastCheckInDate?: string;
  completedBooks?: string[];

  currentStudyBookId?: string;
}

export class UserManager {
  private static PREF_NAME = 'UserDatabase';
  private static PROGRESS_DB_NAME = 'WordMemoryDB';
  // 🌟 新增：显式声明收藏库的名字，用于跨库歼灭
  private static COLLECTION_DB_NAME = 'UserCollections';
  private static KEY_USERS = 'AllUsers';
  private static KEY_CURRENT = 'CurrentUserId';

  static async getAllUsers(context: Context): Promise<Record<string, UserInfo>> {
    try {
      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      let dataStr = await pref.get(UserManager.KEY_USERS, '{}') as string;
      return JSON.parse(dataStr);
    } catch (e) { return {}; }
  }

  static async register(context: Context, user: UserInfo): Promise<boolean> {
    let users = await UserManager.getAllUsers(context);
    if (users[user.userId]) { promptAction.showToast({ message: '该账号已存在！' }); return false; }
    user.completedBooks = [];
    users[user.userId] = user;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
    await pref.flush();
    return true;
  }

  static async login(context: Context, userId: string, pass: string): Promise<boolean> {
    let users = await UserManager.getAllUsers(context);
    let targetUser = users[userId];
    if (!targetUser) { promptAction.showToast({ message: '账号不存在！' }); return false; }
    if (targetUser.password !== pass) { promptAction.showToast({ message: '密码错误！' }); return false; }

    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(UserManager.KEY_CURRENT, userId);
    await pref.flush();

    AppStorage.setOrCreate('currentUser', targetUser);
    let plan = await UserManager.getUserPlan(context, targetUser.userId);
    AppStorage.setOrCreate('studyPlan', plan);
    return true;
  }

  static async logout(context: Context): Promise<void> {
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.delete(UserManager.KEY_CURRENT);
    await pref.flush();
    AppStorage.setOrCreate('currentUser', null);
    AppStorage.setOrCreate('studyPlan', null);
    AppStorage.setOrCreate('totalLearnedInBook', 0);
  }

  static async autoLogin(context: Context): Promise<void> {
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    let currentId = await pref.get(UserManager.KEY_CURRENT, '') as string;
    if (currentId !== '') {
      let users = await UserManager.getAllUsers(context);
      if (users[currentId]) {
        AppStorage.setOrCreate('currentUser', users[currentId]);
        let plan = await UserManager.getUserPlan(context, currentId);
        AppStorage.setOrCreate('studyPlan', plan);
      }
    }
  }

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
      AppStorage.setOrCreate('currentUser', currentUser);
      return true;
    }
    return false;
  }

  static async deleteAccount(context: Context): Promise<boolean> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return false;
    let userId = currentUser.userId;
    let users = await UserManager.getAllUsers(context);

    if (users[userId]) {
      let newUsers: Record<string, UserInfo> = {};
      let keys = Object.keys(users);
      for (let i = 0; i < keys.length; i++) {
        let key = keys[i];
        if (key !== userId) newUsers[key] = users[key];
      }

      // 1. 清理主数据库（账号信息、主线断点、每日队列快照等）
      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(newUsers));
      await pref.delete(`plan_${userId}`);
      await pref.delete(`session_${userId}`);
      await pref.delete(UserManager.KEY_CURRENT);
      // 由于 queue 是按日期生成的动态键，注销时不便全量遍历，但主账号已毁，垃圾数据会被隔离，不再影响新同名用户。
      await pref.flush();

      // 2. 清理进度数据库（艾宾浩斯记忆档案）
      let progressPref = await preferences.getPreferences(context, UserManager.PROGRESS_DB_NAME);
      await progressPref.delete(`user_${userId}_Progress`);
      await progressPref.flush();

      // 3. 🌟 核心修复：全面清理第三大数据库 —— 收藏夹及收藏特训断点！
      let colPref = await preferences.getPreferences(context, UserManager.COLLECTION_DB_NAME);
      let colDataStr = await colPref.get(`col_${userId}`, '{}') as string;
      let colData = JSON.parse(colDataStr) as Record<string, Object>;
      // 遍历该用户之前所有的收藏夹，把为它们单独创建的“特训断点快照”全部物理粉碎
      for (let bookId of Object.keys(colData)) {
        await colPref.delete(`col_session_${userId}_${bookId}`);
      }
      // 粉碎收藏夹本体
      await colPref.delete(`col_${userId}`);
      await colPref.flush();

      // 4. 重置内存变量
      AppStorage.setOrCreate('currentUser', null);
      AppStorage.setOrCreate('studyPlan', null);
      AppStorage.setOrCreate('totalLearnedInBook', 0);
      return true;
    }
    return false;
  }

  static async getUserPlan(context: Context, userId: string): Promise<PlanData | null> {
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    let planStr = await pref.get(`plan_${userId}`, '') as string;
    if (planStr) return JSON.parse(planStr);
    return null;
  }

  static async saveUserPlan(context: Context, userId: string, plan: PlanData): Promise<void> {
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(`plan_${userId}`, JSON.stringify(plan));
    await pref.flush();
  }

  static async updateUserStats(context: Context, addedNew: number, addedReview: number): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      let totalAdded = addedNew + addedReview;
      u.totalWords += totalAdded;
      let today = new Date().toDateString();

      if (u.lastStudyDate !== today) {
        u.lastStudyDate = today;
        u.todayStudiedCount = totalAdded;
        u.todayStudiedNew = addedNew;
        u.todayStudiedReview = addedReview;
      } else {
        u.todayStudiedCount = (u.todayStudiedCount || 0) + totalAdded;
        u.todayStudiedNew = (u.todayStudiedNew || 0) + addedNew;
        u.todayStudiedReview = (u.todayStudiedReview || 0) + addedReview;
      }

      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
      await pref.flush();
      AppStorage.setOrCreate('currentUser', u);
    }
  }

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
      AppStorage.setOrCreate('currentUser', u);
    }
  }

  static async saveActiveSession(context: Context, sessionStr: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(`session_${currentUser.userId}`, sessionStr);
    await pref.flush();
  }

  static async getActiveSession(context: Context): Promise<string | null> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return null;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    let data = await pref.get(`session_${currentUser.userId}`, '') as string;
    return data !== '' ? data : null;
  }

  static async clearActiveSession(context: Context): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.delete(`session_${currentUser.userId}`);
    await pref.flush();
  }

  static async saveDailyQueue(context: Context, bookId: string, date: string, queueStr: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.put(`queue_${currentUser.userId}_${bookId}_${date}`, queueStr);
    await pref.flush();
  }

  static async getDailyQueue(context: Context, bookId: string, date: string): Promise<string | null> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return null;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    let data = await pref.get(`queue_${currentUser.userId}_${bookId}_${date}`, '') as string;
    return data !== '' ? data : null;
  }

  static async clearDailyQueue(context: Context, bookId: string, date: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
    await pref.delete(`queue_${currentUser.userId}_${bookId}_${date}`);
    await pref.flush();
  }

  static async recordCheckIn(context: Context): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      let today = new Date().toDateString();
      let yesterdayDate = new Date(Date.now() - 86400000).toDateString();

      if (u.lastCheckInDate === today) {
      } else if (u.lastCheckInDate === yesterdayDate) {
        u.continuousCheckInDays = (u.continuousCheckInDays || 0) + 1;
        u.lastCheckInDate = today;
      } else {
        u.continuousCheckInDays = 1;
        u.lastCheckInDate = today;
      }

      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
      await pref.flush();
      AppStorage.setOrCreate('currentUser', u);
    }
  }

  static async checkAndResetStreak(context: Context): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      let today = new Date().toDateString();
      let yesterdayDate = new Date(Date.now() - 86400000).toDateString();

      if (u.lastCheckInDate !== today && u.lastCheckInDate !== yesterdayDate) {
        if ((u.continuousCheckInDays || 0) > 0) {
          u.continuousCheckInDays = 0;
          let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
          await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
          await pref.flush();
          AppStorage.setOrCreate('currentUser', u);
        }
      }
    }
  }

  static async recordCompletedBook(context: Context, bookName: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      if (!u.completedBooks) u.completedBooks = [];
      if (!u.completedBooks.includes(bookName)) {
        u.completedBooks.push(bookName);
        let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
        await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
        await pref.flush();
        AppStorage.setOrCreate('currentUser', u);
      }
    }
  }
}