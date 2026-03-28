// entry/src/main/ets/pages/RegisterPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserManager, UserInfo } from '../utils/UserManager';

@Entry
@Component
struct RegisterPage {
  @State userId: string = '';
  @State username: string = '';
  @State pass: string = '';

  build() {
    Column() {
      // 顶部返回
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => router.back())
      }.width('100%').padding(20)

      // 🌟 鸭鸭迎新
      Image($r('app.media.ic_duck_active')).width(80).height(80).margin({ top: 10 })
      Text('领养你的专属背词鸭').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#333').margin({ top: 15, bottom: 40 })

      // 🌟 表单卡片
      Column() {
        TextInput({ placeholder: '设置账号 (如手机号)' })
          .width('100%').height(50).backgroundColor(Color.Transparent).placeholderColor('#999')
          .onChange((val) => this.userId = val)

        Divider().color('#EEEEEE').margin({ left: 15, right: 15 })

        TextInput({ placeholder: '给鸭鸭取个昵称吧' })
          .width('100%').height(50).backgroundColor(Color.Transparent).placeholderColor('#999')
          .onChange((val) => this.username = val)

        Divider().color('#EEEEEE').margin({ left: 15, right: 15 })

        TextInput({ placeholder: '设置密码' })
          .width('100%').height(50).type(InputType.Password).backgroundColor(Color.Transparent).placeholderColor('#999')
          .onChange((val) => this.pass = val)
      }
      .width('85%').backgroundColor('#F7F7F7').borderRadius(15)
      .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })
      .margin({ bottom: 40 })

      // 🌟 主题按钮
      Button('立即注册')
        .width('85%').height(50).backgroundColor('#FFCA28').fontColor('#333')
        .fontSize(18).fontWeight(FontWeight.Medium)
        .onClick(async () => {
          if (!this.userId || !this.username || !this.pass) {
            promptAction.showToast({ message: '请填写完整信息' });
            return;
          }

          let newUser: UserInfo = {
            userId: this.userId,
            username: this.username,
            password: this.pass,
            checkInDays: 0,
            totalWords: 0
          };

          let success = await UserManager.register(getContext(this), newUser);
          if (success) {
            promptAction.showToast({ message: '注册成功，快去登录吧！' });
            router.back();
          }
        })
    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
    })
  }
}