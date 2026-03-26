// entry/src/main/ets/utils/CollectionManager.ets
import preferences from '@ohos.data.preferences';
import { UserInfo } from '../utils/UserManager';

export interface CollectionData {
  bookName: string;
  wordIds: string[];
  // 🌟 新增：每日特训的任务量
  dailyLimit?: number;
  // 🌟 新增：记录上一次学到的单词锚点（断点续传）
  lastWordId?: string;
}

export class CollectionManager {
  private static PREF_NAME = 'UserCollections';

  static async getCollections(context: Context): Promise<Record<string, CollectionData>> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return {};
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    let data = await pref.get(`col_${currentUser.userId}`, '{}') as string;
    return JSON.parse(data);
  }

  static async toggleCollection(context: Context, bookId: string, bookName: string, wordId: string): Promise<boolean> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return false;

    let cols = await CollectionManager.getCollections(context);

    if (!cols[bookId]) {
      cols[bookId] = { bookName: bookName, wordIds: [], dailyLimit: 20 };
    }

    let idx = cols[bookId].wordIds.indexOf(wordId);
    let isCollected = false;

    if (idx > -1) {
      cols[bookId].wordIds.splice(idx, 1);
      isCollected = false;
    } else {
      cols[bookId].wordIds.push(wordId);
      isCollected = true;
    }

    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    await pref.put(`col_${currentUser.userId}`, JSON.stringify(cols));
    await pref.flush();
    return isCollected;
  }

  static async isCollected(context: Context, bookId: string, wordId: string): Promise<boolean> {
    let cols = await CollectionManager.getCollections(context);
    if (cols[bookId] && cols[bookId].wordIds.includes(wordId)) {
      return true;
    }
    return false;
  }

  // ---------------- 🌟 高级定制功能 ----------------

  // 一键清空某本词书的收藏词
  static async clearCollection(context: Context, bookId: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let cols = await CollectionManager.getCollections(context);
    if (cols[bookId]) {
      cols[bookId].wordIds = []; // 清空单词，但保留空文件夹和设置
      let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
      await pref.put(`col_${currentUser.userId}`, JSON.stringify(cols));
      await pref.flush();
    }
  }

  // 获取与设置每日任务量
  static async getDailyLimit(context: Context, bookId: string): Promise<number> {
    let cols = await CollectionManager.getCollections(context);
    return cols[bookId]?.dailyLimit || 20; // 默认 20 个
  }

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

  // 获取与设置学习断点锚点
  static async getLastWordId(context: Context, bookId: string): Promise<string | undefined> {
    let cols = await CollectionManager.getCollections(context);
    return cols[bookId]?.lastWordId;
  }

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