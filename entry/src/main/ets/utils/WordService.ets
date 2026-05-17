// entry/src/main/ets/utils/WordService.ets
import { DataLoader } from './DataLoader';
import { ProgressManager } from './ProgressManager';
import { WordEntry } from '../model/WordModel';
import { PlanData } from '../model/StudyPlan';
import { UserInfo } from './UserManager';

// 用于在首页展示今日任务的总览情况
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

    // 初始化基础任务量（从计划中读取）
    let neededNew = plan.dailyNew;
    let neededReview = plan.dailyReview;

    //如果用户今天已经学习过
    if (currentUser && currentUser.lastStudyDate === new Date().toDateString()) {
      // 计算还需要背多少新词：今日目标新词数 - 今日已背新词数
      let targetNew = currentUser.todayTargetNew !== undefined ? currentUser.todayTargetNew : plan.dailyNew;
      let studiedNew = currentUser.todayStudiedNew !== undefined ? currentUser.todayStudiedNew : 0;
      neededNew = Math.max(0, targetNew - studiedNew);

      // 计算还需要复习多少词：今日目标复习数 - 今日已复习旧词数
      let targetReview = currentUser.todayTargetReview !== undefined ? currentUser.todayTargetReview : plan.dailyReview;
      let studiedReview = currentUser.todayStudiedReview !== undefined ? currentUser.todayStudiedReview : 0;
      neededReview = Math.max(0, targetReview - studiedReview);
    }

    // 拉取数据源：词书原文 + 用户的记忆进度表
    let allWords = await DataLoader.loadWordBook(context, `${plan.bookId}.json`);
    let progressMap = await ProgressManager.getProgressMap(context);

    // 未学过的新词池、已学过的旧词池
    let unlearned: WordEntry[] = [];
    let learned: WordEntry[] = [];

    // 遍历整本词书，将单词划入对应的池子
    for (let i = 0; i < allWords.length; i++) {
      let word = allWords[i];
      // 给 ID 加上词书专属命名空间，防止词书间进度串联
      let namespacedId = `${plan.bookId}_${word.content.word.wordId}`;

      //进度表中单词查询
      if (progressMap[namespacedId]) {
        learned.push(word);
      } else {
        unlearned.push(word);
      }
    }

    // 按顺序从没学过的池子里截取需要的数量
    let finalNew = unlearned.slice(0, neededNew);

    //按下次复习日期排序已学单词
    learned.sort((a, b) => {
      // 单词 a, b 的学习进度
      let aProg = progressMap[`${plan.bookId}_${a.content.word.wordId}`];
      let bProg = progressMap[`${plan.bookId}_${b.content.word.wordId}`];
      // 单词 a, b 的下次复习时间
      let dateA = aProg ? aProg.nextReviewDate : 0;
      let dateB = bProg ? bProg.nextReviewDate : 0;
      // 按时间从小到大排列
      return dateA - dateB;
    });

    // 截取最急需复习的前 neededReview 个单词
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

  // 获取今日任务概况（用于首页环形进度条、数值展示的计算）
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
      // 查询该单词有无进度
      let progress = progressMap[namespacedId];
      if (progress) {
        totalLearnedCount++;
        // 判断是否到了该复习的时间
        if (progress.nextReviewDate <= now) {
          reviewQueueCount++;
        }
      } else {
        newQueueCount++;// 进度表里没有，就是新词
      }
    }

    return {
      // 实际每日新词数：取（计划值）和（词库剩余新词数）的最小值
      newCount: Math.min(newQueueCount, plan.dailyNew),
      reviewCount: Math.min(reviewQueueCount, plan.dailyReview),
      totalLearned: totalLearnedCount,
      availableNew: newQueueCount,
      availableReview: reviewQueueCount
    };
  }
}