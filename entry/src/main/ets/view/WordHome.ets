// entry/src/main/ets/view/WordHome.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import preferences from '@ohos.data.preferences'
import { PlanData } from '../model/StudyPlan'
import { UserInfo, UserManager } from '../utils/UserManager'
import { WordService } from '../utils/WordService'
import { ProgressManager } from '../utils/ProgressManager'

// 自定义完成词书弹窗
@CustomDialog
struct CompletionDialog {
  controller: CustomDialogController
  bookName: string = ''
  onConfirm: (index: number) => void = () => {}

  build() {
    Column() {
      // 🌟 1. 顶部的鸭子图标
      Image($r('app.media.ic_duck'))
        .width(80)
        .height(80)
        .margin({ top: -40, bottom: 10 }) // 向上偏移，制造破框而出的视觉感

      Text('恭喜完成该词书！')
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

      // 🌟 2. 选项按钮
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
    // 🌟 3. 与主页一致的渐变背景
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 1.0]]
    })
    .shadow({ radius: 20, color: '#33000000' })
  }
}

// 🌟 新增：自定义加练弹窗
@CustomDialog
struct ExtraStudyDialog {
  controller: CustomDialogController
  onConfirm: () => void = () => {}

  build() {
    Column() {
      // 同样的鸭子图标偏移设计
      Image($r('app.media.ic_duck'))
        .width(80)
        .height(80)
        .margin({ top: -40, bottom: 10 })

      Text('今日任务已完成')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#333')
        .margin({ bottom: 15 })

      Text('您已完成今天的专属背词任务！\n是否要开启额外加练？')
        .fontSize(14)
        .fontColor('#666')
        .textAlign(TextAlign.Center)
        .lineHeight(20)
        .padding({ left: 20, right: 20 })
        .margin({ bottom: 25 })

      Button('继续加练')
        .width('90%')
        .height(45)
        .backgroundColor('#FFCA28')
        .fontColor('#333')
        .margin({ bottom: 12 })
        .onClick(() => {
          this.onConfirm()
          this.controller.close()
        })

      Button('休息一下')
        .width('90%')
        .height(45)
        .backgroundColor('#F7F7F7')
        .fontColor('#999')
        .border({ width: 1, color: '#DDD' })
        .margin({ bottom: 20 })
        .onClick(() => {
          this.controller.close()
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

@Component
export struct WordHome {
  @StorageLink('currentUser') user: UserInfo | null = null;
  @StorageLink('studyPlan') @Watch('refreshDailyState') plan: PlanData | null = null;

  @StorageLink('totalLearnedInBook') totalLearnedInBook: number = 0;

  // 处理完本后的选择逻辑
  async handleCompletionSelection(index: number) {
    if (index === 0) {
      router.pushUrl({ url: 'pages/BookSelectPage' });
    } else if (index === 1) {
      // 这里的逻辑就是你原本 index === 1 里的逻辑
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
  }

  // 定义弹窗控制器
  private completionDialogController: CustomDialogController | null = new CustomDialogController({
    builder: CompletionDialog({
      bookName: this.plan ? this.plan.bookName : '',
      onConfirm: (index: number) => { this.handleCompletionSelection(index) }
    }),
    autoCancel: false,
    customStyle: true // 使用自定义样式，去掉白边
  })

  // 🌟 修改：在原有控制器下方增加加练控制器
  private extraStudyDialogController: CustomDialogController | null = new CustomDialogController({
    builder: ExtraStudyDialog({
      onConfirm: () => { this.handleExtraStudy() }
    }),
    autoCancel: true,
    customStyle: true
  })

  // 🌟 新增：处理加练的逻辑函数
  async handleExtraStudy() {
    if (this.plan) {
      let taskInfo = await WordService.getTodayTaskInfo(getContext(this), this.plan);
      await UserManager.addExtraTarget(getContext(this), this.plan, taskInfo.availableNew, taskInfo.availableReview);
      router.pushUrl({ url: 'pages/LearningSessionPage' })
    }
  }

  private lastSeenPlanStr: string = '';

  async aboutToAppear() {
    if (!this.user) {
      UserManager.autoLogin(getContext(this));
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
      // 头部栏：恢复大气尺寸
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
        // 🌟 核心修改：利用 SpaceEvenly 让组件饱满地撑开整个屏幕，去掉了不必要的固定外边距
        Column() {

          // 栏目 1：更换词书与任务总览 (恢复大号字体和间距)
          Column() {
            Row() { Text(this.plan.bookName).fontSize(20).fontWeight(FontWeight.Bold); Blank(); Text('更换词书 >').fontSize(14).fontColor('#FF9800').onClick(() => { router.pushUrl({ url: 'pages/BookSelectPage' }) }) }.width('100%')
            Row() {
              Column() { Text('今日新词').fontSize(14).fontColor('#666'); Text((this.user.todayTargetNew !== undefined ? this.user.todayTargetNew : 0).toString()).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#FF9800') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
              Divider().height(26).vertical(true).backgroundColor('#E0E0E0')
              Column() { Text('今日复习').fontSize(14).fontColor('#666'); Text((this.user.todayTargetReview !== undefined ? this.user.todayTargetReview : 0).toString()).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#FFCA28') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
              Divider().height(26).vertical(true).backgroundColor('#E0E0E0')
              Column() { Text('总词数').fontSize(14).fontColor('#666'); Text(this.plan.totalWords.toString()).fontSize(26).fontWeight(FontWeight.Bold).fontColor('#333') }.layoutWeight(1).alignItems(HorizontalAlign.Center)
            }.width('100%').margin({ top: 16 })
          }
          .width('90%').padding(20).backgroundColor('#F7F7F7').borderRadius(15)
          .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

          // 🌟 栏目 2：词书总进度 (换成 ic_duck2)
          Column() {
            Row() {
              Text('词书总进度').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
              Blank()
              Text(`${this.totalLearnedInBook} / ${this.plan.totalWords} 词`).fontSize(14).fontColor('#666')
            }.width('100%').margin({ bottom: 12 })

            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(12).backgroundColor('#FFF8E1').borderRadius(6)
              Row().width(`${this.plan.totalWords > 0 ? (this.totalLearnedInBook / this.plan.totalWords) * 100 : 0}%`).height(12).backgroundColor('#FFCA28').borderRadius(6).animation({ duration: 500, curve: Curve.EaseInOut })

              // 🌟 替换为 ic_duck2，并恢复饱满尺寸
              Image($r('app.media.ic_duck2'))
                .width(28).height(28)
                .margin({ left: `${this.plan.totalWords > 0 ? (this.totalLearnedInBook / this.plan.totalWords) * 100 : 0}%` })
                .offset({ x: -14, y: 0 })
                .animation({ duration: 500, curve: Curve.EaseInOut })
            }.width('100%').height(28).padding({ left: 14, right: 14 })
          }
          .width('90%').padding(20).backgroundColor('#F7F7F7').borderRadius(15)
          .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

          // 栏目 3：学习计划
          Column() {
            Row() { Text('学习计划').fontSize(16).fontWeight(FontWeight.Bold); Blank(); Text('调整计划 >').fontSize(14).fontColor('#FF9800').onClick(() => { router.pushUrl({ url: 'pages/StudyPlanPage' }) }) }.width('100%')
            Divider().margin({ top: 10, bottom: 10 }).color('#E0E0E0')
            Row() { Text('每日新词').fontSize(15).fontColor('#555'); Blank(); Text(this.plan.dailyNew + ' 词').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#FF9800') }.width('100%').margin({ bottom: 8 })
            Row() { Text('每日复习').fontSize(15).fontColor('#555'); Blank(); Text(this.plan.dailyReview + ' 词').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#FFCA28') }.width('100%').margin({ bottom: 8 })
            Row() { Text('学习模式').fontSize(15).fontColor('#555'); Blank(); Text(this.plan.studyMode === 0 ? '先学新词再复习' : '新词复习混合').fontSize(15).fontWeight(FontWeight.Medium).fontColor('#666') }.width('100%')
          }
          .width('90%').padding(20).backgroundColor('#F7F7F7').borderRadius(15)
          .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

          // 🌟 栏目 4：今日进度 (换成 ic_duck2)
          Column() {
            Row() {
              Text('今日进度').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
              Blank()
              Text(`${this.user.todayStudiedCount !== undefined ? this.user.todayStudiedCount : 0} / ${this.user.todayTarget !== undefined ? this.user.todayTarget : 0} 词`).fontSize(14).fontColor('#666')
            }.width('100%').margin({ bottom: 12 })

            Stack({ alignContent: Alignment.Start }) {
              Row().width('100%').height(12).backgroundColor('#FFF8E1').borderRadius(6)
              Row().width(`${(this.user.todayTarget && this.user.todayTarget > 0) ? ((this.user.todayStudiedCount || 0) / this.user.todayTarget) * 100 : 0}%`).height(12).backgroundColor('#FFCA28').borderRadius(6).animation({ duration: 500, curve: Curve.EaseInOut })

              // 🌟 替换为 ic_duck2
              Image($r('app.media.ic_duck2'))
                .width(28).height(28)
                .margin({ left: `${(this.user.todayTarget && this.user.todayTarget > 0) ? ((this.user.todayStudiedCount || 0) / this.user.todayTarget) * 100 : 0}%` })
                .offset({ x: -14, y: 0 })
                .animation({ duration: 500, curve: Curve.EaseInOut })
            }.width('100%').height(28).padding({ left: 14, right: 14 })
          }
          .width('90%').padding(20).backgroundColor('#F7F7F7').borderRadius(15)
          .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

          // 按钮恢复饱满尺寸
          Button(this.user.todayStudiedCount !== undefined && this.user.todayTarget !== undefined && this.user.todayStudiedCount > 0 && this.user.todayStudiedCount < this.user.todayTarget ? '继续学习' : '开始背单词')
            .width('90%').height(50).fontSize(18).backgroundColor('#FFCA28').fontColor('#333')
            .onClick(() => {
              if (this.totalLearnedInBook >= this.plan!.totalWords && this.plan!.totalWords > 0) {
                this.completionDialogController?.open()
                return;
              }

              let studied = this.user!.todayStudiedCount !== undefined ? this.user!.todayStudiedCount : 0;
              let target = this.user!.todayTarget !== undefined ? this.user!.todayTarget : 0;

              if (studied >= target && target > 0) {
                // 🌟 修改这里：不再使用 promptAction，改为打开自定义弹窗
                this.extraStudyDialogController?.open()
              } else {
                router.pushUrl({ url: 'pages/LearningSessionPage' })
              }
            })
        }
        .width('100%')
        .layoutWeight(1) // 占满下方全部屏幕高度
        // 🌟 核心：均匀分配剩余的所有垂直空间，自动撑满不留白！
        .justifyContent(FlexAlign.SpaceEvenly)
        .padding({ bottom: 10 }) // 底部稍微留一点点呼吸空间
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