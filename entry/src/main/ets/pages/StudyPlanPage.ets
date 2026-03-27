// entry/src/main/ets/pages/StudyPlanPage.ets
import router from '@ohos.router'
import { PlanData } from '../model/StudyPlan'
import { UserManager, UserInfo } from '../utils/UserManager'

@Entry
@Component
struct StudyPlanPage {
  @State dailyNew: number = 20
  @State dailyReview: number = 50
  @State studyMode: number = 0
  @State plan: PlanData | null = null;

  // 每日任务滑轮数据
  private options: string[] = [];
  private newWordsList: number[] = [];
  @State selectedPickerIndex: number = 3;

  // 学习模式滑轮数据
  private modeOptions: string[] = ['先学新词再复习', '新词复习混合'];

  // 🌟 为了匹配 BookSelectPage 的莫兰迪色系，这里定义一个简单的颜色查找
  private getBookColor(bookId: string): string {
    const colorMap: Record<string, string> = {
      'cet4': '#7EAC8A', 'cet6': '#D1A075', 'kaoyan': '#CB8585',
      'junior_high': '#A2B889', 'high_school': '#829DBF', 'ielts': '#A68CB2',
      'sat': '#7B88B5', 'gmat': '#7AAEB5'
    };
    return colorMap[bookId] || '#9CA3AF'; // 找不到则返回中性灰
  }

  aboutToAppear(): void {
    let currentPlan = AppStorage.get<PlanData>('studyPlan');
    if (currentPlan) {
      this.plan = currentPlan;
      this.dailyNew = currentPlan.dailyNew;
      this.dailyReview = currentPlan.dailyReview;
      this.studyMode = currentPlan.studyMode;
    } else {
      this.dailyReview = Math.round(this.dailyNew * 2.5);
    }

    let totalWords = this.plan ? this.plan.totalWords : 1000;

    for (let i = 5; i <= 100; i += 5) {
      this.newWordsList.push(i);
      let review = Math.round(i * 2.5);
      let days = Math.ceil(totalWords / i);
      this.options.push(`新词 ${i}  预计复习 ${review}  需要${days}天`);
    }

    let index = this.newWordsList.indexOf(this.dailyNew);
    this.selectedPickerIndex = index >= 0 ? index : 3;
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24).height(24).margin({ left: 16 })
          .onClick(() => { router.back() })

        Text('调整学习计划').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333').margin({ left: 16 })
        Blank()
        Text('保存').fontSize(16).fontColor('#FF9800').margin({ right: 16 })
          .onClick(() => { this.savePlan() })
      }
      .width('100%').height(56)

      Scroll() {
        Column() {

          // 🌟 核心修改：将当前词书档案换成与 BookSelectPage 一致的通栏样式
          if (this.plan) {
            Column() {
              Row() {
                // 莫兰迪色块图标
                Column() {
                  Text(this.plan.bookName.substring(0, 2))
                    .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.White)
                }
                .width(48).height(48)
                .backgroundColor(this.getBookColor(this.plan.bookId))
                .borderRadius(8).margin({ right: 16 })
                .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)

                // 词书信息
                Column() {
                  Row() {
                    Text(this.plan.bookName).fontSize(16).fontWeight(FontWeight.Medium).fontColor('#333')
                    Blank()
                    Text('当前目标').fontSize(11).fontColor('#666666')
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor('#E6E6E6').borderRadius(4)
                  }.width('100%')

                  Row() {
                    Text(`共 ${this.plan.totalWords} 词`).fontSize(13).fontColor('#999')
                    Blank()
                    Text('正在学习').fontSize(13).fontColor('#999')
                  }.width('100%').margin({ top: 6 })
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
              }
              .width('100%').padding(18)
            }
            .width('90%').backgroundColor('#F7F7F7').borderRadius(15)
            .margin({ top: 10, bottom: 5 })
            .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })
          }

          // 栏目 1：每日任务规划
          Column() {
            Row() { Text('每日任务规划').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333') }
            .width('100%').margin({ bottom: 10 })

            TextPicker({ range: this.options, selected: this.selectedPickerIndex })
              .canLoop(false)
              .textStyle({ color: '#999', font: { size: 14 } })
              .selectedTextStyle({ color: '#FF9800', font: { size: 16, weight: FontWeight.Bold } })
              .onChange((value: string | string[], index: number | number[]) => {
                let idx = typeof index === 'number' ? index : index[0];
                this.selectedPickerIndex = idx;
                this.dailyNew = this.newWordsList[idx];
                this.dailyReview = Math.round(this.dailyNew * 2.5);
              })
              .width('100%').height(140)
          }
          .width('90%').padding(20).backgroundColor('#F7F7F7').borderRadius(15)
          .margin({ top: 15 }).shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

          // 栏目 2：学习模式设置
          Column() {
            Row() { Text('学习模式').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#333') }
            .width('100%').margin({ bottom: 10 })

            TextPicker({ range: this.modeOptions, selected: this.studyMode })
              .canLoop(false).textStyle({ color: '#999', font: { size: 14 } })
              .selectedTextStyle({ color: '#FF9800', font: { size: 16, weight: FontWeight.Bold } })
              .onChange((value: string | string[], index: number | number[]) => {
                this.studyMode = typeof index === 'number' ? index : index[0];
              })
              .width('100%').height(90)
          }
          .width('90%').padding(20).backgroundColor('#F7F7F7').borderRadius(15)
          .margin({ top: 20 }).shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })

          // 底部情绪插画
          Column() {
            Image($r('app.media.ic_duck')).width(60).height(60).opacity(0.8)
            Text('选好计划，就不能反悔了鸭！').fontSize(12).fontColor('#BDBDBD').margin({ top: 8 })
          }
          .margin({ top: 40, bottom: 40 }).alignItems(HorizontalAlign.Center)

        }.width('100%').alignItems(HorizontalAlign.Center)
      }.layoutWeight(1)
    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
    })
  }

  async savePlan() {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    let plan = AppStorage.get<PlanData>('studyPlan');

    if (plan && currentUser) {
      plan.dailyNew = Math.round(this.dailyNew);
      plan.dailyReview = Math.round(this.dailyReview);
      plan.studyMode = this.studyMode;
      AppStorage.setOrCreate('studyPlan', plan);
      await UserManager.saveUserPlan(getContext(this), currentUser.userId, plan);
    }
    router.back();
  }
}