// entry/src/main/ets/pages/LearningSessionPage.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { WordEntry, TransItem, SentenceItem } from '../model/WordModel'
import { Ebbinghaus, WordProgress } from '../utils/Ebbinghaus'
import { WordService, TaskInfo } from '../utils/WordService'
import { ProgressManager } from '../utils/ProgressManager'
import { PlanData } from '../model/StudyPlan'
import { UserManager } from '../utils/UserManager'

interface CacheData {
  date: string;
  wordQueue: WordEntry[];
  currentIndex: number;
  sessionTotalNew: number;
  sessionTotalReview: number;
  sessionFinishedNew: number;
  sessionFinishedReview: number;
  initialNewWordIds: string[];
  completedWordIds: string[];
  // 🌟 将界面状态也存入快照，防止在背面退出时重置
  isShowDetails: boolean;
  lastAnswerIsKnown: boolean;
}

@Entry
@Component
struct LearningSessionPage {
  @State wordQueue: WordEntry[] = [];
  @State currentIndex: number = 0;
  @State isShowDetails: boolean = false;
  @State isLoading: boolean = true;
  @State currentProgress: WordProgress = { wordId: '', repetition: 0, interval: 0, efactor: 2.5, nextReviewDate: 0 }

  @State sessionTotalNew: number = 0;
  @State sessionTotalReview: number = 0;
  @State sessionFinishedNew: number = 0;
  @State sessionFinishedReview: number = 0;

  // 🌟 新增：用于“记错了”功能的状态追踪
  @State lastAnswerIsKnown: boolean = false;
  private previousProgressBackup: WordProgress | null = null; // 备份答题前的进度

  private initialNewWordIds: string[] = [];
  private completedWordIds: string[] = [];

  aboutToAppear() {
    this.loadTodayWords();
  }

  onBackPress() {
    this.saveSessionToCache();
    return false;
  }

  async saveSessionToCache() {
    if (this.wordQueue.length === 0) return;
    let sessionData: CacheData = {
      date: new Date().toDateString(),
      wordQueue: this.wordQueue,
      currentIndex: this.currentIndex,
      sessionTotalNew: this.sessionTotalNew,
      sessionTotalReview: this.sessionTotalReview,
      sessionFinishedNew: this.sessionFinishedNew,
      sessionFinishedReview: this.sessionFinishedReview,
      initialNewWordIds: this.initialNewWordIds,
      completedWordIds: this.completedWordIds,
      isShowDetails: this.isShowDetails,
      lastAnswerIsKnown: this.lastAnswerIsKnown
    };
    await UserManager.saveActiveSession(getContext(this), JSON.stringify(sessionData));
  }

  async loadTodayWords() {
    this.isLoading = true;
    let plan = AppStorage.get<PlanData>('studyPlan');
    if (!plan) { promptAction.showToast({ message: '计划异常' }); router.back(); return; }

    let sessionStr = await UserManager.getActiveSession(getContext(this));
    let today = new Date().toDateString();

    if (sessionStr) {
      let cachedSession = JSON.parse(sessionStr) as CacheData;
      if (cachedSession.date === today && cachedSession.wordQueue && cachedSession.wordQueue.length > 0) {
        this.wordQueue = cachedSession.wordQueue;
        this.currentIndex = cachedSession.currentIndex;
        this.sessionTotalNew = cachedSession.sessionTotalNew;
        this.sessionTotalReview = cachedSession.sessionTotalReview;
        this.sessionFinishedNew = cachedSession.sessionFinishedNew;
        this.sessionFinishedReview = cachedSession.sessionFinishedReview;
        this.initialNewWordIds = cachedSession.initialNewWordIds;
        this.completedWordIds = cachedSession.completedWordIds;

        // 恢复退出时的正反面状态
        this.isShowDetails = cachedSession.isShowDetails || false;
        this.lastAnswerIsKnown = cachedSession.lastAnswerIsKnown || false;

        await this.initWordProgress(this.wordQueue[this.currentIndex].content.word.wordId);
        promptAction.showToast({ message: '已为您恢复上次的学习进度' });
        this.isLoading = false;
        return;
      }
    }

    this.wordQueue = await WordService.generateTodayQueue(getContext(this), plan);

    if (this.wordQueue.length > 0) {
      let map = await ProgressManager.getProgressMap(getContext(this));
      for (let word of this.wordQueue) {
        let wId = word.content.word.wordId;
        if (map[wId]) {
          this.sessionTotalReview++;
        } else {
          this.sessionTotalNew++;
          this.initialNewWordIds.push(wId);
        }
      }
      await this.initWordProgress(this.wordQueue[0].content.word.wordId);
      this.saveSessionToCache();
    } else {
      promptAction.showToast({ message: '太棒了！没有任务啦。' });
      setTimeout(() => { router.back() }, 1500);
    }
    this.isLoading = false;
  }

  async initWordProgress(wordId: string) {
    let map = await ProgressManager.getProgressMap(getContext(this));
    if (map[wordId]) {
      this.currentProgress = map[wordId];
    } else {
      this.currentProgress = { wordId: wordId, repetition: 0, interval: 0, efactor: 2.5, nextReviewDate: Date.now() }
    }
  }

  async handleAnswer(isKnown: boolean) {
    // 🌟 1. 备份当前进度，为“后悔药”做准备
    this.previousProgressBackup = {
      wordId: this.currentProgress.wordId,
      repetition: this.currentProgress.repetition,
      interval: this.currentProgress.interval,
      efactor: this.currentProgress.efactor,
      nextReviewDate: this.currentProgress.nextReviewDate
    };
    this.lastAnswerIsKnown = isKnown;

    let newProgress = Ebbinghaus.calculateNextReview(this.currentProgress, isKnown);
    await ProgressManager.saveWordProgress(getContext(this), newProgress);
    this.currentProgress = newProgress; // 更新本地内存

    let map = await ProgressManager.getProgressMap(getContext(this));
    AppStorage.setOrCreate('totalLearnedInBook', Object.keys(map).length);

    let wId = this.currentProgress.wordId;

    if (isKnown && !this.completedWordIds.includes(wId)) {
      this.completedWordIds.push(wId);
      if (this.initialNewWordIds.includes(wId)) {
        this.sessionFinishedNew++;
        await UserManager.updateUserStats(getContext(this), 1, 0);
      } else {
        this.sessionFinishedReview++;
        await UserManager.updateUserStats(getContext(this), 0, 1);
      }
    }

    if (!isKnown) {
      this.wordQueue.push(this.wordQueue[this.currentIndex]);
    }
    this.isShowDetails = true;
    this.saveSessionToCache();
  }

  // 🌟 核心新增：记错了（完美回滚机制）
  async markAsWrong() {
    if (!this.previousProgressBackup) return;

    // 1. 基于备份的旧进度，重新按“不认识”计算艾宾浩斯惩罚
    let newProgress = Ebbinghaus.calculateNextReview(this.previousProgressBackup, false);
    await ProgressManager.saveWordProgress(getContext(this), newProgress);
    this.currentProgress = newProgress;

    let wId = this.currentProgress.wordId;

    // 2. 撤回完成清单里的记录，并把顶部分子和底层数据库扣除 1
    let index = this.completedWordIds.indexOf(wId);
    if (index > -1) {
      this.completedWordIds.splice(index, 1); // 移出已完成名单
      if (this.initialNewWordIds.includes(wId)) {
        this.sessionFinishedNew--;
        await UserManager.updateUserStats(getContext(this), -1, 0); // 告诉大脑扣分
      } else {
        this.sessionFinishedReview--;
        await UserManager.updateUserStats(getContext(this), 0, -1);
      }
    }

    // 3. 把这个词重新塞入队尾
    this.wordQueue.push(this.wordQueue[this.currentIndex]);

    // 4. 隐藏后悔按钮，并提示用户
    this.lastAnswerIsKnown = false;
    promptAction.showToast({ message: '已标记为不认识，稍后将重新复习' });
    this.saveSessionToCache();
  }

  async nextWord() {
    if (this.currentIndex < this.wordQueue.length - 1) {
      this.currentIndex += 1;
      this.isShowDetails = false;
      await this.initWordProgress(this.wordQueue[this.currentIndex].content.word.wordId);
      this.saveSessionToCache();
    } else {
      await UserManager.clearActiveSession(getContext(this));

      // 🌟 新增：只要走到这一步（无论是当天首个任务还是加练任务），都算今天打卡成功！
      await UserManager.recordCheckIn(getContext(this));

      let totalLearned = this.sessionFinishedNew + this.sessionFinishedReview;
      promptAction.showToast({ message: `今日任务已完成！本次累计掌握了 ${totalLearned} 个单词`, duration: 2000 });
      setTimeout(() => { router.back() }, 1500);
    }
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => {
          this.saveSessionToCache();
          router.back();
        })
        Blank()
        if (!this.isLoading && this.wordQueue.length > 0) {
          Row() {
            Text(`新词 ${this.sessionFinishedNew}/${this.sessionTotalNew}`).fontSize(14).fontColor('#F44336').margin({ right: 15 })
            Text(`复习 ${this.sessionFinishedReview}/${this.sessionTotalReview}`).fontSize(14).fontColor('#2196F3')
          }
        }
      }.width('100%').padding(16)

      if (this.isLoading) {
        Column() { LoadingProgress().width(50).height(50).color('#4CAF50'); Text('生成任务中...').fontSize(16).fontColor('#666').margin({ top: 20 }) }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.wordQueue.length > 0) {
        Column() {
          Row() {
            Text(this.initialNewWordIds.includes(this.wordQueue[this.currentIndex].content.word.wordId) ? '新词' : '复习')
              .fontSize(12).fontColor(this.initialNewWordIds.includes(this.wordQueue[this.currentIndex].content.word.wordId) ? '#F44336' : '#2196F3')
              .backgroundColor(this.initialNewWordIds.includes(this.wordQueue[this.currentIndex].content.word.wordId) ? '#FFEBEE' : '#E3F2FD')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(10)
          }.width('100%').justifyContent(FlexAlign.End)

          Text(this.wordQueue[this.currentIndex].headWord).fontSize(40).fontWeight(FontWeight.Bold).fontColor('#333').margin({ top: 10 })
          if (this.wordQueue[this.currentIndex].content.word.content.usphone) {
            Text(`美 [${this.wordQueue[this.currentIndex].content.word.content.usphone!}]`).fontSize(16).fontColor('#666').margin({ top: 10 })
          }

          if (!this.isShowDetails) { Blank() } else {
            Scroll() {
              Column() {
                if (this.wordQueue[this.currentIndex].content.word.content.trans) {
                  Column() {
                    ForEach(this.wordQueue[this.currentIndex].content.word.content.trans || [], (tran: TransItem) => {
                      Row() { Text(tran.pos + ".").fontSize(16).fontColor('#4CAF50').fontWeight(FontWeight.Bold).margin({ right: 8 }); Text(tran.tranCn).fontSize(16).fontColor('#333') }.width('100%').margin({ bottom: 5 })
                    })
                  }.padding(15).backgroundColor('#F5F5F5').borderRadius(10).width('100%').margin({ top: 30 })
                }
                if (this.wordQueue[this.currentIndex].content.word.content.sentence) {
                  Column() {
                    Text('语境例句').fontSize(14).fontColor('#999').width('100%').margin({ bottom: 10 })
                    ForEach(this.wordQueue[this.currentIndex].content.word.content.sentence?.sentences || [], (sen: SentenceItem) => {
                      Column() { Text(sen.sContent).fontSize(16).fontColor('#333').fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 5 }); Text(sen.sCn).fontSize(14).fontColor('#666').width('100%') }.margin({ bottom: 15 })
                    })
                  }.padding(15).width('100%').margin({ top: 20 })
                }
              }.width('100%').alignItems(HorizontalAlign.Start)
            }.layoutWeight(1).margin({ top: 20 })
          }
        }.width('90%').layoutWeight(1).backgroundColor(Color.White).borderRadius(20).padding(20).shadow({ radius: 10, color: '#1A000000', offsetX: 0, offsetY: 5 }).margin({ top: 10, bottom: 20 })

        // ------------------ 🌟 底部按钮区：动态展示“记错了” ------------------
        Row() {
          if (!this.isShowDetails) {
            Button('不认识').width('45%').height(50).backgroundColor('#FFF3E0').fontColor('#FF9800').fontSize(18).onClick(() => { this.handleAnswer(false) })
            Button('认识').width('45%').height(50).backgroundColor('#E8F5E9').fontColor('#4CAF50').fontSize(18).onClick(() => { this.handleAnswer(true) })
          } else {
            // 如果上一步点的是“认识”，则显示后悔药按钮
            if (this.lastAnswerIsKnown) {
              Button('记错了')
                .width('40%').height(50).backgroundColor('#FFEBEE').fontColor('#F44336').fontSize(18)
                .onClick(() => { this.markAsWrong() })
              Button(this.currentIndex === this.wordQueue.length - 1 ? '完成任务 🎉' : '下一个')
                .width('55%').height(50).backgroundColor('#4CAF50').fontSize(18)
                .onClick(() => { this.nextWord() })
            } else {
              // 否则只显示唯一的下一个/完成按钮
              Button(this.currentIndex === this.wordQueue.length - 1 ? '完成任务 🎉' : '下一个')
                .width('100%').height(50).backgroundColor('#4CAF50').fontSize(18)
                .onClick(() => { this.nextWord() })
            }
          }
        }.width('90%').justifyContent(FlexAlign.SpaceBetween).margin({ bottom: 30 })
      } else {
        Text('暂无学习任务').margin({ top: 100 })
      }
    }.width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}