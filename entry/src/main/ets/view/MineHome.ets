// entry/src/main/ets/view/MineHome.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserInfo, UserManager } from '../utils/UserManager';

@Component
export struct MineHome {
  @StorageLink('currentUser') user: UserInfo | null = null;

  build() {
    Scroll() {
      Column() {
        // ---------------- 用户头像信息区域 ----------------
        Row() {
          Image($r('app.media.user_avatar')).width(60).height(60).borderRadius(30).backgroundColor('#DDD')

          Column() {
            if (this.user) {
              Row() {
                Text(this.user.username).fontSize(20).fontWeight(FontWeight.Bold)
                // 提示用户可以点击修改
                Text(' ✎').fontSize(16).fontColor('#999')
              }.onClick(() => {
                // 跳转到修改昵称页面
                router.pushUrl({ url: 'pages/EditProfilePage' });
              })

              Text(`已坚持打卡 ${this.user.checkInDays} 天`).fontSize(14).fontColor('#999').margin({ top: 4 })
            } else {
              Text("点击登录/注册").fontSize(20).fontWeight(FontWeight.Bold)
              Text("登录后可同步学习数据").fontSize(14).fontColor('#999').margin({ top: 4 })
            }
          }.alignItems(HorizontalAlign.Start).margin({ left: 15 })

        }
        .width('100%').padding(20)
        .onClick(() => {
          // 如果没登录，点击整个头部跳转登录页
          if (!this.user) {
            router.pushUrl({ url: 'pages/LoginPage' });
          }
        })

        Grid() {
          GridItem() { this.StatItem("累计单词", this.user ? this.user.totalWords.toString() : "0") }
          GridItem() { this.StatItem("今日时长", this.user ? "45min" : "0min") }
          GridItem() { this.StatItem("掌握程度", this.user ? "85%" : "0%") }
        }
        .columnsTemplate('1fr 1fr 1fr')
        .height(100).margin(10)

        // 学习量可视化图表（模拟）
        Column() {
          Text("学习遗忘曲线分析").fontWeight(FontWeight.Medium).margin({ bottom: 10 })
          Rect().width('100%').height(150).fill('#E8F2FF').radius(10)
          Text("建议：今日复习力度可加大").fontSize(12).fontColor('#4CAF50').margin(5)
        }
        .width('90%').padding(15).backgroundColor(Color.White).borderRadius(15)

        List() {
          ListItem() { this.MenuItem("错题本", "12词") }
          ListItem() { this.MenuItem("我的收藏", "5词") }
          ListItem() { this.MenuItem("全局设置", "") }
        }
        .backgroundColor(Color.White).margin(20).borderRadius(10)

        // ---------------- 账号操作区 ----------------
        if (this.user) {
          Column() {
            // 1. 退出登录 (只清凭证，不删数据)
            Button('退出登录')
              .width('90%').height(50).backgroundColor('#FFF3E0').fontColor('#FF9800')
              .margin({ bottom: 15 })
              .onClick(async () => {
                await UserManager.logout(getContext(this));
              })

            // 2. 永久注销 (危险操作，需二次确认)
            Text('注销账号')
              .fontSize(14).fontColor('#F44336').decoration({ type: TextDecorationType.Underline })
              .margin({ bottom: 40 })
              .onClick(() => {
                promptAction.showDialog({
                  title: '⚠ 危险操作',
                  message: '注销后，您的所有学习进度和数据将被永久删除且无法恢复。确定要注销吗？',
                  buttons: [
                    { text: '手滑了', color: '#4CAF50' },
                    { text: '确认永久注销', color: '#F44336' }
                  ]
                }).then(async (data) => {
                  if (data.index === 1) { // 用户点击了第二个按钮(确认)
                    let success = await UserManager.deleteAccount(getContext(this));
                    if (success) {
                      promptAction.showToast({ message: '账号已永久注销' });
                    }
                  }
                })
              })
          }.width('100%').margin({ top: 20 })
        }
      }
    }
    .backgroundColor('#F5F5F5')
  }

  @Builder StatItem(label: string, value: string) {
    Column() {
      Text(value).fontSize(18).fontWeight(FontWeight.Bold)
      Text(label).fontSize(12).fontColor('#666').margin({ top: 4 })
    }
  }

  @Builder MenuItem(title: string, extra: string) {
    Row() {
      Text(title).fontSize(16)
      Blank()
      Text(extra).fontColor('#999').margin({ right: 10 }).fontSize(14)
      Text('>').fontColor('#CCC').fontSize(16)
    }
    .width('100%').padding(15)
  }
}