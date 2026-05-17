// entry/src/main/ets/utils/CollectionManager.ets
import preferences from '@ohos.data.preferences';
import { UserInfo } from '../utils/UserManager';

// 定义单个词书收藏夹的数据模型
export interface CollectionData {
  bookName: string;
  wordIds: string[];
  dailyLimit?: number;
  lastWordId?: string;
}

export class CollectionManager {
  private static PREF_NAME = 'UserCollections';

  // 获取当前用户所有的收藏数据
  static async getCollections(context: Context): Promise<Record<string, CollectionData>> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return {};

    // 获取 Preferences 实例
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);

    //使用 `col_用户ID` 作为 Key，确保不同账号在同一台设备上收藏夹不串号
    let data = await pref.get(`col_${currentUser.userId}`, '{}') as string;
    return JSON.parse(data);
  }

  // 切换单词的收藏状态
  static async toggleCollection(context: Context, bookId: string, bookName: string, wordId: string): Promise<boolean> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return false;

    let cols = await CollectionManager.getCollections(context);

    // 如果该词书尚未建立收藏夹，自动初始化一个空结构
    if (!cols[bookId]) {
      cols[bookId] = { bookName: bookName, wordIds: [], dailyLimit: 20 };
    }

    // 查找该单词 ID 是否已经在数组中
    let idx = cols[bookId].wordIds.indexOf(wordId);
    let isCollected = false;

    if (idx > -1) {
      // 存在，则从数组中剔除 (取消收藏)
      cols[bookId].wordIds.splice(idx, 1);
      isCollected = false;
    } else {
      // 不存在，则追加到数组末尾 (加入收藏)
      cols[bookId].wordIds.push(wordId);
      isCollected = true;
    }

    // 将修改后的完整对象重新序列化，并覆写回本地存储
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    await pref.put(`col_${currentUser.userId}`, JSON.stringify(cols));
    await pref.flush();
    return isCollected;
  }

  // 查询某个单词是否被收藏
  static async isCollected(context: Context, bookId: string, wordId: string): Promise<boolean> {
    let cols = await CollectionManager.getCollections(context);
    if (cols[bookId] && cols[bookId].wordIds.includes(wordId)) {
      return true;
    }
    return false;
  }

  // 一键清空某本词书的所有收藏词
  static async clearCollection(context: Context, bookId: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let cols = await CollectionManager.getCollections(context);
    if (cols[bookId]) {
      cols[bookId].wordIds = [];// 将数组置空
      let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
      await pref.put(`col_${currentUser.userId}`, JSON.stringify(cols));
      await pref.flush();
    }
  }

  // 每日特训量（单次任务上限）
  static async getDailyLimit(context: Context, bookId: string): Promise<number> {
    let cols = await CollectionManager.getCollections(context);
    return cols[bookId]?.dailyLimit || 20;
  }

  // 设置某本词书的每日学习上限
  static async setDailyLimit(context: Context, bookId: string, limit: number): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let cols = await CollectionManager.getCollections(context);
    if (cols[bookId]) {
      cols[bookId].dailyLimit = limit;
      let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
      await pref.put(`col_${currentUser.userId}`, JSON.stringify(cols));
      await pref.flush();
    }
  }

  // ---------------- 断点续传管理 ----------------
  // 保存收藏会话字符串
  static async saveCollectionSession(context: Context, bookId: string, sessionStr: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    await pref.put(`col_session_${currentUser.userId}_${bookId}`, sessionStr);
    await pref.flush();
  }

  // 读取收藏会话字符串
  static async getCollectionSession(context: Context, bookId: string): Promise<string | null> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return null;
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    let data = await pref.get(`col_session_${currentUser.userId}_${bookId}`, '') as string;
    return data !== '' ? data : null;
  }

  // 清除收藏会话
  static async clearCollectionSession(context: Context, bookId: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    await pref.delete(`col_session_${currentUser.userId}_${bookId}`);
    await pref.flush();
  }

  // ---------------- 词汇锚点记录 ----------------
  // 获取词书最后学习的单词ID
  static async getLastWordId(context: Context, bookId: string): Promise<string | undefined> {
    let cols = await CollectionManager.getCollections(context);
    return cols[bookId]?.lastWordId;
  }

  // 保存最后学习的单词ID
  static async setLastWordId(context: Context, bookId: string, wordId: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let cols = await CollectionManager.getCollections(context);
    if (cols[bookId]) {
      cols[bookId].lastWordId = wordId;
      let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
      await pref.put(`col_${currentUser.userId}`, JSON.stringify(cols));
      await pref.flush();
    }
  }
}