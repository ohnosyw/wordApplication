// entry/src/main/ets/utils/Ebbinghaus.ets

export interface WordProgress {
  wordId: string;
  repetition: number;       // 连续答对的次数
  interval: number;         // 距离下一次复习的间隔天数
  efactor: number;          // 简易度因子 (Easiness Factor)
  nextReviewDate: number;   // 下一次复习的时间戳
}

export class Ebbinghaus {
  /**
   * 基于 SM-2 (艾宾浩斯记忆曲线) 计算单词的下一次复习时间
   * @param progress 单词当前的记忆进度
   * @param isKnown 用户是否认识该单词
   * @returns 更新后的记忆进度
   */
  static calculateNextReview(progress: WordProgress, isKnown: boolean): WordProgress {
    // 质量评分：4表示认识(Good)，0表示完全不认识(Blackout)
    let grade = isKnown ? 4 : 0;

    // ArkTS 不允许对象展开运算符，所以手动赋值创建新对象
    let newProgress: WordProgress = {
      wordId: progress.wordId,
      repetition: progress.repetition,
      interval: progress.interval,
      efactor: progress.efactor,
      nextReviewDate: progress.nextReviewDate
    };

    // 如果认识（评分 >= 3）
    if (grade >= 3) {
      if (newProgress.repetition === 0) {
        newProgress.interval = 1; // 第一次复习间隔1天
      } else if (newProgress.repetition === 1) {
        newProgress.interval = 6; // 第二次复习间隔6天
      } else {
        // 后续复习间隔 = 前一次间隔 * 简易度因子
        newProgress.interval = Math.round(newProgress.interval * newProgress.efactor);
      }
      newProgress.repetition += 1;
    } else {
      // 如果不认识，连续正确次数清零，明天重新复习
      newProgress.repetition = 0;
      newProgress.interval = 1;
    }

    // 动态调整简易度因子
    newProgress.efactor = newProgress.efactor + (0.1 - (5 - grade) * (0.08 + (5 - grade) * 0.02));
    if (newProgress.efactor < 1.3) {
      newProgress.efactor = 1.3; // 最小值底线
    }

    // 计算下一次复习的精确时间戳
    newProgress.nextReviewDate = Date.now() + newProgress.interval * 24 * 60 * 60 * 1000;

    return newProgress;
  }
}