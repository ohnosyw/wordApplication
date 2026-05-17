import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { WordEntry, TransItem, SentenceItem } from '../model/WordModel'
import { Ebbinghaus, WordProgress } from '../utils/Ebbinghaus'
import { WordService } from '../utils/WordService'
import { ProgressManager } from '../utils/ProgressManager'
import { PlanData } from '../model/StudyPlan'
import { UserManager, UserInfo } from '../utils/UserManager'
import { CollectionManager } from '../utils/CollectionManager'
import { DataLoader } from '../utils/DataLoader'

// 用户中途退出时，整个状态机会被序列化进此结构。
interface CacheData {
  date: string;
  wordQueue: WordEntry[];// 尚未背完的队列
  currentIndex: number;// 游标位置
  sessionTotalNew: number;// 本次会话总新词数
  sessionTotalReview: number;// 本次会话总复习数
  sessionFinishedNew: number;// 已完成的新词数
  sessionFinishedReview: number;// 已完成的复习数
  initialNewWordIds: string[];// 用于区分“这是新词还是旧词”的字典
  completedWordIds: string[];// 在本次会话中已经彻底掌握的词
  isShowDetails: boolean;// 退出时是否正处于展示释义的状态
  lastAnswerIsKnown: boolean;// 退出时的最后一次回答状态
}

//当天任务清单
interface DailyQueueData {
  wordQueue: WordEntry[];
  initialNewWordIds: string[];
  sessionTotalNew: number;
  sessionTotalReview: number;
}

// 自定义完成词书弹窗
@CustomDialog
struct CompletionDialog {
  controller: CustomDialogController
  bookName: string = ''
  onConfirm: (index: number) => void = () => {}

  build() {
    Column() {
      Image($r('app.media.ic_duck'))
        .width(80)
        .height(80)
        .margin({ top: -40, bottom: 10 })

      Text(' 恭喜完成该词书！')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .margin({ bottom: 15 })

      Text(`您已成功背完《${this.bookName}》所有单词！`)
        .fontSize(14)
        .fontColor('#666')
        .textAlign(TextAlign.Center)
        .lineHeight(20)
        .padding({ left: 20, right: 20 })
        .margin({ bottom: 25 })

      Button('更换新词书')
        .width('90%')
        .height(45)
        .backgroundColor('#FFCA28')
        .fontColor('#333')
        .margin({ bottom: 12 })
        .onClick(() => {
          this.controller.close()
          this.onConfirm(0)
        })

      Button('重置并二刷')
        .width('90%')
        .height(45)
        .backgroundColor('#F7F7F7')
        .fontColor('#FF9800')
        .border({ width: 1, color: '#FFCA28' })
        .margin({ bottom: 20 })
        .onClick(() => {
          this.controller.close()
          this.onConfirm(1)
        })
    }
    .width('90%')
    .padding(20)
    .borderRadius(20)
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 1.0]]
    })
    .shadow({ radius: 20, color: '#33000000' })
  }
}

@Entry
@Component
struct LearningSessionPage {
  @State wordQueue: WordEntry[] = [];// 当前需要背诵的所有单词队列
  @State currentIndex: number = 0;// 当前卡片指向队列中的第几个单词
  @State isShowDetails: boolean = false;// 是否展示释义
  @State isLoading: boolean = true;
  @State currentProgress: WordProgress = { wordId: '', repetition: 0, interval: 0, efactor: 2.5, nextReviewDate: 0 } as WordProgress;

  // 会话统计 (用于顶部状态栏展示：10/20)
  @State sessionTotalNew: number = 0;
  @State sessionTotalReview: number = 0;
  @State sessionFinishedNew: number = 0;
  @State sessionFinishedReview: number = 0;

  @State lastAnswerIsKnown: boolean = false;
  private previousProgressBackup: WordProgress | null = null;// 备份点击前的进度，用于撤销操作

  private initialNewWordIds: string[] = [];
  private completedWordIds: string[] = [];

  // 模式切换状态
  @State isCollectionMode: boolean = false;// 是否是“收藏夹特训模式”
  @State isCurrentWordCollected: boolean = false;// 当前单词是否已被标星
  private currentBookId: string = '';
  private currentBookName: string = '';

  private isClicking: boolean = false;

  // 弹窗控制器
  completionDialogController: CustomDialogController = new CustomDialogController({
    builder: CompletionDialog({
      bookName: this.currentBookName,
      onConfirm: (index: number) => { this.handleCompletionSelection(index) }
    }),
    autoCancel: false,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  aboutToAppear() {
    this.loadWords();// 加载单词数据
  }

  onBackPress() {
    this.saveSessionToCache();// 自动保存当前学习进度
    return false;
  }

  // 将当前的内存状态全量存入沙箱
  async saveSessionToCache() {
    if (this.wordQueue.length === 0) return;

    // 收藏模式的断点续传（只记录上次背到了哪个词）
    if (this.isCollectionMode) {
      if (this.currentIndex < this.wordQueue.length) {
        let currentWordId = this.wordQueue[this.currentIndex].content.word.wordId;
        await CollectionManager.setLastWordId(getContext(this), this.currentBookId, currentWordId);
      }
      return;
    }

    // 正常模式的断点续传（序列化整个上下文，包括游标和打分）
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

  // 决定数据是从头生成，还是从缓存中恢复
  async loadWords() {
    this.isLoading = true;
    let params = router.getParams() as Record<string, Object>;

    // 用户从收藏页点击“开始特训”进入
    if (params && params['mode'] === 'collection') {
      this.isCollectionMode = true;
      this.currentBookId = params['bookId'] as string;
      this.currentBookName = params['bookName'] as string;

      // 获取该用户收藏的所有单词ID
      let cols = await CollectionManager.getCollections(getContext(this));
      let targetWordIds: string[] = [];
      let dailyLimit = 20;
      let lastWordId: string | undefined = undefined;

      if (cols[this.currentBookId]) {
        targetWordIds = cols[this.currentBookId].wordIds;
        dailyLimit = cols[this.currentBookId].dailyLimit || 20;
        lastWordId = cols[this.currentBookId].lastWordId;
      }

      // 加载整本词书，并过滤出收藏的单词
      let allWords = await DataLoader.loadWordBook(getContext(this), `${this.currentBookId}.json`);
      let collectionWords = allWords.filter(w => targetWordIds.includes(w.content.word.wordId));

      if (collectionWords.length > 0) {
        let startIndex = 0;
        if (lastWordId) {
          let idx = collectionWords.findIndex(w => w.content.word.wordId === lastWordId);
          if (idx !== -1) startIndex = idx;
        }

        // 从上次学到的单词开始，取 N 个单词
        let finalQueue: WordEntry[] = [];
        let count = Math.min(dailyLimit, collectionWords.length);
        for (let i = 0; i < count; i++) {
          let idx = (startIndex + i) % collectionWords.length;
          finalQueue.push(collectionWords[idx]);
        }

        // 赋值给学习队列
        this.wordQueue = finalQueue;
        this.sessionTotalReview = this.wordQueue.length;
      }
    } else {
      // 常规打卡模式
      let plan = AppStorage.get<PlanData>('studyPlan');
      if (!plan) { promptAction.showToast({ message: '计划异常' }); router.back(); return; }

      this.currentBookId = plan.bookId;
      this.currentBookName = plan.bookName;

      let sessionStr = await UserManager.getActiveSession(getContext(this));
      let today = new Date().toDateString();
      if (sessionStr) {
        let cachedSession = JSON.parse(sessionStr) as CacheData;
        // 如果是今天的进度，直接恢复
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

      // 检查有没有今日已生成的队列
      let queueStr = await UserManager.getDailyQueue(getContext(this), this.currentBookId, today);
      if (queueStr) {
        let dailyData = JSON.parse(queueStr) as DailyQueueData;
        this.wordQueue = dailyData.wordQueue;
        this.initialNewWordIds = dailyData.initialNewWordIds;
        this.sessionTotalNew = dailyData.sessionTotalNew;
        this.sessionTotalReview = dailyData.sessionTotalReview;

        this.currentIndex = 0;
        this.sessionFinishedNew = 0;
        this.sessionFinishedReview = 0;
        this.completedWordIds = [];
        this.isShowDetails = false;
        this.lastAnswerIsKnown = false;
      } else {
        // 今天已经生成过学习列表
        this.wordQueue = await WordService.generateTodayQueue(getContext(this), plan);
        if (this.wordQueue.length > 0) {
          let map = await ProgressManager.getProgressMap(getContext(this));
          // 遍历队列，区分哪些是新词，哪些是复习词
          for (let word of this.wordQueue) {
            let rawId = word.content.word.wordId;
            let namespacedId = `${this.currentBookId}_${rawId}`;
            if (map[namespacedId]) {
              this.sessionTotalReview++;
            } else {
              this.sessionTotalNew++;
              this.initialNewWordIds.push(rawId);
            }
          }

          let dailyData: DailyQueueData = {
            wordQueue: this.wordQueue,
            initialNewWordIds: this.initialNewWordIds,
            sessionTotalNew: this.sessionTotalNew,
            sessionTotalReview: this.sessionTotalReview
          };
          await UserManager.saveDailyQueue(getContext(this), this.currentBookId, today, JSON.stringify(dailyData));
        }
      }
    }

    if (this.wordQueue.length > 0) {
      await this.prepareCurrentWord();
      this.saveSessionToCache();
    } else {
      promptAction.showToast({ message: '太棒了！没有任务啦。' });
      setTimeout(() => { router.back() }, 1500);
    }
    this.isLoading = false;
  }

  // 检查当前单词在底层的复习进度，以及是否被标了星号
  async prepareCurrentWord() {
    let rawId = this.wordQueue[this.currentIndex].content.word.wordId;
    let namespacedId = `${this.currentBookId}_${rawId}`;

    let map = await ProgressManager.getProgressMap(getContext(this));
    if (map[namespacedId]) {
      this.currentProgress = map[namespacedId];
    } else {
      this.currentProgress = { wordId: namespacedId, repetition: 0, interval: 0, efactor: 2.5, nextReviewDate: Date.now() } as WordProgress;
    }
    this.isCurrentWordCollected = await CollectionManager.isCollected(getContext(this), this.currentBookId, rawId);
  }

  // 处理收藏单词逻辑
  async toggleStar() {
    let rawId = this.wordQueue[this.currentIndex].content.word.wordId;
    this.isCurrentWordCollected = await CollectionManager.toggleCollection(
      getContext(this),
      this.currentBookId,
      this.currentBookName,
      rawId
    );
    promptAction.showToast({ message: this.isCurrentWordCollected ? '已加入收藏' : '已取消收藏' });
  }

  // 处理用户的“认识 / 不认识”点击事件
  async handleAnswer(isKnown: boolean) {
    if (this.isClicking) return;
    this.isClicking = true;

    // 备份旧进度：如果用户点击“记错了”，需要靠这个备份来回滚
    this.previousProgressBackup = {
      wordId: this.currentProgress.wordId,
      repetition: this.currentProgress.repetition,
      interval: this.currentProgress.interval,
      efactor: this.currentProgress.efactor,
      nextReviewDate: this.currentProgress.nextReviewDate
    };

    this.lastAnswerIsKnown = isKnown;

    // 呼叫艾宾浩斯引擎，计算下一次复习时间，并落盘
    let newProgress = Ebbinghaus.calculateNextReview(this.currentProgress, isKnown);
    await ProgressManager.saveWordProgress(getContext(this), newProgress);
    this.currentProgress = newProgress;

    let rawId = this.wordQueue[this.currentIndex].content.word.wordId;

    // 如果“认识”，且这个词在本次会话中还没算过分
    if (isKnown && !this.completedWordIds.includes(rawId)) {
      this.completedWordIds.push(rawId);
      if (this.isCollectionMode) {
        this.sessionFinishedReview++;
      } else {
        if (this.initialNewWordIds.includes(rawId)) {
          this.sessionFinishedNew++;
          await UserManager.updateUserStats(getContext(this), 1, 0);
          let currentTotal = AppStorage.get<number>('totalLearnedInBook') || 0;
          AppStorage.setOrCreate('totalLearnedInBook', currentTotal + 1);
        } else {
          this.sessionFinishedReview++;
          await UserManager.updateUserStats(getContext(this), 0, 1);
        }
      }
    }

    // 如果“不认识”，将该词重新加入队列
    if (!isKnown) {
      this.wordQueue.push(this.wordQueue[this.currentIndex]);
    }
    this.isShowDetails = true;
    this.saveSessionToCache();
    this.isClicking = false;
  }

  // 处理用户的“记错了”点击事件
  async markAsWrong() {
    if (this.isClicking || !this.previousProgressBackup) return;
    this.isClicking = true;

    // 拿最初的备份去计算 false (不认识) 的结果
    let newProgress = Ebbinghaus.calculateNextReview(this.previousProgressBackup, false);
    await ProgressManager.saveWordProgress(getContext(this), newProgress);
    this.currentProgress = newProgress;

    let rawId = this.wordQueue[this.currentIndex].content.word.wordId;
    let index = this.completedWordIds.indexOf(rawId);

    // 扣除刚刚加上的统计分数
    if (index > -1) {
      this.completedWordIds.splice(index, 1);
      if (this.isCollectionMode) {
        this.sessionFinishedReview--;
      } else {
        if (this.initialNewWordIds.includes(rawId)) {
          this.sessionFinishedNew--;
          await UserManager.updateUserStats(getContext(this), -1, 0);
          let currentTotal = AppStorage.get<number>('totalLearnedInBook') || 0;
          AppStorage.setOrCreate('totalLearnedInBook', Math.max(0, currentTotal - 1));
        } else {
          this.sessionFinishedReview--;
          await UserManager.updateUserStats(getContext(this), 0, -1);
        }
      }
    }

    // 将该词再次追加到队列末尾
    this.wordQueue.push(this.wordQueue[this.currentIndex]);
    this.lastAnswerIsKnown = false;
    promptAction.showToast({ message: '已标记为不认识' });
    this.saveSessionToCache();
    this.isClicking = false;
  }

  // 处理用户完本逻辑
  async handleCompletionSelection(index: number) {
    if (index === 0) {
      router.replaceUrl({ url: 'pages/BookSelectPage' });
    } else if (index === 1) {
      await ProgressManager.clearBookProgress(getContext(this), this.currentBookId);
      AppStorage.setOrCreate('totalLearnedInBook', 0);
      let user = AppStorage.get<UserInfo>('currentUser');
      if (user) {
        user.todayStudiedCount = 0;
        user.todayStudiedNew = 0;
        user.todayStudiedReview = 0;
        UserManager.syncUserToAppStorage(user);
      }
      promptAction.showToast({ message: '进度已重置，开启二刷之旅！' });
      router.back();
    }
  }

  // 点击“下一个 / 完成任务”
  async nextWord() {
    if (this.isClicking) return;
    this.isClicking = true;

    // 还有下一个词，游标前移，重置卡片状态
    if (this.currentIndex < this.wordQueue.length - 1) {
      this.currentIndex += 1;
      this.isShowDetails = false;
      await this.prepareCurrentWord();
      this.saveSessionToCache();
      this.isClicking = false;
    } else {
      // 全部背完，执行清场与撒花逻辑
      let totalLearned = this.sessionFinishedNew + this.sessionFinishedReview;
      if (!this.isCollectionMode) {
        // 清除会话缓存，打上当天的 CheckIn (连签) 印记
        await UserManager.clearActiveSession(getContext(this));
        await UserManager.clearDailyQueue(getContext(this), this.currentBookId, new Date().toDateString());
        await UserManager.recordCheckIn(getContext(this));

        let plan = AppStorage.get<PlanData>('studyPlan');
        let currentTotal = AppStorage.get<number>('totalLearnedInBook') || 0;

        // 完本判断
        if (plan && currentTotal >= plan.totalWords && plan.totalWords > 0) {
          await UserManager.recordCompletedBook(getContext(this), plan);
          this.completionDialogController.open();
        } else {
          promptAction.showToast({ message: `今日任务已完成！本次掌握 ${totalLearned} 词`, duration: 2000 });
          setTimeout(() => { router.back() }, 1500);
        }
      } else {
        // 特训模式结束，锚点推进到下一个词
        let cols = await CollectionManager.getCollections(getContext(this));
        if (cols[this.currentBookId] && cols[this.currentBookId].wordIds.length > 0) {
          let globalWords = cols[this.currentBookId].wordIds;
          let lastCompletedId = this.wordQueue[this.wordQueue.length - 1].content.word.wordId;
          let idx = globalWords.indexOf(lastCompletedId);
          let nextIdx = (idx + 1) % globalWords.length;
          await CollectionManager.setLastWordId(getContext(this), this.currentBookId, globalWords[nextIdx]);
        }
        promptAction.showToast({ message: `特训完成！复习 ${totalLearned} 词`, duration: 2000 });
        setTimeout(() => { router.back() }, 1500);
      }
    }
  }

  build() {
    Column() {
      // 1. 顶部栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24)
          .onClick(() => { this.saveSessionToCache(); router.back(); })
        Blank()
        if (!this.isLoading && this.wordQueue.length > 0) {
          Row() {
            if (this.isCollectionMode) {
              Text(`特训 ${this.sessionFinishedReview}/${this.sessionTotalReview}`).fontSize(14).fontColor('#FF9800')
            } else {
              Text(`新词 ${this.sessionFinishedNew}/${this.sessionTotalNew}`).fontSize(14).fontColor('#FF9800').margin({ right: 15 })
              Text(`复习 ${this.sessionFinishedReview}/${this.sessionTotalReview}`).fontSize(14).fontColor('#FFCA28')
            }
          }
        }
      }.width('100%').padding(16)

      if (this.isLoading) {
        Column() { LoadingProgress().width(50).height(50).color('#FFCA28'); Text('正在准备数据...').fontSize(16).fontColor('#666').margin({ top: 20 }) }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.wordQueue.length > 0) {
        // 2. 核心卡片容器
        Column() {
          Row() {
            if (!this.isCollectionMode) {
              Text(this.initialNewWordIds.includes(this.wordQueue[this.currentIndex].content.word.wordId) ? '新词' : '复习')
                .fontSize(12).fontColor('#FF9800').backgroundColor('#FFF8E1')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(6)
            } else {
              Text('收藏复习').fontSize(12).fontColor('#FFCA28').backgroundColor('#FFF8E1')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(6)
            }
            Blank()
            Text(this.isCurrentWordCollected ? '★' : '☆')
              .fontSize(28).fontColor('#FFCA28')
              .onClick(() => { this.toggleStar() })
          }.width('100%').alignItems(VerticalAlign.Center)

          Text(this.wordQueue[this.currentIndex].headWord).fontSize(40).fontWeight(FontWeight.Bold).fontColor('#333').margin({ top: 10 })
          if (this.wordQueue[this.currentIndex].content.word.content.usphone) {
            Text(`美 [${this.wordQueue[this.currentIndex].content.word.content.usphone!}]`).fontSize(16).fontColor('#999').margin({ top: 10 })
          }

          if (!this.isShowDetails) { Blank() } else {
            Scroll() {
              Column() {
                if (this.wordQueue[this.currentIndex].content.word.content.trans) {
                  Column() {
                    ForEach(this.wordQueue[this.currentIndex].content.word.content.trans || [], (tran: TransItem) => {
                      // 防止释义长文本溢出屏幕
                      Row() {
                        Text(tran.pos + ".").fontSize(16).fontColor('#FF9800').fontWeight(FontWeight.Bold).margin({ right: 8 });
                        Text(tran.tranCn)
                          .fontSize(16)
                          .fontColor('#333')
                          .layoutWeight(1) // 限制宽度自动换行
                      }.width('100%').margin({ bottom: 5 }).alignItems(VerticalAlign.Top) // 顶部对齐，换行后更美观
                    })
                  }.padding(15).backgroundColor('#EAEAEA').borderRadius(10).width('100%').margin({ top: 30 })
                }
                if (this.wordQueue[this.currentIndex].content.word.content.sentence) {
                  Column() {
                    Text('语境例句').fontSize(14).fontColor('#999').width('100%').margin({ bottom: 10 })
                    ForEach(this.wordQueue[this.currentIndex].content.word.content.sentence?.sentences || [], (sen: SentenceItem) => {
                      Column() {
                        Text(sen.sContent).fontSize(16).fontColor('#333').fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 5 });
                        Text(sen.sCn).fontSize(14).fontColor('#999').width('100%')
                      }.margin({ bottom: 15 })
                    })
                  }.padding(15).width('100%').margin({ top: 20 })
                }
              }.width('100%').alignItems(HorizontalAlign.Start)
            }.layoutWeight(1).margin({ top: 20 })
          }
        }
        .width('90%').layoutWeight(1).backgroundColor('#F7F7F7').borderRadius(20).padding(20)
        .shadow({ radius: 15, color: '#1A000000', offsetX: 0, offsetY: 8 }).margin({ top: 10, bottom: 20 })

        // 3. 底部按钮组
        Row() {
          if (!this.isShowDetails) {
            Button('不认识').width('45%').height(50).backgroundColor('#FFF8E1').fontColor('#FF9800').fontSize(18).onClick(() => { this.handleAnswer(false) })
            Button('认识').width('45%').height(50).backgroundColor('#FFCA28').fontColor('#333').fontSize(18).onClick(() => { this.handleAnswer(true) })
          } else {
            if (this.lastAnswerIsKnown) {
              Button('记错了').width('40%').height(50).backgroundColor('#F7F7F7').fontColor('#FF9800').border({width:1, color:'#FFCA28'}).fontSize(18).onClick(() => { this.markAsWrong() })
              Button(this.currentIndex === this.wordQueue.length - 1 ? '完成任务' : '下一个').width('55%').height(50).backgroundColor('#FFCA28').fontColor('#333').fontSize(18).onClick(() => { this.nextWord() })
            } else {
              Button(this.currentIndex === this.wordQueue.length - 1 ? '完成任务' : '下一个').width('100%').height(50).backgroundColor('#FFCA28').fontColor('#333').fontSize(18).onClick(() => { this.nextWord() })
            }
          }
        }.width('90%').justifyContent(FlexAlign.SpaceBetween).margin({ bottom: 30 })
      }
    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
    })
  }
}