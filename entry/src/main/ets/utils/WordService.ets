// entry/src/main/ets/utils/WordService.ets
import { DataLoader } from './DataLoader';
import { ProgressManager } from './ProgressManager';
import { WordEntry } from '../model/WordModel';
import { PlanData } from '../model/StudyPlan';
import { UserInfo } from './UserManager';

export interface TaskInfo {
  newCount: number;
  reviewCount: number;
  totalLearned: number;
  availableNew: number;
  availableReview: number;
}

export class WordService {
  //生成今日学习清单
  static async generateTodayQueue(context: Context, plan: PlanData): Promise<WordEntry[]> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');

    let neededNew = plan.dailyNew;
    let neededReview = plan.dailyReview;

    //如果用户今天已经学习过（上次学习日期是今天）
    if (currentUser && currentUser.lastStudyDate === new Date().toDateString()) {
      //用户是否有重新设定计划？
      let targetNew = currentUser.todayTargetNew !== undefined ? currentUser.todayTargetNew : plan.dailyNew;
      let studiedNew = currentUser.todayStudiedNew !== undefined ? currentUser.todayStudiedNew : 0;
      neededNew = Math.max(0, targetNew - studiedNew);

      let targetReview = currentUser.todayTargetReview !== undefined ? currentUser.todayTargetReview : plan.dailyReview;
      let studiedReview = currentUser.todayStudiedReview !== undefined ? currentUser.todayStudiedReview : 0;
      neededReview = Math.max(0, targetReview - studiedReview);
    }

    let allWords = await DataLoader.loadWordBook(context, `${plan.bookId}.json`);
    let progressMap = await ProgressManager.getProgressMap(context);

    let unlearned: WordEntry[] = [];
    let learned: WordEntry[] = [];

    for (let i = 0; i < allWords.length; i++) {
      let word = allWords[i];
      // 给 ID 加上词书专属命名空间，防止词书间进度串联
      let namespacedId = `${plan.bookId}_${word.content.word.wordId}`;

      //进度表中单词查询？？
      if (progressMap[namespacedId]) {
        learned.push(word);
      } else {
        unlearned.push(word);
      }
    }

    let finalNew = unlearned.slice(0, neededNew);

    //按下次复习日期排序已学单词
    learned.sort((a, b) => {
      let aProg = progressMap[`${plan.bookId}_${a.content.word.wordId}`];
      let bProg = progressMap[`${plan.bookId}_${b.content.word.wordId}`];
      let dateA = aProg ? aProg.nextReviewDate : 0;
      let dateB = bProg ? bProg.nextReviewDate : 0;
      return dateA - dateB;
    });

    let finalReview = learned.slice(0, neededReview);

    let todayQueue: WordEntry[] = [];
    //如果学习模式为 0（顺序模式）
    if (plan.studyMode === 0) {
      todayQueue = finalNew.concat(finalReview);
    } else {
      todayQueue = finalNew.concat(finalReview);
      //使用Fisher-Yates算法打乱顺序
      for (let i = todayQueue.length - 1; i > 0; i--) {
        let j = Math.floor(Math.random() * (i + 1));
        let temp = todayQueue[i];
        todayQueue[i] = todayQueue[j];
        todayQueue[j] = temp;
      }
    }

    return todayQueue;
  }

  static async getTodayTaskInfo(context: Context, plan: PlanData): Promise<TaskInfo> {
    let allWords = await DataLoader.loadWordBook(context, `${plan.bookId}.json`);
    let progressMap = await ProgressManager.getProgressMap(context);

    let newQueueCount = 0;
    let reviewQueueCount = 0;
    let totalLearnedCount = 0;
    let now = Date.now();

    for (let i = 0; i < allWords.length; i++) {
      // 按照命名空间检查本书学习量
      let namespacedId = `${plan.bookId}_${allWords[i].content.word.wordId}`;
      let progress = progressMap[namespacedId];
      if (progress) {
        totalLearnedCount++;
        if (progress.nextReviewDate <= now) {
          reviewQueueCount++;
        }
      } else {
        newQueueCount++;
      }
    }

    return {
      newCount: Math.min(newQueueCount, plan.dailyNew),
      reviewCount: Math.min(reviewQueueCount, plan.dailyReview),
      totalLearned: totalLearnedCount,
      availableNew: newQueueCount,
      availableReview: reviewQueueCount
    };
  }
}