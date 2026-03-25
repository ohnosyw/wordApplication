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
}

export class UserManager {
  private static PREF_NAME = 'UserDatabase';
  // 🌟 引入单词进度库的名字，用于跨库删除
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
    // 🌟 退出时顺手清空一下 UI 缓存，防止切换账号时画面闪烁旧数据
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

  // ------------------ 🌟 核心修复区 ------------------
  static async deleteAccount(context: Context): Promise<boolean> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return false;
    let userId = currentUser.userId;
    let users = await UserManager.getAllUsers(context);

    if (users[userId]) {
      // 1. 从总用户表中剔除
      let newUsers: Record<string, UserInfo> = {};
      let keys = Object.keys(users);
      for (let i = 0; i < keys.length; i++) {
        let key = keys[i];
        if (key !== userId) newUsers[key] = users[key];
      }

      // 2. 清理 UserDatabase (用户信息库)
      let pref = await preferences.getPreferences(context, UserManager.PREF_NAME);
      await pref.put(UserManager.KEY_USERS, JSON.stringify(newUsers));
      await pref.delete(`plan_${userId}`);
      await pref.delete(`session_${userId}`);
      await pref.delete(UserManager.KEY_CURRENT);
      await pref.flush();

      // 3. 🌟 跨库精准打击：清理 WordMemoryDB (单词进度库)
      let progressPref = await preferences.getPreferences(context, UserManager.PROGRESS_DB_NAME);
      await progressPref.delete(`user_${userId}_Progress`);
      await progressPref.flush();

      // 4. 清理内存 UI 状态
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
        u.checkInDays += 1;
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

  // 替换掉 UserManager 里面原有的 addExtraTarget 方法
  // 🌟 核心升级：加练配额现在被系统可用余量严格限制！
  static async addExtraTarget(context: Context, plan: PlanData, currentAvailableNew: number, currentAvailableReview: number): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let users = await UserManager.getAllUsers(context);
    let u = users[currentUser.userId];

    if (u) {
      let studiedNew = u.todayStudiedNew || 0;
      let studiedReview = u.todayStudiedReview || 0;

      // 理论上的最大可学数量 = 已经学了的 + 现在数据库里还能抽出来的
      let maxPossibleNew = studiedNew + currentAvailableNew;
      let maxPossibleReview = studiedReview + currentAvailableReview;

      let targetNew = u.todayTargetNew || 0;
      let targetReview = u.todayTargetReview || 0;

      // 计算新词的增量，但绝不允许越界
      let addNew = plan.dailyNew;
      if (targetNew + addNew > maxPossibleNew) {
        addNew = Math.max(0, maxPossibleNew - targetNew);
      }

      // 计算复习词的增量（如果是第一天，这里算出的一定是 0！）
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
}