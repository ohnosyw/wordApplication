// entry/src/main/ets/utils/DataLoader.ets
import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';
import { WordEntry } from '../model/WordModel';

export class DataLoader {
  /**
   * 从 rawfile 异步读取词书 JSON
   * @param context UIAbility 的上下文，或者组件中的 getContext(this)
   * @param fileName rawfile 下的文件名，如 'CET4.json'
   * @returns 解析后的单词数组
   */
  static async loadWordBook(context: Context, fileName: string): Promise<WordEntry[]> {
    try {
      // 1. 获取资源管理器
      let rm = context.resourceManager;

      // 2. 读取 rawfile 文件内容
      let rawData = await rm.getRawFileContent(fileName);

      // 3. 将字节数组解码为字符串
      let textDecoder = new util.TextDecoder('utf-8');
      let jsonString = textDecoder.decodeWithStream(rawData);

      // 4. 解析 JSON 字符串
      let wordList = JSON.parse(jsonString) as WordEntry[];

      console.info('LoadBook', `成功导入词书，共包含 ${wordList.length} 个单词`);
      return wordList;

    } catch (error) {
      console.error('LoadBook', `读取词书失败: ${error}`);
      return [];
    }
  }
}