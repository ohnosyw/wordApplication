// entry/src/main/ets/pages/CompletedBooksPage.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import preferences from '@ohos.data.preferences'
import { UserInfo, CompletedBookInfo, UserManager } from '../utils/UserManager'
import { ProgressManager } from '../utils/ProgressManager'
import { PlanData } from '../model/StudyPlan'
import { WordService } from '../utils/WordService'

@Entry
@Component
struct CompletedBooksPage {
  // 拿到当前用户的完本记录
  @StorageLink('currentUser') user: UserInfo | null = null;
  // 记录每本完结词书当前的“实际已背数量”
  @State learnedCounts: Record<string, number> = {};

  private getBookColor(bookId: string): string {
    const colorMap: Record<string, string> = {
      'cet4': '#7EAC8A', 'cet6': '#D1A075', 'kaoyan': '#CB8585',
      'junior_high': '#A2B889', 'high_school': '#829DBF', 'ielts': '#A68CB2',
      'sat': '#7B88B5', 'gmat': '#7AAEB5'
    };
    return colorMap[bookId] || '#9CA3AF';
  }

  async onPageShow() {
    await this.loadProgress();
  }

  // 遍历底层记忆库，计算各词书的实际进度
  async loadProgress() {
    let map = await ProgressManager.getProgressMap(getContext(this));
    let counts: Record<string, number> = {};
    if (this.user && this.user.completedBooks) {
      for (let book of this.user.completedBooks) {
        let count = 0;
        // 利用命名空间前缀进行精确过滤
        let prefix = `${book.bookId}_`;
        for (let key of Object.keys(map)) {
          if (key.startsWith(prefix)) count++;
        }
        counts[book.bookId] = count;
      }
    }
    this.learnedCounts = counts;
  }

  // 重置二刷
  async resetProgress(book: CompletedBookInfo) {
    // 二次确认弹窗
    promptAction.showDialog({
      title: '重置词书进度',
      message: `确定要重置《${book.bookName}》的背诵进度吗？`,
      buttons: [{ text: '取消', color: '#999' }, { text: '确认重置', color: '#FF9800' }]
    }).then(async (res) => {
      if (res.index === 1) {// 用户点击了确认
        // 清除底层艾宾浩斯记忆库中的该书数据
        await ProgressManager.clearBookProgress(getContext(this), book.bookId);

        let currentPlan = AppStorage.get<PlanData>('studyPlan');
        if (currentPlan && currentPlan.bookId === book.bookId) {
          // 归零首页的总进度条
          AppStorage.setOrCreate('totalLearnedInBook', 0);
          // 粉碎进行中的会话和今日队列缓存
          await UserManager.clearActiveSession(getContext(this));
          await UserManager.clearDailyQueue(getContext(this), book.bookId, new Date().toDateString());

          if (this.user) {
            // 将用户今天的“已学数据”全部归零
            this.user.todayStudiedCount = 0;
            this.user.todayStudiedNew = 0;
            this.user.todayStudiedReview = 0;
            // 重新计算今日目标
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
        promptAction.showToast({ message: '词书进度已重置！' });
      }
    })
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => { router.back() })
        Text('已完成词书').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
      }.width('100%').padding(20)

      // 空状态：没有完本记录时展示插画
      if (!this.user || !this.user.completedBooks || this.user.completedBooks.length === 0) {
        Column() {
          Image($r('app.media.ic_duck_sleep')).width(100).height(100).opacity(0.5)
          Text('暂无完本记录').fontSize(16).fontColor('#999').margin({ top: 20 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        // 列表渲染
        List({ space: 15 }) {
          ForEach(this.user.completedBooks, (book: CompletedBookInfo) => {
            ListItem() {
              Row() {
                Column() {
                  Text(book.bookName.substring(0, 2))
                    .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.White)
                }
                .width(50).height(50).borderRadius(10).margin({ right: 16 })
                .backgroundColor(this.getBookColor(book.bookId))
                .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)

                Column() {
                  Text(book.bookName).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#333')
                  Text(`进度: ${this.learnedCounts[book.bookId] || 0} / ${book.totalWords} 词`).fontSize(13).fontColor('#999').margin({ top: 5 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                // 如果实际进度已满，说明需要二刷，展示橙色按钮；如果进度不满（说明刚点过重置），展示灰色不可点击状态
                if ((this.learnedCounts[book.bookId] || 0) >= book.totalWords) {
                  Text('重置二刷')
                    .fontSize(12).fontColor('#FF9800')
                    .backgroundColor('#FFF8E1').padding({left:10, right:10, top:6, bottom:6})
                    .borderRadius(20).fontWeight(FontWeight.Bold)
                    .onClick(() => { this.resetProgress(book) })
                } else {
                  Text('已重置')
                    .fontSize(12).fontColor('#CCC')
                    .backgroundColor('#F0F0F0').padding({left:10, right:10, top:6, bottom:6})
                    .borderRadius(20)
                }
              }
              .width('100%').padding(18).backgroundColor('#F7F7F7').borderRadius(15)
              .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })
            }
          })
        }.width('90%').layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
    })
  }
}