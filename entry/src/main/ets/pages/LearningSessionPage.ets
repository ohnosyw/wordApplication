// entry/src/main/ets/pages/LearningSessionPage.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { WordEntry, TransItem, SentenceItem } from '../model/WordModel'
import { Ebbinghaus, WordProgress } from '../utils/Ebbinghaus'
import { WordService } from '../utils/WordService'
import { ProgressManager } from '../utils/ProgressManager'
import { PlanData } from '../model/StudyPlan'
import { UserManager } from '../utils/UserManager'
import { CollectionManager } from '../utils/CollectionManager'
import { DataLoader } from '../utils/DataLoader'

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

  @State lastAnswerIsKnown: boolean = false;
  private previousProgressBackup: WordProgress | null = null;

  private initialNewWordIds: string[] = [];
  private completedWordIds: string[] = [];

  @State isCollectionMode: boolean = false;
  @State isCurrentWordCollected: boolean = false;
  private currentBookId: string = '';
  private currentBookName: string = '';

  aboutToAppear() {
    this.loadWords();
  }

  onBackPress() {
    this.saveSessionToCache();
    return false;
  }

  async saveSessionToCache() {
    if (this.wordQueue.length === 0) return;

    if (this.isCollectionMode) {
      if (this.currentIndex < this.wordQueue.length) {
        let currentWordId = this.wordQueue[this.currentIndex].content.word.wordId;
        await CollectionManager.setLastWordId(getContext(this), this.currentBookId, currentWordId);
      }
      return;
    }

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

  async loadWords() {
    this.isLoading = true;
    let params = router.getParams() as Record<string, string | string[]>;

    if (params && params['mode'] === 'collection') {
      this.isCollectionMode = true;
      this.currentBookId = params['bookId'] as string;
      this.currentBookName = params['bookName'] as string;

      let cols = await CollectionManager.getCollections(getContext(this));
      let targetWordIds: string[] = [];
      let dailyLimit = 20;
      let lastWordId: string | undefined = undefined;

      if (cols[this.currentBookId]) {
        targetWordIds = cols[this.currentBookId].wordIds;
        dailyLimit = cols[this.currentBookId].dailyLimit || 20;
        lastWordId = cols[this.currentBookId].lastWordId;
      }

      let allWords = await DataLoader.loadWordBook(getContext(this), `${this.currentBookId}.json`);
      let collectionWords = allWords.filter(w => targetWordIds.includes(w.content.word.wordId));

      if (collectionWords.length > 0) {
        let startIndex = 0;
        if (lastWordId) {
          let idx = collectionWords.findIndex(w => w.content.word.wordId === lastWordId);
          if (idx !== -1) startIndex = idx;
        }

        let finalQueue: WordEntry[] = [];
        let count = Math.min(dailyLimit, collectionWords.length);
        for (let i = 0; i < count; i++) {
          let idx = (startIndex + i) % collectionWords.length;
          finalQueue.push(collectionWords[idx]);
        }

        this.wordQueue = finalQueue;
        this.sessionTotalReview = this.wordQueue.length;
      }

    } else {
      let plan = AppStorage.get<PlanData>('studyPlan');
      if (!plan) { promptAction.showToast({ message: '计划异常' }); router.back(); return; }

      this.currentBookId = plan.bookId;
      this.currentBookName = plan.bookName;

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
          this.isShowDetails = cachedSession.isShowDetails || false;
          this.lastAnswerIsKnown = cachedSession.lastAnswerIsKnown || false;

          await this.prepareCurrentWord();
          promptAction.showToast({ message: '已为您恢复上次的学习进度' });
          this.isLoading = false;
          return;
        }
      }
      this.wordQueue = await WordService.generateTodayQueue(getContext(this), plan);
    }

    if (this.wordQueue.length > 0) {
      if (!this.isCollectionMode) {
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
      }
      await this.prepareCurrentWord();
      this.saveSessionToCache();
    } else {
      promptAction.showToast({ message: '太棒了！没有任务啦。' });
      setTimeout(() => { router.back() }, 1500);
    }
    this.isLoading = false;
  }

  async prepareCurrentWord() {
    let wordId = this.wordQueue[this.currentIndex].content.word.wordId;

    let map = await ProgressManager.getProgressMap(getContext(this));
    if (map[wordId]) {
      this.currentProgress = map[wordId];
    } else {
      this.currentProgress = { wordId: wordId, repetition: 0, interval: 0, efactor: 2.5, nextReviewDate: Date.now() }
    }
    this.isCurrentWordCollected = await CollectionManager.isCollected(getContext(this), this.currentBookId, wordId);
  }

  async toggleStar() {
    let wordId = this.wordQueue[this.currentIndex].content.word.wordId;
    this.isCurrentWordCollected = await CollectionManager.toggleCollection(
      getContext(this),
      this.currentBookId,
      this.currentBookName,
      wordId
    );
    promptAction.showToast({ message: this.isCurrentWordCollected ? '已加入收藏' : '已取消收藏' });
  }

  async handleAnswer(isKnown: boolean) {
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
    this.currentProgress = newProgress;

    let wId = this.currentProgress.wordId;

    if (isKnown && !this.completedWordIds.includes(wId)) {
      this.completedWordIds.push(wId);
      if (this.isCollectionMode) {
        this.sessionFinishedReview++;
      } else {
        if (this.initialNewWordIds.includes(wId)) {
          this.sessionFinishedNew++;
          await UserManager.updateUserStats(getContext(this), 1, 0);

          // 🌟 修复 Bug 1：只有真正掌握了新的词，书本总进度才加 1
          let currentTotal = AppStorage.get<number>('totalLearnedInBook') || 0;
          AppStorage.setOrCreate('totalLearnedInBook', currentTotal + 1);

        } else {
          this.sessionFinishedReview++;
          await UserManager.updateUserStats(getContext(this), 0, 1);
        }
      }
    }

    if (!isKnown) {
      this.wordQueue.push(this.wordQueue[this.currentIndex]);
    }
    this.isShowDetails = true;
    this.saveSessionToCache();
  }

  async markAsWrong() {
    if (!this.previousProgressBackup) return;

    let newProgress = Ebbinghaus.calculateNextReview(this.previousProgressBackup, false);
    await ProgressManager.saveWordProgress(getContext(this), newProgress);
    this.currentProgress = newProgress;

    let wId = this.currentProgress.wordId;
    let index = this.completedWordIds.indexOf(wId);

    if (index > -1) {
      this.completedWordIds.splice(index, 1);
      if (this.isCollectionMode) {
        this.sessionFinishedReview--;
      } else {
        if (this.initialNewWordIds.includes(wId)) {
          this.sessionFinishedNew--;
          await UserManager.updateUserStats(getContext(this), -1, 0);

          // 🌟 修复 Bug 1（反向撤销）：新词记错了撤回，书本总进度也减 1
          let currentTotal = AppStorage.get<number>('totalLearnedInBook') || 0;
          AppStorage.setOrCreate('totalLearnedInBook', Math.max(0, currentTotal - 1));

        } else {
          this.sessionFinishedReview--;
          await UserManager.updateUserStats(getContext(this), 0, -1);
        }
      }
    }

    this.wordQueue.push(this.wordQueue[this.currentIndex]);
    this.lastAnswerIsKnown = false;
    promptAction.showToast({ message: '已标记为不认识，稍后将重新复习' });
    this.saveSessionToCache();
  }

  async nextWord() {
    if (this.currentIndex < this.wordQueue.length - 1) {
      this.currentIndex += 1;
      this.isShowDetails = false;
      await this.prepareCurrentWord();
      this.saveSessionToCache();
    } else {
      let totalLearned = this.sessionFinishedNew + this.sessionFinishedReview;

      if (!this.isCollectionMode) {
        await UserManager.clearActiveSession(getContext(this));
        await UserManager.recordCheckIn(getContext(this));
        promptAction.showToast({ message: `今日任务已完成！本次累计掌握了 ${totalLearned} 个单词`, duration: 2000 });
      } else {
        let cols = await CollectionManager.getCollections(getContext(this));
        if (cols[this.currentBookId] && cols[this.currentBookId].wordIds.length > 0) {
          let globalWords = cols[this.currentBookId].wordIds;
          let lastCompletedId = this.wordQueue[this.wordQueue.length - 1].content.word.wordId;
          let idx = globalWords.indexOf(lastCompletedId);
          let nextIdx = (idx + 1) % globalWords.length;
          await CollectionManager.setLastWordId(getContext(this), this.currentBookId, globalWords[nextIdx]);
        }
        promptAction.showToast({ message: `特训完成！共复习 ${totalLearned} 个收藏词汇`, duration: 2000 });
      }
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
            if (this.isCollectionMode) {
              Text(`特训 ${this.sessionFinishedReview}/${this.sessionTotalReview}`).fontSize(14).fontColor('#FF9800')
            } else {
              Text(`新词 ${this.sessionFinishedNew}/${this.sessionTotalNew}`).fontSize(14).fontColor('#F44336').margin({ right: 15 })
              Text(`复习 ${this.sessionFinishedReview}/${this.sessionTotalReview}`).fontSize(14).fontColor('#2196F3')
            }
          }
        }
      }.width('100%').padding(16)

      if (this.isLoading) {
        Column() { LoadingProgress().width(50).height(50).color('#4CAF50'); Text('正在准备数据...').fontSize(16).fontColor('#666').margin({ top: 20 }) }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.wordQueue.length > 0) {
        Column() {
          Row() {
            if (!this.isCollectionMode) {
              Text(this.initialNewWordIds.includes(this.wordQueue[this.currentIndex].content.word.wordId) ? '新词' : '复习')
                .fontSize(12).fontColor(this.initialNewWordIds.includes(this.wordQueue[this.currentIndex].content.word.wordId) ? '#F44336' : '#2196F3')
                .backgroundColor(this.initialNewWordIds.includes(this.wordQueue[this.currentIndex].content.word.wordId) ? '#FFEBEE' : '#E3F2FD')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(10)
            } else {
              Text('收藏复习')
                .fontSize(12).fontColor('#FF9800').backgroundColor('#FFF3E0')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(10)
            }

            Blank()

            Text(this.isCurrentWordCollected ? '★' : '☆')
              .fontSize(28).fontColor(this.isCurrentWordCollected ? '#4CAF50' : '#CCCCCC')
              .onClick(() => { this.toggleStar() })

          }.width('100%').alignItems(VerticalAlign.Center)

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

        Row() {
          if (!this.isShowDetails) {
            Button('不认识').width('45%').height(50).backgroundColor('#FFF3E0').fontColor('#FF9800').fontSize(18).onClick(() => { this.handleAnswer(false) })
            Button('认识').width('45%').height(50).backgroundColor('#E8F5E9').fontColor('#4CAF50').fontSize(18).onClick(() => { this.handleAnswer(true) })
          } else {
            if (this.lastAnswerIsKnown) {
              Button('记错了')
                .width('40%').height(50).backgroundColor('#FFEBEE').fontColor('#F44336').fontSize(18)
                .onClick(() => { this.markAsWrong() })
              Button(this.currentIndex === this.wordQueue.length - 1 ? '完成特训 🎉' : '下一个')
                .width('55%').height(50).backgroundColor('#4CAF50').fontSize(18)
                .onClick(() => { this.nextWord() })
            } else {
              Button(this.currentIndex === this.wordQueue.length - 1 ? '完成特训 🎉' : '下一个')
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