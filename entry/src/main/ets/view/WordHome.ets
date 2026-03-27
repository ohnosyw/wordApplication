// entry/src/main/ets/view/WordHome.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import preferences from '@ohos.data.preferences'
import { PlanData } from '../model/StudyPlan'
import { UserInfo, UserManager } from '../utils/UserManager'
import { WordService } from '../utils/WordService'
import { ProgressManager } from '../utils/ProgressManager'

@Component
export struct WordHome {
  @StorageLink('currentUser') user: UserInfo | null = null;
  @StorageLink('studyPlan') @Watch('refreshDailyState') plan: PlanData | null = null;

  @StorageLink('totalLearnedInBook') totalLearnedInBook: number = 0;

  // 计划变动侦测器
  private lastSeenPlanStr: string = '';

  async aboutToAppear() {
    if (!this.user) {
      await UserManager.autoLogin(getContext(this));
    }
    if (this.plan) {
      this.lastSeenPlanStr = JSON.stringify(this.plan);
    }
    this.refreshDailyState();
  }

  async refreshDailyState() {
    if (!this.user || !this.plan) return;

    let currentPlanStr = JSON.stringify(this.plan);
    let isPlanAdjusted = false;
    if (this.lastSeenPlanStr !== '' && this.lastSeenPlanStr !== currentPlanStr) {
      isPlanAdjusted = true;
    }
    this.lastSeenPlanStr = currentPlanStr;

    let taskInfo = await WordService.getTodayTaskInfo(getContext(this), this.plan);
    this.totalLearnedInBook = taskInfo.totalLearned;

    if (this.totalLearnedInBook >= this.plan.totalWords && this.plan.totalWords > 0) {
      await UserManager.recordCompletedBook(getContext(this), this.plan);
    }

    let users = await UserManager.getAllUsers(getContext(this));
    let dbUser = users[this.user.userId];
    if (!dbUser) return;

    let today = new Date().toDateString();
    let isBookSwitched = dbUser.currentStudyBookId !== this.plan.bookId;

    if (dbUser.lastStudyDate !== today || !dbUser.todayTarget || dbUser.todayTarget === 0 || dbUser.todayStudiedCount === undefined || isBookSwitched || isPlanAdjusted) {

      if (isBookSwitched || isPlanAdjusted) {
        await UserManager.clearActiveSession(getContext(this));
        await UserManager.clearDailyQueue(getContext(this), this.plan.bookId, today);
      }

      let targetNew = taskInfo.newCount;
      let targetReview = taskInfo.reviewCount;

      let queueStr = await UserManager.getDailyQueue(getContext(this), this.plan.bookId, today);
      if (queueStr) {
        let dailyData = JSON.parse(queueStr) as Record<string, Object>;
        targetNew = dailyData['sessionTotalNew'] as number;
        targetReview = dailyData['sessionTotalReview'] as number;
      }

      let tempUser: UserInfo = {
        userId: dbUser.userId,
        username: dbUser.username,
        password: dbUser.password,
        checkInDays: dbUser.checkInDays,
        totalWords: dbUser.totalWords,
        continuousCheckInDays: dbUser.continuousCheckInDays,
        lastCheckInDate: dbUser.lastCheckInDate,
        completedBooks: dbUser.completedBooks,

        lastStudyDate: today,
        currentStudyBookId: this.plan.bookId,

        todayStudiedCount: (dbUser.lastStudyDate === today && !isBookSwitched) ? (dbUser.todayStudiedCount || 0) : 0,
        todayStudiedNew: (dbUser.lastStudyDate === today && !isBookSwitched) ? (dbUser.todayStudiedNew || 0) : 0,
        todayStudiedReview: (dbUser.lastStudyDate === today && !isBookSwitched) ? (dbUser.todayStudiedReview || 0) : 0,

        todayTargetNew: targetNew,
        todayTargetReview: targetReview,
        todayTarget: targetNew + targetReview
      };

      users[tempUser.userId] = tempUser;
      let pref = await preferences.getPreferences(getContext(this), 'UserDatabase');
      await pref.put('AllUsers', JSON.stringify(users));
      await pref.flush();

      UserManager.syncUserToAppStorage(tempUser);
    } else {
      UserManager.syncUserToAppStorage(dbUser);
    }
  }

  build() {
    Column() {
      // 头部栏：图标 + 标题
      Row() {
        Image($r('app.media.ic_duck'))
          .width(32)
          .height(32)
          .margin({ left: 20, right: 10 })
        Text('背词鸭')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333')
      }.width('100%').height(60)

      if (!this.user) {
        Column() {
          Image($r('app.media.user_avatar')).width(80).height(80).margin({ bottom: 20, top: 100 }).backgroundColor('#DDD').borderRadius(40)
          Text('登录后开启背单词之旅').fontSize(18).fontColor('#666').margin({ bottom: 40 })
          Button('去登录 / 注册').width('80%').height(50).backgroundColor('#FFCA28').fontColor('#333').onClick(() => router.pushUrl({ url: 'pages/LoginPage' }))
        }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center)
      } else if (!this.plan) {
        Column() {
          Text(`你好，${this.user.username}！`).fontSize(24).fontWeight(FontWeight.Bold).margin({ top: 80, bottom: 20 })
          Text('你还没有制定学习计划，无法开始学习。').fontSize(16).fontColor('#666').margin({ bottom: 50 })
          Button('选择我的第一本词书').width('80%').height(50).backgroundColor('#FFCA28').fontColor('#333').onClick(() => router.pushUrl({ url: 'pages/BookSelectPage' }))
        }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            // 🌟 栏目 1：更换词书与任务总览
            Column() {
              Row() { Text(this.plan.bookName).fontSize(22).fontWeight(FontWeight.Bold); Blank(); Text('更换词书 >').fontSize(14).fontColor('#FF9800').onClick(() => { router.pushUrl({ url: 'pages/BookSelectPage' }) }) }.width('100%')
              Row() {
                Column() { Text('今日新词').fontSize(14).fontColor('#666'); Text((this.user.todayTargetNew !== undefined ? this.user.todayTargetNew : 0).toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FF9800') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
                Divider().height(30).vertical(true).backgroundColor('#E0E0E0') // 分割线稍微调浅一点
                Column() { Text('今日复习').fontSize(14).fontColor('#666'); Text((this.user.todayTargetReview !== undefined ? this.user.todayTargetReview : 0).toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#FFCA28') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
                Divider().height(30).vertical(true).backgroundColor('#E0E0E0')
                Column() { Text('总词数').fontSize(14).fontColor('#666'); Text(this.plan.totalWords.toString()).fontSize(28).fontWeight(FontWeight.Bold).fontColor('#333') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
              }.width('100%').margin({ top: 20 })
            }
            .width('90%')
            .padding(20)
            .backgroundColor('#F7F7F7') // 🌟 替换为淡灰色
            .borderRadius(15)
            .margin({ top: 20 })
            .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 }) // 加一点点阴影增加质感

            // 🌟 栏目 2：词书总进度
            Column() {
              Row() {
                Text('词书总进度').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
                Blank()
                Text(`${this.totalLearnedInBook} / ${this.plan.totalWords} 词`).fontSize(14).fontColor('#666')
              }.width('100%').margin({ bottom: 10 })

              Progress({ value: this.totalLearnedInBook, total: this.plan.totalWords || 1, type: ProgressType.Linear })
                .width('100%').color('#FFCA28').backgroundColor('#FFF8E1').style({ strokeWidth: 12 }).animation({ duration: 500, curve: Curve.EaseInOut })
            }
            .width('90%')
            .padding(20)
            .backgroundColor('#F7F7F7') // 🌟 替换为淡灰色
            .borderRadius(15)
            .margin({ top: 20 })
            .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

            // 🌟 栏目 3：学习计划
            Column() {
              Row() { Text('学习计划').fontSize(18).fontWeight(FontWeight.Bold); Blank(); Text('调整计划 >').fontSize(14).fontColor('#FF9800').onClick(() => { router.pushUrl({ url: 'pages/StudyPlanPage' }) }) }.width('100%')
              Divider().margin({ top: 10, bottom: 10 }).color('#E0E0E0')
              Row() { Text('每日新词').fontSize(16); Blank(); Text(this.plan.dailyNew + ' 词').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#FF9800') }.width('100%').margin({ bottom: 10 })
              Row() { Text('每日复习').fontSize(16); Blank(); Text(this.plan.dailyReview + ' 词').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#FFCA28') }.width('100%').margin({ bottom: 10 })
              Row() { Text('学习模式').fontSize(16); Blank(); Text(this.plan.studyMode === 0 ? '先学新词再复习' : '新词复习混合').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#666') }.width('100%').margin({ bottom: 10 })
            }
            .width('90%')
            .padding(20)
            .backgroundColor('#F7F7F7') // 🌟 替换为淡灰色
            .borderRadius(15)
            .margin({ top: 20 })
            .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

            // 🌟 栏目 4：今日进度
            Column() {
              Row() {
                Text('今日进度').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
                Blank()
                Text(`${this.user.todayStudiedCount !== undefined ? this.user.todayStudiedCount : 0} / ${this.user.todayTarget !== undefined ? this.user.todayTarget : 0} 词`).fontSize(14).fontColor('#666')
              }.width('100%').margin({ bottom: 10 })

              Progress({ value: this.user.todayStudiedCount !== undefined ? this.user.todayStudiedCount : 0, total: this.user.todayTarget || 1, type: ProgressType.Linear })
                .width('100%').color('#FFCA28').backgroundColor('#FFF8E1').style({ strokeWidth: 12 }).animation({ duration: 500, curve: Curve.EaseInOut })
            }
            .width('90%')
            .padding(20)
            .backgroundColor('#F7F7F7') // 🌟 替换为淡灰色
            .borderRadius(15)
            .margin({ top: 20 })
            .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

            Button(this.user.todayStudiedCount !== undefined && this.user.todayTarget !== undefined && this.user.todayStudiedCount > 0 && this.user.todayStudiedCount < this.user.todayTarget ? '继续学习' : '开始背单词')
              .width('90%').height(50).backgroundColor('#FFCA28').fontColor('#333').margin({ top: 30, bottom: 30 })
              .onClick(() => {

                if (this.totalLearnedInBook >= this.plan!.totalWords && this.plan!.totalWords > 0) {
                  promptAction.showDialog({
                    title: '🎉 恭喜完本！',
                    message: `您已成功背完《${this.plan!.bookName}》所有单词！\n接下来您想重置进度开启二刷，还是更换一本新词书？\n（若选择更换，重置权限将在"已完成词书"中为您保留）`,
                    buttons: [
                      { text: '更换新词书', color: '#2196F3' },
                      { text: '重置并二刷', color: '#F44336' }
                    ]
                  }).then(async (data) => {
                    if (data.index === 0) {
                      router.pushUrl({ url: 'pages/BookSelectPage' });
                    } else if (data.index === 1) {
                      await ProgressManager.clearBookProgress(getContext(this), this.plan!.bookId);
                      AppStorage.setOrCreate('totalLearnedInBook', 0);
                      await UserManager.clearActiveSession(getContext(this));
                      await UserManager.clearDailyQueue(getContext(this), this.plan!.bookId, new Date().toDateString());

                      let allUsers = await UserManager.getAllUsers(getContext(this));
                      let realUser = allUsers[this.user!.userId];
                      if (realUser) {
                        realUser.todayStudiedCount = 0;
                        realUser.todayStudiedNew = 0;
                        realUser.todayStudiedReview = 0;

                        let taskInfo = await WordService.getTodayTaskInfo(getContext(this), this.plan!);
                        realUser.todayTargetNew = taskInfo.newCount;
                        realUser.todayTargetReview = taskInfo.reviewCount;
                        realUser.todayTarget = taskInfo.newCount + taskInfo.reviewCount;

                        allUsers[realUser.userId] = realUser;
                        let pref = await preferences.getPreferences(getContext(this), 'UserDatabase');
                        await pref.put('AllUsers', JSON.stringify(allUsers));
                        await pref.flush();

                        UserManager.syncUserToAppStorage(realUser);
                      }
                      this.refreshDailyState();
                      promptAction.showToast({ message: '进度已重置，开启二刷之旅！' });
                    }
                  });
                  return;
                }

                let studied = this.user!.todayStudiedCount !== undefined ? this.user!.todayStudiedCount : 0;
                let target = this.user!.todayTarget !== undefined ? this.user!.todayTarget : 0;

                if (studied >= target && target > 0) {
                  promptAction.showDialog({
                    title: '🎉 今日任务已完成',
                    message: '您已完成今天的专属背词任务！是否要开启额外加练？',
                    buttons: [
                      { text: '休息一下', color: '#999' },
                      { text: '继续加练', color: '#FFCA28' }
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
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [
        ['#FFFDE7', 0.0],
        ['#FFF9C4', 0.3],
        ['#F5F5F5', 1.0]
      ]
    })
  }
}