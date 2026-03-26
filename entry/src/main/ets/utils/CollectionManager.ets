// entry/src/main/ets/utils/CollectionManager.ets
import preferences from '@ohos.data.preferences';
import { UserInfo } from '../utils/UserManager';

export interface CollectionData {
  bookName: string;
  wordIds: string[];
  dailyLimit?: number;
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

  static async clearCollection(context: Context, bookId: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let cols = await CollectionManager.getCollections(context);
    if (cols[bookId]) {
      cols[bookId].wordIds = [];
      let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
      await pref.put(`col_${currentUser.userId}`, JSON.stringify(cols));
      await pref.flush();
    }
  }

  static async getDailyLimit(context: Context, bookId: string): Promise<number> {
    let cols = await CollectionManager.getCollections(context);
    return cols[bookId]?.dailyLimit || 20;
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

  // ---------------- 🌟 收藏模式专属：断点续传管理 ----------------
  static async saveCollectionSession(context: Context, bookId: string, sessionStr: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    await pref.put(`col_session_${currentUser.userId}_${bookId}`, sessionStr);
    await pref.flush();
  }

  static async getCollectionSession(context: Context, bookId: string): Promise<string | null> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return null;
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    let data = await pref.get(`col_session_${currentUser.userId}_${bookId}`, '') as string;
    return data !== '' ? data : null;
  }

  static async clearCollectionSession(context: Context, bookId: string): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return;
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    await pref.delete(`col_session_${currentUser.userId}_${bookId}`);
    await pref.flush();
  }
}