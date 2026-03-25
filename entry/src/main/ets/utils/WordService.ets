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
  // 🌟 新增：系统里绝对真实的剩余可用量（不受计划上限影响）
  availableNew: number;
  availableReview: number;
}

export class WordService {
  static async generateTodayQueue(context: Context, plan: PlanData): Promise<WordEntry[]> {
    let currentUser = AppStorage.get<UserInfo>('currentUser');

    let neededNew = plan.dailyNew;
    let neededReview = plan.dailyReview;

    if (currentUser && currentUser.lastStudyDate === new Date().toDateString()) {
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
      let wordId = word.content.word.wordId;
      if (progressMap[wordId]) {
        learned.push(word);
      } else {
        unlearned.push(word);
      }
    }

    let finalNew = unlearned.slice(0, neededNew);

    learned.sort((a, b) => {
      return progressMap[a.content.word.wordId].nextReviewDate - progressMap[b.content.word.wordId].nextReviewDate;
    });

    let finalReview = learned.slice(0, neededReview);

    let todayQueue: WordEntry[] = [];
    if (plan.studyMode === 0) {
      todayQueue = finalNew.concat(finalReview);
    } else {
      todayQueue = finalNew.concat(finalReview);
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
      let wordId = allWords[i].content.word.wordId;
      let progress = progressMap[wordId];
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
      // 🌟 精准返回目前库里还能榨出多少词
      availableNew: newQueueCount,
      availableReview: reviewQueueCount
    };
  }
}