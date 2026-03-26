// entry/src/main/ets/view/MineHome.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserInfo, UserManager } from '../utils/UserManager';

@Component
export struct MineHome {
  @StorageLink('currentUser') user: UserInfo | null = null;

  aboutToAppear() {
    UserManager.checkAndResetStreak(getContext(this));
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Image($r('app.media.user_avatar')).width(60).height(60).borderRadius(30).backgroundColor('#DDD')
          Column() {
            if (this.user) {
              Row() {
                Text(this.user.username).fontSize(20).fontWeight(FontWeight.Bold)
                Text(' ✎').fontSize(16).fontColor('#999')
              }.onClick(() => { router.pushUrl({ url: 'pages/EditProfilePage' }); })
              Text(`已连续打卡 ${this.user.continuousCheckInDays || 0} 天`).fontSize(14).fontColor('#999').margin({ top: 4 })
            } else {
              Text("点击登录/注册").fontSize(20).fontWeight(FontWeight.Bold)
              Text("登录后可同步学习数据").fontSize(14).fontColor('#999').margin({ top: 4 })
            }
          }.alignItems(HorizontalAlign.Start).margin({ left: 15 })
        }
        .width('100%').padding(20)
        .onClick(() => { if (!this.user) router.pushUrl({ url: 'pages/LoginPage' }); })

        if (this.user) {
          Column() {
            Row() { Text('🔥 连续打卡').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333') }.width('100%').margin({ bottom: 10 })
            Row() {
              Text((this.user.continuousCheckInDays || 0).toString()).fontSize(40).fontWeight(FontWeight.Bolder).fontColor('#FF5722')
              Text(' 天').fontSize(16).fontColor('#666').margin({ bottom: 6, left: 4 })
            }.alignItems(VerticalAlign.Bottom).width('100%')
            Text(this.user.continuousCheckInDays && this.user.continuousCheckInDays > 0 ? '保持热爱，奔赴山海！今天也要坚持哦！' : '打卡中断了，今天重新起航吧！')
              .fontSize(12).fontColor('#999').margin({ top: 8 }).width('100%')
          }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(15).margin({ top: 10, bottom: 20 })

          // 🌟 荣誉入口列表化
          List() {
            ListItem() {
              this.MenuItem("已完成词书", `${this.user.completedBooks ? this.user.completedBooks.length : 0} 本`)
            }
            .onClick(() => { router.pushUrl({ url: 'pages/CompletedBooksPage' }) })

            ListItem() {
              this.MenuItem("我的收藏", "去复习")
            }
            .onClick(() => { router.pushUrl({ url: 'pages/CollectionsPage' }) })
          }
          .backgroundColor(Color.White).width('90%').margin({ bottom: 20 }).borderRadius(10)

          Column() {
            Button('退出登录').width('90%').height(50).backgroundColor('#FFF3E0').fontColor('#FF9800').margin({ bottom: 15 })
              .onClick(async () => { await UserManager.logout(getContext(this)); })

            Text('注销账号').fontSize(14).fontColor('#F44336').decoration({ type: TextDecorationType.Underline }).margin({ bottom: 40 })
              .onClick(() => {
                promptAction.showDialog({
                  title: '⚠ 危险操作',
                  message: '注销后，您的所有学习进度和数据将被永久删除且无法恢复。确定要注销吗？',
                  buttons: [{ text: '手滑了', color: '#4CAF50' }, { text: '确认永久注销', color: '#F44336' }]
                }).then(async (data) => {
                  if (data.index === 1) {
                    let success = await UserManager.deleteAccount(getContext(this));
                    if (success) promptAction.showToast({ message: '账号已永久注销' });
                  }
                })
              })
          }.width('100%').margin({ top: 10 })
        }
      }
    }.backgroundColor('#F5F5F5').height('100%')
  }

  @Builder MenuItem(title: string, extra: string) {
    Row() {
      Text(title).fontSize(16).fontColor('#333')
      Blank()
      Text(extra).fontColor('#999').margin({ right: 10 }).fontSize(14)
      Text('>').fontColor('#CCC').fontSize(16)
    }.width('100%').padding(15)
  }
}