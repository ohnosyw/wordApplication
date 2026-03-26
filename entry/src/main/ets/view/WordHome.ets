// entry/src/main/ets/view/WordHome.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import preferences from '@ohos.data.preferences'
import { PlanData } from '../model/StudyPlan'
import { UserInfo, UserManager } from '../utils/UserManager'
import { WordService } from '../utils/WordService'

@Component
export struct WordHome {
  @StorageLink('currentUser') user: UserInfo | null = null;
  @StorageLink('studyPlan') @Watch('refreshDailyState') plan: PlanData | null = null;

  @StorageLink('totalLearnedInBook') totalLearnedInBook: number = 0;

  aboutToAppear() {
    this.refreshDailyState();
  }

  async refreshDailyState() {
    if (!this.user || !this.plan) return;

    let taskInfo = await WordService.getTodayTaskInfo(getContext(this), this.plan);
    this.totalLearnedInBook = taskInfo.totalLearned;

    if (this.totalLearnedInBook >= this.plan.totalWords && this.plan.totalWords > 0) {
      await UserManager.recordCompletedBook(getContext(this), this.plan.bookName);
    }

    let today = new Date().toDateString();

    // 🌟 核心判断：不仅判断跨天，还判断“是否切换了词书”
    let isBookSwitched = this.user.currentStudyBookId !== this.plan.bookId;

    if (this.user.lastStudyDate !== today || !this.user.todayTarget || this.user.todayTarget === 0 || this.user.todayStudiedCount === undefined || isBookSwitched) {

      let tempUser: UserInfo = {
        userId: this.user.userId,
        username: this.user.username,
        password: this.user.password,
        checkInDays: this.user.checkInDays,
        totalWords: this.user.totalWords,
        continuousCheckInDays: this.user.continuousCheckInDays,
        lastCheckInDate: this.user.lastCheckInDate,
        completedBooks: this.user.completedBooks,

        lastStudyDate: today,
        currentStudyBookId: this.plan.bookId, // 🌟 重新绑定为新词书

        // 🌟 核心修复：如果是同一天内换书，进度强制归 0（针对这本新书重新开始打卡）
        todayStudiedCount: (this.user.lastStudyDate === today && !isBookSwitched) ? (this.user.todayStudiedCount || 0) : 0,
        todayStudiedNew: (this.user.lastStudyDate === today && !isBookSwitched) ? (this.user.todayStudiedNew || 0) : 0,
        todayStudiedReview: (this.user.lastStudyDate === today && !isBookSwitched) ? (this.user.todayStudiedReview || 0) : 0,

        todayTargetNew: taskInfo.newCount,
        todayTargetReview: taskInfo.reviewCount,
        todayTarget: taskInfo.newCount + taskInfo.reviewCount
      };

      if (tempUser.todayTarget === 0) {
        tempUser.todayTargetNew = this.plan.dailyNew;
        tempUser.todayTargetReview = this.plan.dailyReview;
        tempUser.todayTarget = this.plan.dailyNew + this.plan.dailyReview;
      }

      let users = await UserManager.getAllUsers(getContext(this));
      users[tempUser.userId] = tempUser;
      let pref = await preferences.getPreferences(getContext(this), 'UserDatabase');
      await pref.put('AllUsers', JSON.stringify(users));
      await pref.flush();
      AppStorage.setOrCreate('currentUser', tempUser);
    }
  }

  build() {
    Column() {
      Row() { Text('背单词').fontSize(24).fontWeight(FontWeight.Bold).margin({ left: 20 }) }.width('100%').height(60).backgroundColor(Color.White)

      if (!this.user) {
        Column() {
          Image($r('app.media.user_avatar')).width(80).height(80).margin({ bottom: 20, top: 100 }).backgroundColor('#DDD').borderRadius(40)
          Text('登录后开启背单词之旅').fontSize(18).fontColor('#666').margin({ bottom: 40 })
          Button('去登录 / 注册').width('80%').height(50).backgroundColor('#4CAF50').onClick(() => router.pushUrl({ url: 'pages/LoginPage' }))
        }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center)
      } else if (!this.plan) {
        Column() {
          Text(`你好，${this.user.username}！`).fontSize(24).fontWeight(FontWeight.Bold).margin({ top: 80, bottom: 20 })
          Text('你还没有制定学习计划，无法开始学习。').fontSize(16).fontColor('#666').margin({ bottom: 50 })
          Button('选择我的第一本词书').width('80%').height(50).backgroundColor('#FF9800').onClick(() => router.pushUrl({ url: 'pages/BookSelectPage' }))
        }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            Column() {
              Row() { Text(this.plan.bookName).fontSize(22).fontWeight(FontWeight.Bold); Blank(); Text('更换词书 >').fontSize(14).fontColor('#4CAF50').onClick(() => { router.pushUrl({ url: 'pages/BookSelectPage' }) }) }.width('100%')
              Row() {
                Column() { Text('今日新词').fontSize(14).fontColor('#666'); Text((this.user.todayTargetNew !== undefined ? this.user.todayTargetNew : 0).toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#4CAF50') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
                Divider().height(30).vertical(true).backgroundColor('#DDD')
                Column() { Text('今日复习').fontSize(14).fontColor('#666'); Text((this.user.todayTargetReview !== undefined ? this.user.todayTargetReview : 0).toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF9800') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
                Divider().height(30).vertical(true).backgroundColor('#DDD')
                Column() { Text('总词数').fontSize(14).fontColor('#666'); Text(this.plan.totalWords.toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#2196F3') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
              }.width('100%').margin({ top: 20 })
            }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(15).margin({ top: 20 })

            Column() {
              Row() {
                Text('词书总进度').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
                Blank()
                Text(`${this.totalLearnedInBook} / ${this.plan.totalWords} 词`).fontSize(14).fontColor('#666')
              }.width('100%').margin({ bottom: 10 })

              Progress({ value: this.totalLearnedInBook, total: this.plan.totalWords || 1, type: ProgressType.Linear })
                .width('100%').color('#2196F3').backgroundColor('#E3F2FD').style({ strokeWidth: 12 }).animation({ duration: 500, curve: Curve.EaseInOut })
            }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(15).margin({ top: 20 })

            Column() {
              Row() { Text('学习计划').fontSize(18).fontWeight(FontWeight.Bold); Blank(); Text('调整计划 >').fontSize(14).fontColor('#4CAF50').onClick(() => { router.pushUrl({ url: 'pages/StudyPlanPage' }) }) }.width('100%')
              Divider().margin({ top: 10, bottom: 10 })
              Row() { Text('每日新词').fontSize(16); Blank(); Text(this.plan.dailyNew + ' 词').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#4CAF50') }.width('100%').margin({ bottom: 10 })
              Row() { Text('每日复习').fontSize(16); Blank(); Text(this.plan.dailyReview + ' 词').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#FF9800') }.width('100%').margin({ bottom: 10 })
              Row() { Text('学习模式').fontSize(16); Blank(); Text(this.plan.studyMode === 0 ? '先学新词再复习' : '新词复习混合').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#666') }.width('100%').margin({ bottom: 10 })
            }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(15).margin({ top: 20 })

            Column() {
              Row() {
                Text('今日进度').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
                Blank()
                Text(`${this.user.todayStudiedCount !== undefined ? this.user.todayStudiedCount : 0} / ${this.user.todayTarget !== undefined ? this.user.todayTarget : 0} 词`).fontSize(14).fontColor('#666')
              }.width('100%').margin({ bottom: 10 })

              Progress({ value: this.user.todayStudiedCount !== undefined ? this.user.todayStudiedCount : 0, total: this.user.todayTarget || 1, type: ProgressType.Linear })
                .width('100%').color('#4CAF50').backgroundColor('#E8F5E9').style({ strokeWidth: 12 }).animation({ duration: 500, curve: Curve.EaseInOut })
            }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(15).margin({ top: 20 })

            Button(this.user.todayStudiedCount !== undefined && this.user.todayTarget !== undefined && this.user.todayStudiedCount > 0 && this.user.todayStudiedCount < this.user.todayTarget ? '继续学习' : '开始背单词')
              .width('90%').height(50).backgroundColor('#4CAF50').margin({ top: 30, bottom: 30 })
              .onClick(() => {
                let studied = this.user!.todayStudiedCount !== undefined ? this.user!.todayStudiedCount : 0;
                let target = this.user!.todayTarget !== undefined ? this.user!.todayTarget : 0;

                if (studied >= target && target > 0) {
                  promptAction.showDialog({
                    title: '🎉 今日任务已完成',
                    message: '您已完成今天的专属背词任务！是否要开启额外加练？',
                    buttons: [
                      { text: '休息一下', color: '#999' },
                      { text: '继续加练', color: '#4CAF50' }
                    ]
                  }).then(async (data) => {
                    if (data.index === 1) {
                      let taskInfo = await WordService.getTodayTaskInfo(getContext(this), this.plan!);
                      await UserManager.addExtraTarget(getContext(this), this.plan!, taskInfo.availableNew, taskInfo.availableReview);
                      router.pushUrl({ url: 'pages/LearningSessionPage' })
                    }
                  })
                } else {
                  router.pushUrl({ url: 'pages/LearningSessionPage' })
                }
              })
          }.width('100%')
        }.layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}