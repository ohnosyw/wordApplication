// entry/src/main/ets/utils/ProgressManager.ets
import preferences from '@ohos.data.preferences';
import { WordProgress } from './Ebbinghaus';
// 引入 UserInfo 接口，确保路径与你的实际路径一致
import { UserInfo } from './UserManager';

export class ProgressManager {
  // 数据库文件的名字，整个 App 共用这一个文件即可
  private static PREF_NAME = 'WordMemoryDB';

  /**
   * 获取当前登录用户的所有单词记忆进度
   */
  static async getProgressMap(context: Context): Promise<Record<string, WordProgress>> {
    try {
      // 1. 获取本地数据库实例
      let pref = await preferences.getPreferences(context, ProgressManager.PREF_NAME);

      // 2. 从内存中获取当前登录的用户
      let currentUser = AppStorage.get<UserInfo>('currentUser');
      if (!currentUser || !currentUser.userId) {
        console.warn('ProgressManager', '当前无用户登录，返回空进度');
        return {};
      }

      // 3. 核心：动态生成属于该用户的独有 Key（例如：user_1380000_Progress）
      let userKey = `user_${currentUser.userId}_Progress`;

      // 4. 读取属于该用户的进度数据
      let dataString = await pref.get(userKey, '{}') as string;
      return JSON.parse(dataString);
    } catch (e) {
      console.error('ProgressManager', '读取进度失败', e);
      return {};
    }
  }

  /**
   * 保存/更新单个单词的进度（自动存入当前登录用户的名下）
   */
  static async saveWordProgress(context: Context, progress: WordProgress): Promise<void> {
    // 1. 检查登录状态
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser || !currentUser.userId) {
      console.error('ProgressManager', '未登录，无法保存进度');
      return;
    }

    // 2. 获取数据库实例和当前用户的历史进度
    let pref = await preferences.getPreferences(context, ProgressManager.PREF_NAME);
    let map = await ProgressManager.getProgressMap(context);

    // 3. 更新该单词的进度
    map[progress.wordId] = progress;

    // 4. 使用同样的专属 Key 存回本地
    let userKey = `user_${currentUser.userId}_Progress`;
    await pref.put(userKey, JSON.stringify(map));
    await pref.flush(); // 强制写入磁盘，确保断电不丢数据
  }
}