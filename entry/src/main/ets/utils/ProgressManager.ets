// entry/src/main/ets/utils/ProgressManager.ets
import preferences from '@ohos.data.preferences';
import { WordProgress } from './Ebbinghaus';
import { UserInfo } from './UserManager';

export class ProgressManager {
  private static PREF_NAME = 'WordMemoryDB';

  // 高速缓存
  private static memoryCache: Record<string, WordProgress> | null = null;
  // 记录当前缓存属于哪个用户
  private static currentUserId: string = '';

  // 内存粉碎方法,当用户退出登录、切换账号或注销账号时，必须强行清空内存缓存。
  static clearMemoryCache(): void {
    ProgressManager.memoryCache = null;
    ProgressManager.currentUserId = '';
  }

  // 获取当前用户的全量记忆进度表
  static async getProgressMap(context: Context): Promise<Record<string, WordProgress>> {
    try {
      let currentUser = AppStorage.get<UserInfo>('currentUser');
      // 如果没有登录，直接返回空对象
      if (!currentUser || !currentUser.userId) {
        let emptyMap: Record<string, WordProgress> = {};
        return emptyMap;
      }

      // 如果内存中有数据，且内存数据归属于当前账号
      if (ProgressManager.memoryCache && ProgressManager.currentUserId === currentUser.userId) {
        //直接返回内存缓存（避免重复读取本地存储，提升性能）
        return ProgressManager.memoryCache;
      }

      // 缓存未命中，执行“二级缓存（磁盘）”读取
      let pref = await preferences.getPreferences(context, ProgressManager.PREF_NAME);
      let userKey = `user_${currentUser.userId}_Progress`;
      let dataString = await pref.get(userKey, '{}') as string;

      let parsedData = JSON.parse(dataString) as Record<string, WordProgress>;

      // 读完之后，立刻写入一级缓存，并绑定所属的 UserID
      ProgressManager.memoryCache = parsedData;
      ProgressManager.currentUserId = currentUser.userId;

      return ProgressManager.memoryCache;
    } catch (e) {
      let emptyMap: Record<string, WordProgress> = {};
      return emptyMap;
    }
  }

  // 保存或更新单个单词的记忆进度
  static async saveWordProgress(context: Context, progress: WordProgress): Promise<void> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser || !currentUser.userId) return;

    // 获取全量数据
    let map = await ProgressManager.getProgressMap(context);

    // 更新字典中的特定单词进度，并回写更新内存缓存
    map[progress.wordId] = progress;
    ProgressManager.memoryCache = map;

    // 异步刷入磁盘：保证数据持久化
    let pref = await preferences.getPreferences(context, ProgressManager.PREF_NAME);
    let userKey = `user_${currentUser.userId}_Progress`;
    await pref.put(userKey, JSON.stringify(map));
    await pref.flush();
  }

  // 重置某本词书的进度
  static async clearBookProgress(context: Context, bookId: string): Promise<void> {
    let map = await ProgressManager.getProgressMap(context);
    let newMap: Record<string, WordProgress> = {};

    // 数据过滤算法
    let keys = Object.keys(map) as string[];
    for (let i = 0; i < keys.length; i++) {
      let key = keys[i];
      // 如果key不是以 当前词书ID_ 开头
      if (!key.startsWith(`${bookId}_`)) {
        newMap[key] = map[key];
      }
    }

    // 使用过滤后的数据覆盖内存缓存
    ProgressManager.memoryCache = newMap;

    let pref = await preferences.getPreferences(context, ProgressManager.PREF_NAME);
    let currentUser = AppStorage.get<UserInfo>('currentUser');

    if (currentUser) {
      await pref.put(`user_${currentUser.userId}_Progress`, JSON.stringify(newMap));
      await pref.flush();
    }
  }
}