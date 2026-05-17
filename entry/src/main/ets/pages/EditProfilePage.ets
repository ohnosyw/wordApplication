// entry/src/main/ets/pages/EditProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserManager, UserInfo } from '../utils/UserManager';

@Entry
@Component
struct EditProfilePage {
  // 绑定输入框中的内容
  @State newName: string = '';

  // 用户进入修改页面时，输入框里应该默认显示他现在的名字
  aboutToAppear() {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (currentUser) {
      this.newName = currentUser.username;
    }
  }

  build() {
    Column() {
      // 自定义顶部标题栏
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24)
          .onClick(() => router.back())
        Text('修改昵称').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333').margin({ left: 16 })
        Blank()

        Text('保存').fontSize(16).fontColor('#FF9800').fontWeight(FontWeight.Medium)
          .onClick(async () => {
            if (this.newName.trim() === '') {
              promptAction.showToast({ message: '昵称不能为空哦' });
              return;
            }
            let success = await UserManager.updateNickname(getContext(this), this.newName);
            if (success) {
              promptAction.showToast({ message: '修改成功！' });
              router.back();
            }
          })
      }.width('100%').height(56).padding({ left: 20, right: 20 })

      Column() {
        TextInput({ text: this.newName, placeholder: '请输入新昵称' })
          .width('100%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .placeholderColor('#999')
          .onChange((value: string) => {
            this.newName = value;
          })
        Divider().color('#EEEEEE').margin({ left: 10, right: 10 })
        Text('好名字可以让背单词更有动力哦~')
          .fontSize(12).fontColor('#999').margin({ top: 15, left: 10 }).width('100%')
      }
      .width('90%').padding({ top: 10, bottom: 20, left: 10, right: 10 })
      .backgroundColor('#F7F7F7').borderRadius(15)
      .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })
      .margin({ top: 20 })

    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
    })
  }
}