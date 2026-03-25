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

  aboutToAppear(): void {
    // 读取全局状态
    let currentPlan = AppStorage.get<PlanData>('studyPlan');
    if (currentPlan) {
      this.dailyNew = currentPlan.dailyNew;
      this.dailyReview = currentPlan.dailyReview;
      this.studyMode = currentPlan.studyMode;
    } else {
      // 如果完全没有初始值，给定一个科学的默认匹配
      this.dailyReview = Math.round(this.dailyNew * 2.5);
    }
  }

  // 核心逻辑：动态计算复习词数（按照 2.5 倍计算）
  updateReviewCount(newWords: number) {
    this.dailyNew = newWords;
    this.dailyReview = Math.round(newWords * 2.5);
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .margin({ left: 16 })
          .onClick(() => { router.back() })

        Text('学习计划设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })

        Blank()

        Text('保存')
          .fontSize(16)
          .fontColor('#4CAF50')
          .margin({ right: 16 })
          .onClick(() => {
            this.savePlan()
          })
      }
      .width('100%')
      .height(56)
      .backgroundColor(Color.White)

      Scroll() {
        Column() {
          // 每日新词数设置 (主动控制)
          Column() {
            Row() {
              Text('每日新词数').fontSize(16).fontWeight(FontWeight.Medium)
              Blank()
              Text(this.dailyNew + ' 词').fontSize(16).fontColor('#4CAF50')
            }.width('100%')

            Slider({ value: this.dailyNew, min: 5, max: 100, step: 5, style: SliderStyle.OutSet })
              .blockColor('#4CAF50').trackColor('#E0E0E0').selectedColor('#4CAF50').showTips(true)
              .onChange((value: number) => {
                // 调用动态计算函数
                this.updateReviewCount(value);
              })
              .width('100%').margin({ top: 10 })

            // 快速选择
            Row() {
              ForEach([10, 20, 30, 50], (item: number) => {
                Text(item + '词')
                  .fontSize(14)
                  .fontColor(this.dailyNew === item ? '#4CAF50' : '#666')
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor(this.dailyNew === item ? '#E8F5E9' : '#F5F5F5')
                  .borderRadius(20)
                  .onClick(() => {
                    // 调用动态计算函数
                    this.updateReviewCount(item);
                  })
              })
            }.width('100%').justifyContent(FlexAlign.SpaceAround).margin({ top: 10 })
          }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(15).margin({ top: 20 })

          // 每日复习数展示 (被动展示，自动结算)
          Column() {
            Row() {
              Text('预计每日复习').fontSize(16).fontWeight(FontWeight.Medium)
              Blank()
              Text(this.dailyReview + ' 词').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FF9800')
            }.width('100%')

            Text('根据艾宾浩斯遗忘曲线，科学复习量约为新词的 2.5 倍，系统已为您自动匹配最佳数量。')
              .fontSize(12).fontColor('#999').lineHeight(18).width('100%').margin({ top: 10 })
          }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(15).margin({ top: 20 })

          // 学习模式设置
          Column() {
            Text('学习模式').fontSize(16).fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 15 })
            Row() {
              this.createModeCard(0, '先学新词再复习', '先学习新词，完成后再进行复习')
              this.createModeCard(1, '新词复习混合', '新词和复习词随机混合出现')
            }.width('100%').justifyContent(FlexAlign.SpaceBetween)
          }.width('90%').padding(20).backgroundColor(Color.White).borderRadius(15).margin({ top: 20 })

          // 学习建议
          Column() {
            Text('学习建议').fontSize(16).fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 10 })
            Text('• 建议新词数不超过50个，以保证学习效果').fontSize(14).fontColor('#666').width('100%').margin({ bottom: 5 })
            Text('• 学习新词时请结合例句，不要死记硬背').fontSize(14).fontColor('#666').width('100%').margin({ bottom: 5 })
            Text('• 坚持每天打卡才是背单词的终极秘诀').fontSize(14).fontColor('#666').width('100%')
          }.width('90%').padding(20).backgroundColor('#FFF9C4').borderRadius(15).margin({ top: 20, bottom: 20 })
        }.width('100%').alignItems(HorizontalAlign.Center)
      }.backgroundColor('#F5F5F5')
    }.width('100%').height('100%').backgroundColor('#F5F5F5')
  }

  @Builder
  createModeCard(mode: number, title: string, description: string) {
    Column() {
      Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.studyMode === mode ? '#4CAF50' : '#333').margin({ bottom: 8 })
      Text(description).fontSize(12).fontColor('#999').textAlign(TextAlign.Center).maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
    }
    .width(150).padding(15)
    .backgroundColor(this.studyMode === mode ? '#E8F5E9' : '#F5F5F5')
    .borderRadius(12)
    .border({ width: this.studyMode === mode ? 2 : 1, color: this.studyMode === mode ? '#4CAF50' : '#E0E0E0' })
    .onClick(() => { this.studyMode = mode })
  }

  // 保存计划并同步到当前用户数据库
  async savePlan() {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    let plan = AppStorage.get<PlanData>('studyPlan');

    if (plan && currentUser) {
      plan.dailyNew = Math.round(this.dailyNew);
      plan.dailyReview = Math.round(this.dailyReview); // 存入自动计算好的值
      plan.studyMode = this.studyMode;

      // 1. 更新内存
      AppStorage.setOrCreate('studyPlan', plan);
      // 2. 写入数据库
      await UserManager.saveUserPlan(getContext(this), currentUser.userId, plan);
    }

    router.back();
  }
}