// entry/src/main/ets/pages/LoginPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserManager } from '../utils/UserManager';

@Entry
@Component
struct LoginPage {
  @State userId: string = '';
  @State pass: string = '';

  build() {
    Column() {
      // 顶部返回
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => router.back())
      }.width('100%').padding(20)

      // 🌟 鸭鸭迎宾
      Image($r('app.media.ic_duck')).width(80).height(80).margin({ top: 10 })
      Text('欢迎回到背词鸭').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#333').margin({ top: 15, bottom: 40 })

      // 🌟 表单卡片
      Column() {
        TextInput({ placeholder: '请输入账号' })
          .width('100%').height(50).backgroundColor(Color.Transparent).placeholderColor('#999')
          .onChange((val) => this.userId = val)

        Divider().color('#EEEEEE').margin({ left: 15, right: 15 })

        TextInput({ placeholder: '请输入密码' })
          .width('100%').height(50).type(InputType.Password).backgroundColor(Color.Transparent).placeholderColor('#999')
          .onChange((val) => this.pass = val)
      }
      .width('85%').backgroundColor('#F7F7F7').borderRadius(15)
      .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })
      .margin({ bottom: 40 })

      // 🌟 主题按钮
      Button('登录')
        .width('85%').height(50).backgroundColor('#FFCA28').fontColor('#333')
        .fontSize(18).fontWeight(FontWeight.Medium).margin({ bottom: 25 })
        .onClick(async () => {
          if (!this.userId || !this.pass) {
            promptAction.showToast({ message: '账号和密码不能为空哦鸭' });
            return;
          }
          let success = await UserManager.login(getContext(this), this.userId, this.pass);
          if (success) {
            promptAction.showToast({ message: '登录成功' });
            router.back();
          }
        })

      // 🌟 底部链接改色
      Row() {
        Text('还没领养鸭鸭？').fontColor('#999').fontSize(14)
        Text('去注册').fontColor('#FF9800').fontSize(14).fontWeight(FontWeight.Bold)
          .onClick(() => { router.pushUrl({ url: 'pages/RegisterPage' }) })
      }
    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
    })
  }
}