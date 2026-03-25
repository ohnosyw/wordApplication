// entry/src/main/ets/pages/EditProfilePage.ets
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { UserManager, UserInfo } from '../utils/UserManager';

@Entry
@Component
struct EditProfilePage {
  @State newName: string = '';

  aboutToAppear() {
    // 进来时，输入框默认显示现在的昵称
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (currentUser) {
      this.newName = currentUser.username;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24)
          .onClick(() => router.back())
        Text('修改昵称').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 16 })
        Blank()
        Text('保存').fontSize(16).fontColor('#4CAF50')
          .onClick(async () => {
            if (this.newName.trim() === '') {
              promptAction.showToast({ message: '昵称不能为空哦' });
              return;
            }
            // 调用底层方法保存新昵称
            let success = await UserManager.updateNickname(getContext(this), this.newName);
            if (success) {
              promptAction.showToast({ message: '修改成功！' });
              router.back();
            }
          })
      }.width('100%').height(56).padding({ left: 16, right: 16 }).backgroundColor(Color.White)

      // 输入区
      Column() {
        TextInput({ text: this.newName, placeholder: '请输入新昵称' })
          .width('100%')
          .height(50)
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            this.newName = value;
          })
        Divider().color('#E0E0E0')
        Text('好名字可以让背单词更有动力哦~')
          .fontSize(12).fontColor('#999').margin({ top: 10 }).width('100%')
      }.width('100%').padding(20).backgroundColor(Color.White).margin({ top: 10 })

    }.width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}