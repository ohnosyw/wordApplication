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
        Image($r('app.media.ic_back')).width(24).height(24)
          .onClick(() => router.back())
      }.width('100%').padding(20)

      Text('欢迎回到背词鸭').fontSize(28).fontWeight(FontWeight.Bold).margin({ top: 40, bottom: 40 })

      TextInput({ placeholder: '请输入账号' })
        .width('85%').height(50).margin({ bottom: 20 })
        .onChange((val) => this.userId = val)

      TextInput({ placeholder: '请输入密码' })
        .width('85%').height(50).type(InputType.Password).margin({ bottom: 30 })
        .onChange((val) => this.pass = val)

      Button('登录')
        .width('85%').height(50).backgroundColor('#4CAF50').margin({ bottom: 20 })
        .onClick(async () => {
          if (!this.userId || !this.pass) {
            promptAction.showToast({ message: '账号和密码不能为空' });
            return;
          }
          let success = await UserManager.login(getContext(this), this.userId, this.pass);
          if (success) {
            promptAction.showToast({ message: '登录成功' });
            router.back();
          }
        })

      Row() {
        Text('没有账号？').fontColor('#666')
        Text('去注册').fontColor('#4CAF50').onClick(() => {
          router.pushUrl({ url: 'pages/RegisterPage' })
        })
      }
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}