// entry/src/main/ets/utils/ProgressManager.ets
import preferences from '@ohos.data.preferences';
import { WordProgress } from './Ebbinghaus';
import { UserInfo } from './UserManager';

export class ProgressManager {
  private static PREF_NAME = 'WordMemoryDB';

  // 高速缓存
  private static memoryCache: Record<string, WordProgress> | null = null;
  private static currentUserId: string = '';

  // 🌟 核心修复 1：新增暴露给外部的内存粉碎方法
  static clearMemoryCache(): void {
    ProgressManager.memoryCache = null;
    ProgressManager.currentUserId = '';
  }

  static async getProgressMap(context: Context): Promise<Record<string, WordProgress>> {
    try {
      let currentUser = AppStorage.get<UserInfo>('currentUser');
      if (!currentUser || !currentUser.userId) {
        let emptyMap: Record<string, WordProgress> = {};
        return emptyMap;
      }

      if (ProgressManager.memoryCache && ProgressManager.currentUserId === currentUser.userId) {
        return ProgressManager.memoryCache;
      }

      let pref = await preferences.getPreferences(context, ProgressManager.PREF_NAME);
      let userKey = `user_${currentUser.userId}_Progress`;
      let dataString = await pref.get(userKey, '{}') as string;

      let parsedData = JSON.parse(dataString) as Record<string, WordProgress>;
      ProgressManager.memoryCache = parsedData;
      ProgressManager.currentUserId = currentUser.userId;

      return ProgressManager.memoryCache;
    } catch (e) {
      let emptyMap: Record<string, WordProgress> = {};
      return emptyMap;
    }
  }

  static async saveWordProgress(context: Context, progress: WordProgress): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser || !currentUser.userId) return;

    let map = await ProgressManager.getProgressMap(context);
    map[progress.wordId] = progress;
    ProgressManager.memoryCache = map;

    let pref = await preferences.getPreferences(context, ProgressManager.PREF_NAME);
    let userKey = `user_${currentUser.userId}_Progress`;
    await pref.put(userKey, JSON.stringify(map));
    await pref.flush();
  }

  static async clearBookProgress(context: Context, bookId: string): Promise<void> {
    let map = await ProgressManager.getProgressMap(context);
    let newMap: Record<string, WordProgress> = {};

    let keys = Object.keys(map) as string[];
    for (let i = 0; i < keys.length; i++) {
      let key = keys[i];
      if (!key.startsWith(`${bookId}_`)) {
        newMap[key] = map[key];
      }
    }

    ProgressManager.memoryCache = newMap;

    let pref = await preferences.getPreferences(context, ProgressManager.PREF_NAME);
    let currentUser = AppStorage.get<UserInfo>('currentUser');

    if (currentUser) {
      await pref.put(`user_${currentUser.userId}_Progress`, JSON.stringify(newMap));
      await pref.flush();
    }
  }
}