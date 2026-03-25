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
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24)
          .onClick(() => router.back())
      }.width('100%').padding(20)

      Text('注册新账号').fontSize(28).fontWeight(FontWeight.Bold).margin({ top: 40, bottom: 40 })

      TextInput({ placeholder: '设置账号 (如手机号)' })
        .width('85%').height(50).margin({ bottom: 20 })
        .onChange((val) => this.userId = val)

      TextInput({ placeholder: '设置昵称' })
        .width('85%').height(50).margin({ bottom: 20 })
        .onChange((val) => this.username = val)

      TextInput({ placeholder: '设置密码' })
        .width('85%').height(50).type(InputType.Password).margin({ bottom: 30 })
        .onChange((val) => this.pass = val)

      Button('立即注册')
        .width('85%').height(50).backgroundColor('#4CAF50')
        .onClick(async () => {
          if (!this.userId || !this.username || !this.pass) {
            promptAction.showToast({ message: '请完整填写信息' });
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
            promptAction.showToast({ message: '注册成功，请登录' });
            router.back();
          }
        })
    }
    .width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}