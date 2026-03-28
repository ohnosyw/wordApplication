// entry/src/main/ets/view/MineHome.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserInfo, UserManager } from '../utils/UserManager';

// 1. 自定义注销账号弹窗
@CustomDialog
struct DeleteAccountDialog {
  controller: CustomDialogController
  onConfirm: () => void = () => {}

  build() {
    Column() {
      Image($r('app.media.ic_duck_sleep'))
        .width(90).height(90).margin({ top: -45, bottom: 10 })

      Text('账号注销确认')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333').margin({ bottom: 12 })

      Text('注销后，您的所有学习进度和数据将被永久删除且无法恢复。你真的要离开鸭鸭吗？')
        .fontSize(14).fontColor('#666').textAlign(TextAlign.Center).lineHeight(20)
        .padding({ left: 10, right: 10 }).margin({ bottom: 25 })

      Button('确认永久注销')
        .width('100%').height(45).backgroundColor('#F7F7F7').fontColor('#F44336')
        .border({ width: 1, color: '#F44336' }).margin({ bottom: 12 })
        .onClick(() => {
          this.onConfirm()
          this.controller.close()
        })

      Button('手滑了，留下来')
        .width('100%').height(45).backgroundColor('#FFCA28').fontColor('#333')
        .onClick(() => { this.controller.close() })
    }
    .width('85%').padding(20).borderRadius(20)
    .linearGradient({ direction: GradientDirection.Bottom, colors: [['#FFFDE7', 0.0], ['#FFF9C4', 1.0]] })
    .shadow({ radius: 20, color: '#33000000' })
  }
}

@Component
export struct MineHome {
  @StorageLink('currentUser') user: UserInfo | null = null;

  deleteAccountDialogController: CustomDialogController = new CustomDialogController({
    builder: DeleteAccountDialog({
      onConfirm: () => { this.handleDeleteAccount() }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  // 🌟 核心修复：更严谨的三段式状态判断
  private getTodayStatus(): 'unstarted' | 'learning' | 'completed' {
    if (!this.user) return 'unstarted';
    let today = new Date().toDateString();

    // 只有底层记录了打卡日期（点击了完成任务），才算真正 completed，此时打卡天数才加了，鸭子才会醒
    if (this.user.lastCheckInDate === today) {
      return 'completed';
    }
    // 如果今天背了单词，但是没点“完成任务”，属于 learning 状态，鸭子依然在睡觉
    if (this.user.todayStudiedCount !== undefined && this.user.todayStudiedCount > 0) {
      return 'learning';
    }

    return 'unstarted';
  }

  async handleDeleteAccount() {
    let success = await UserManager.deleteAccount(getContext(this));
    if (success) {
      promptAction.showToast({ message: '账号已永久注销' });
    }
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
            .width(70).height(70).borderRadius(35).backgroundColor('#E0E0E0')
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
          // --- 2. 连续打卡卡片 ---
          Column() {
            Row() {
              // 🌟 只有真正 completed 时，鸭子才会换成 active！
              Image(this.getTodayStatus() === 'completed' ? $r('app.media.ic_duck_active') : $r('app.media.ic_duck_sleep'))
                .width(30).height(30).margin({ right: 10 })
                .animation({ duration: 400, curve: Curve.EaseInOut })

              Text('连续打卡').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333')
              Blank()

              // 🌟 动态状态标签
              Text(this.getTodayStatus() === 'completed' ? '今日已达标' : (this.getTodayStatus() === 'learning' ? '今日待完成' : '今日待叫醒'))
                .fontSize(11)
                .fontColor(this.getTodayStatus() === 'completed' ? '#FF9800' : (this.getTodayStatus() === 'learning' ? '#2196F3' : '#999'))
                .backgroundColor(this.getTodayStatus() === 'completed' ? '#FFF8E1' : (this.getTodayStatus() === 'learning' ? '#E3F2FD' : '#EAEAEA'))
                .padding({ left: 8, right: 8, top: 4, bottom: 4 }).borderRadius(6)
            }.width('100%').margin({ bottom: 12 }).alignItems(VerticalAlign.Center)

            Row() {
              Text((this.user.continuousCheckInDays || 0).toString())
                .fontSize(45).fontWeight(FontWeight.Bolder).fontColor('#FF9800')
              Text(' 天').fontSize(16).fontColor('#666').margin({ bottom: 8, left: 4 })
            }.alignItems(VerticalAlign.Bottom).width('100%')

            // 🌟 更细腻的情感互动文案
            Text(
              this.getTodayStatus() === 'completed' ? '太棒了！今天也准时把鸭鸭叫醒完成任务了鸭！' :
                (this.getTodayStatus() === 'learning' ? '鸭鸭还在梦里，快去点下最后一步打卡把它叫醒吧！' : '鸭鸭还在梦游，快去背几个单词把它叫醒鸭！')
            )
              .fontSize(12).fontColor('#999').margin({ top: 10 }).width('100%')
          }
          .width('90%').padding(20).backgroundColor('#F7F7F7').borderRadius(15).margin({ top: 10, bottom: 20 })
          .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

          // --- 3. 功能列表 ---
          List() {
            ListItem() { this.MenuItem("已完成词书", `${this.user.completedBooks ? this.user.completedBooks.length : 0} 本`) }
            .onClick(() => { router.pushUrl({ url: 'pages/CompletedBooksPage' }) })
            ListItem() { this.MenuItem("我的收藏", "去复习") }
            .onClick(() => { router.pushUrl({ url: 'pages/CollectionsPage' }) })
          }
          .backgroundColor('#F7F7F7').width('90%').margin({ bottom: 30 }).borderRadius(15)
          .divider({ strokeWidth: 1, color: '#EEEEEE', startMargin: 15, endMargin: 15 })

          // --- 4. 退出与注销 ---
          Column() {
            Button('退出登录')
              .width('90%').height(50).backgroundColor('#FFF8E1').fontColor('#FF9800')
              .fontSize(16).fontWeight(FontWeight.Medium).margin({ bottom: 20 }).borderRadius(12)
              .onClick(async () => { await UserManager.logout(getContext(this)); })

            Text('注销账号')
              .fontSize(14).fontColor('#BDBDBD').decoration({ type: TextDecorationType.Underline }).margin({ bottom: 40 })
              .onClick(() => {
                this.deleteAccountDialogController.open()
              })
          }.width('100%')
        }
      }
    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
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