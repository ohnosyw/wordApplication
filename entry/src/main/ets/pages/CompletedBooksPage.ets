// entry/src/main/ets/pages/CompletedBooksPage.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import preferences from '@ohos.data.preferences'
import { UserInfo, CompletedBookInfo, UserManager } from '../utils/UserManager'
import { ProgressManager } from '../utils/ProgressManager'
import { PlanData } from '../model/StudyPlan'
import { WordService } from '../utils/WordService' // 🌟 新增引入底层雷达

@Entry
@Component
struct CompletedBooksPage {
  @StorageLink('currentUser') user: UserInfo | null = null;
  @State learnedCounts: Record<string, number> = {};

  async onPageShow() {
    await this.loadProgress();
  }

  async loadProgress() {
    let map = await ProgressManager.getProgressMap(getContext(this));
    let counts: Record<string, number> = {};

    if (this.user && this.user.completedBooks) {
      for (let book of this.user.completedBooks) {
        let count = 0;
        let prefix = `${book.bookId}_`;
        for (let key of Object.keys(map)) {
          if (key.startsWith(prefix)) {
            count++;
          }
        }
        counts[book.bookId] = count;
      }
    }
    this.learnedCounts = counts;
  }

  async resetProgress(book: CompletedBookInfo) {
    promptAction.showDialog({
      title: '重置词书进度',
      message: `确定要重置《${book.bookName}》的背诵进度吗？\n重置后您将重新开始背诵本书，但此荣誉记录将被保留。`,
      buttons: [
        { text: '取消', color: '#999' },
        { text: '确认重置', color: '#F44336' }
      ]
    }).then(async (res) => {
      if (res.index === 1) {
        await ProgressManager.clearBookProgress(getContext(this), book.bookId);

        let currentPlan = AppStorage.get<PlanData>('studyPlan');
        if (currentPlan && currentPlan.bookId === book.bookId) {
          AppStorage.setOrCreate('totalLearnedInBook', 0);
          await UserManager.clearActiveSession(getContext(this));
          await UserManager.clearDailyQueue(getContext(this), book.bookId, new Date().toDateString());

          if (this.user) {
            this.user.todayStudiedCount = 0;
            this.user.todayStudiedNew = 0;
            this.user.todayStudiedReview = 0;

            // 🌟 核心修复：唤醒雷达，精确计算这本刚被清空的词书还能挤出多少词
            let taskInfo = await WordService.getTodayTaskInfo(getContext(this), currentPlan);
            this.user.todayTargetNew = taskInfo.newCount;
            this.user.todayTargetReview = taskInfo.reviewCount;
            this.user.todayTarget = taskInfo.newCount + taskInfo.reviewCount;

            let users = await UserManager.getAllUsers(getContext(this));
            users[this.user.userId] = this.user;
            let pref = await preferences.getPreferences(getContext(this), 'UserDatabase');
            await pref.put('AllUsers', JSON.stringify(users));
            await pref.flush();

            AppStorage.setOrCreate('currentUser', this.user);
          }
        }

        await this.loadProgress();
        promptAction.showToast({ message: '词书进度已成功重置！' });
      }
    })
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => { router.back() })
        Text('已完成词书').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
      }.width('100%').padding(20).backgroundColor(Color.White)

      if (!this.user || !this.user.completedBooks || this.user.completedBooks.length === 0) {
        Column() {
          Text('暂无完本记录').fontSize(16).fontColor('#999').margin({ top: 100 })
          Text('完成整本词书背诵后即可点亮荣誉').fontSize(14).fontColor('#CCC').margin({ top: 10 })
        }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 15 }) {
          ForEach(this.user.completedBooks, (book: CompletedBookInfo) => {
            ListItem() {
              Row() {
                Text('🏆').fontSize(28).margin({ right: 15 })
                Column() {
                  Text(book.bookName).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
                  Text(`进度: ${this.learnedCounts[book.bookId] || 0} / ${book.totalWords} 词`).fontSize(14).fontColor('#999').margin({ top: 5 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                if ((this.learnedCounts[book.bookId] || 0) >= book.totalWords) {
                  Button('重置二刷')
                    .backgroundColor('#FFEBEE').fontColor('#F44336').fontSize(14).height(32)
                    .onClick(() => { this.resetProgress(book) })
                } else {
                  Button('已重置')
                    .backgroundColor('#F5F5F5').fontColor('#CCC').fontSize(14).height(32)
                }
              }
              .width('100%').padding(20).backgroundColor(Color.White).borderRadius(15)
              .shadow({ radius: 10, color: '#0A000000', offsetX: 0, offsetY: 5 })
            }
          })
        }.width('90%').layoutWeight(1).margin({ top: 20 })
      }
    }.width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}