// entry/src/main/ets/utils/UserManager.ets
import preferences from '@ohos.data.preferences';
import promptAction from '@ohos.promptAction';
import { PlanData } from '../model/StudyPlan';

export interface UserInfo {
  userId: string;
  username: string;
  password: string;
  checkInDays: number; // 历史遗留的总天数，可以保留作为备用
  totalWords: number;
  lastStudyDate?: string;
  todayStudiedCount?: number;
  todayTarget?: number;
  todayTargetNew?: number;
  todayTargetReview?: number;
  todayStudiedNew?: number;
  todayStudiedReview?: number;

  // 🌟 新增：极简用户中心的核心字段
  continuousCheckInDays?: number; // 连续打卡天数
  lastCheckInDate?: string;       // 严格打卡日期
  completedBooks?: string[];      // 已完成的词书荣誉墙
}

export class UserManager {
  private static PREF_NAME = 'UserDatabase';
  private static PROGRESS_DB_NAME = 'WordMemoryDB';
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
    user.completedBooks = []; // 初始化空书架
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

      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(newUsers));
      await pref.delete(`plan_${userId}`);
      await pref.delete(`session_${userId}`);
      await pref.delete(UserManager.KEY_CURRENT);
      await pref.flush();

      let progressPref = await preferences.getPreferences(context, UserManager.PROGRESS_DB_NAME);
      await progressPref.delete(`user_${userId}_Progress`);
      await progressPref.flush();

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

  // ------------------ 🌟 极简中心核心：打卡与完本逻辑 ------------------

  // 1. 记录打卡（仅在完成当次队列时触发）
  static async recordCheckIn(context: Context): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      let today = new Date().toDateString();
      let yesterdayDate = new Date(Date.now() - 86400000).toDateString();

      if (u.lastCheckInDate === today) {
        // 今天已经打过卡了（加练完成不重复加天数），保持不变
      } else if (u.lastCheckInDate === yesterdayDate) {
        // 昨天打过卡，连续打卡 +1
        u.continuousCheckInDays = (u.continuousCheckInDays || 0) + 1;
        u.lastCheckInDate = today;
      } else {
        // 中断了，重新从 1 开始
        u.continuousCheckInDays = 1;
        u.lastCheckInDate = today;
      }

      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(users));
      await pref.flush();
      AppStorage.setOrCreate('currentUser', u);
    }
  }

  // 2. 检查是否漏打卡中断（在用户中心加载时触发）
  static async checkAndResetStreak(context: Context): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      let today = new Date().toDateString();
      let yesterdayDate = new Date(Date.now() - 86400000).toDateString();

      // 如果上次打卡不是今天，也不是昨天，说明断签了
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

  // 3. 记录已完成的词书
  static async recordCompletedBook(context: Context, bookName: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];
    if (u) {
      if (!u.completedBooks) u.completedBooks = [];
      // 如果还没记录这本书，则加入荣誉墙
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