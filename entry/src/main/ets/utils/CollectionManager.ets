// entry/src/main/ets/utils/CollectionManager.ets
import preferences from '@ohos.data.preferences';
import { UserInfo, UserManager } from '../utils/UserManager'

export interface CollectionData {
  bookName: string;
  wordIds: string[];
}

export class CollectionManager {
  private static PREF_NAME = 'UserCollections';

  // 获取用户的所有收藏夹
  static async getCollections(context: Context): Promise<Record<string, CollectionData>> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return {};
    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    let data = await pref.get(`col_${currentUser.userId}`, '{}') as string;
    return JSON.parse(data);
  }

  // 切换收藏状态（收藏/取消收藏）
  static async toggleCollection(context: Context, bookId: string, bookName: string, wordId: string): Promise<boolean> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) return false;

    // 🌟 修复点 1：将 this.getCollections 改为 CollectionManager.getCollections
    let cols = await CollectionManager.getCollections(context);

    // 如果是第一次收藏这本书，自动创建该词书的收藏夹
    if (!cols[bookId]) {
      cols[bookId] = { bookName: bookName, wordIds: [] };
    }

    let idx = cols[bookId].wordIds.indexOf(wordId);
    let isCollected = false;

    if (idx > -1) {
      // 如果已经收藏，则移除（就算词清空了，对应的 bookId 键依然存在，保留空文件夹）
      cols[bookId].wordIds.splice(idx, 1);
      isCollected = false;
    } else {
      // 如果未收藏，则添加
      cols[bookId].wordIds.push(wordId);
      isCollected = true;
    }

    let pref = await preferences.getPreferences(context, CollectionManager.PREF_NAME);
    await pref.put(`col_${currentUser.userId}`, JSON.stringify(cols));
    await pref.flush();
    return isCollected;
  }

  // 检查某个词是否被收藏
  static async isCollected(context: Context, bookId: string, wordId: string): Promise<boolean> {
    // 🌟 修复点 2：将 this.getCollections 改为 CollectionManager.getCollections
    let cols = await CollectionManager.getCollections(context);
    if (cols[bookId] && cols[bookId].wordIds.includes(wordId)) {
      return true;
    }
    return false;
  }
}