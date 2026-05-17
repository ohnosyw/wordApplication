import { WordHome } from '../view/WordHome'
import { MineHome } from '../view/MineHome'

@Entry
@Component
struct MainPage {
  // 记录当前选中的 Tab 索引
  @State currentIndex: number = 0
  private controller: TabsController = new TabsController()

  @Builder TabBuilder(title: string, index: number, icon: Resource) {
    Column() {
      Image(icon)
        .width(24).height(24)
        // 如果当前索引等于该 Tab 的索引
        .fillColor(this.currentIndex === index ? '#FF9800' : '#999')
      Text(title)
        .margin({ top: 4 })
        .fontSize(12)
        .fontColor(this.currentIndex === index ? '#FF9800' : '#999')
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height(50)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
      TabContent() {
        WordHome() // 单词模块
      }.tabBar(this.TabBuilder('单词', 0, $r('app.media.ic_word')))

      TabContent() {
        MineHome() // 个人中心
      }.tabBar(this.TabBuilder('我的', 1, $r('app.media.ic_user')))
    }
    // 事件监听：当用户滑动屏幕切换 Tab，或点击底部 Tab 切换时触发
    .onChange((index: number) => {
      this.currentIndex = index
    })
    .barHeight(60)
    .barBackgroundColor('#F7F7F7')
  }
}