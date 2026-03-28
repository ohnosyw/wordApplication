// entry/src/main/ets/view/MineHome.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserInfo, UserManager } from '../utils/UserManager';

@Component
export struct MineHome {
  @StorageLink('currentUser') user: UserInfo | null = null;

  // 🌟 辅助函数：判断今天是否已经开始学习（即打卡）
  private hasCheckedInToday(): boolean {
    if (!this.user) return false;
    // 逻辑：只要今日学习量大于 0，鸭子就会醒来
    return (this.user.todayStudiedCount !== undefined && this.user.todayStudiedCount > 0);
  }

  aboutToAppear() {
    UserManager.checkAndResetStreak(getContext(this));
  }

  build() {
    Scroll() {
      Column() {
        // --- 1. 用户基本信息栏 ---
        Row() {
          Image($r('app.media.user_avatar'))
            .width(70)
            .height(70)
            .borderRadius(35)
            .backgroundColor('#E0E0E0')
            .border({ width: 2, color: '#FFF' })

          Column() {
            if (this.user) {
              Row() {
                Text(this.user.username).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333')
                Text(' ✎').fontSize(16).fontColor('#999')
              }.onClick(() => { router.pushUrl({ url: 'pages/EditProfilePage' }); })
              Text(`鸭鸭陪伴你的第 ${this.user.checkInDays || 1} 天`).fontSize(14).fontColor('#666').margin({ top: 6 })
            } else {
              Text("点击登录/注册").fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333')
              Text("登录后开启背词鸭之旅").fontSize(14).fontColor('#666').margin({ top: 6 })
            }
          }.alignItems(HorizontalAlign.Start).margin({ left: 15 })
        }
        .width('100%').padding({ left: 25, right: 25, top: 40, bottom: 20 })
        .onClick(() => { if (!this.user) router.pushUrl({ url: 'pages/LoginPage' }); })

        if (this.user) {
          // --- 2. 连续打卡卡片 (形态进化鸭子) ---
          Column() {
            Row() {
              // 🌟 核心修改：根据打卡状态动态切换鸭子图片
              Image(this.hasCheckedInToday() ? $r('app.media.ic_duck_active') : $r('app.media.ic_duck_sleep'))
                .width(30)
                .height(30)
                .margin({ right: 10 })
                .animation({ duration: 400, curve: Curve.EaseInOut })

              Text('连续打卡')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#333')

              Blank()

              // 右上角状态小标签
              Text(this.hasCheckedInToday() ? '今日已达标' : '今日待叫醒')
                .fontSize(11)
                .fontColor(this.hasCheckedInToday() ? '#FF9800' : '#999')
                .backgroundColor(this.hasCheckedInToday() ? '#FFF8E1' : '#EAEAEA')
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .borderRadius(6)
            }.width('100%').margin({ bottom: 12 }).alignItems(VerticalAlign.Center)

            Row() {
              Text((this.user.continuousCheckInDays || 0).toString())
                .fontSize(45).fontWeight(FontWeight.Bolder).fontColor('#FF9800')
              Text(' 天').fontSize(16).fontColor('#666').margin({ bottom: 8, left: 4 })
            }.alignItems(VerticalAlign.Bottom).width('100%')

            // 根据状态切换互动文案
            Text(this.hasCheckedInToday() ?
              '太棒了！今天也准时把鸭鸭叫醒完成任务了！' :
              '鸭鸭还在梦游，快去背几个单词把它叫醒')
              .fontSize(12).fontColor('#999').margin({ top: 10 }).width('100%')
          }
          .width('90%')
          .padding(20)
          .backgroundColor('#F7F7F7')
          .borderRadius(15)
          .margin({ top: 10, bottom: 20 })
          .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

          // --- 3. 功能列表 ---
          List() {
            ListItem() {
              this.MenuItem("已完成词书", `${this.user.completedBooks ? this.user.completedBooks.length : 0} 本`)
            }.onClick(() => { router.pushUrl({ url: 'pages/CompletedBooksPage' }) })

            ListItem() {
              this.MenuItem("我的收藏", "去复习")
            }.onClick(() => { router.pushUrl({ url: 'pages/CollectionsPage' }) })
          }
          .backgroundColor('#F7F7F7')
          .width('90%')
          .margin({ bottom: 30 })
          .borderRadius(15)
          .divider({ strokeWidth: 1, color: '#EEEEEE', startMargin: 15, endMargin: 15 })

          // --- 4. 退出与注销 ---
          Column() {
            Button('退出登录')
              .width('90%')
              .height(50)
              .backgroundColor('#FFF8E1')
              .fontColor('#FF9800')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 20 })
              .borderRadius(12)
              .onClick(async () => { await UserManager.logout(getContext(this)); })

            Text('注销账号')
              .fontSize(14)
              .fontColor('#BDBDBD')
              .decoration({ type: TextDecorationType.Underline })
              .margin({ bottom: 40 })
              .onClick(() => {
                promptAction.showDialog({
                  title: '⚠ 危险操作',
                  message: '注销后，您的所有学习进度和数据将被永久删除。确定要注销吗？',
                  buttons: [{ text: '手滑了', color: '#4CAF50' }, { text: '确认永久注销', color: '#F44336' }]
                }).then(async (data) => {
                  if (data.index === 1) {
                    let success = await UserManager.deleteAccount(getContext(this));
                    if (success) promptAction.showToast({ message: '账号已永久注销' });
                  }
                })
              })
          }.width('100%')
        }
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

  @Builder MenuItem(title: string, extra: string) {
    Row() {
      Text(title).fontSize(16).fontColor('#333').fontWeight(FontWeight.Medium)
      Blank()
      Text(extra).fontColor('#999').margin({ right: 10 }).fontSize(14)
      Text('>').fontColor('#CCC').fontSize(16).fontWeight(FontWeight.Bold)
    }.width('100%').padding(18)
  }
}