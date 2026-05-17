// entry/src/main/ets/pages/LoginPage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserManager } from '../utils/UserManager';

@Entry
@Component
struct LoginPage {
  // 绑定账号和密码的输入值
  @State userId: string = '';
  @State pass: string = '';

  build() {
    Column() {
      // 顶部返回
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => router.back())
      }.width('100%').padding(20)

      Image($r('app.media.ic_duck')).width(80).height(80).margin({ top: 10 })
      Text('欢迎回到背词鸭').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#333').margin({ top: 15, bottom: 40 })

      // 登录表单卡片
      Column() {
        TextInput({ placeholder: '请输入账号' })
          .width('100%').height(50).backgroundColor(Color.Transparent).placeholderColor('#999')
          // 数据单向绑定：键盘输入实时更新
          .onChange((val) => this.userId = val)

        Divider().color('#EEEEEE').margin({ left: 15, right: 15 })

        TextInput({ placeholder: '请输入密码' })
          .width('100%').height(50).type(InputType.Password).backgroundColor(Color.Transparent).placeholderColor('#999')
          .onChange((val) => this.pass = val)
      }
      .width('85%').backgroundColor('#F7F7F7').borderRadius(15)
      .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })
      .margin({ bottom: 40 })

      // 核心登录逻辑
      Button('登录')
        .width('85%').height(50).backgroundColor('#FFCA28').fontColor('#333')
        .fontSize(18).fontWeight(FontWeight.Medium).margin({ bottom: 25 })
        .onClick(async () => {
          // 防空校验
          if (!this.userId || !this.pass) {
            promptAction.showToast({ message: '账号和密码不能为空哦鸭' });
            return;
          }
          // 异步登录鉴权
          let success = await UserManager.login(getContext(this), this.userId, this.pass);
          if (success) {
            promptAction.showToast({ message: '登录成功' });
            // 页面回退：销毁登录页，回到首页，此时首页会自动监听到 AppStorage 的变化并刷新 UI
            router.back();
          }
        })

      // 切换注册
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