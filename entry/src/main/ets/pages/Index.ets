// entry/src/main/ets/pages/MainPage.ets
import { WordHome } from '../view/WordHome'
import { MineHome } from '../view/MineHome'

@Entry
@Component
struct MainPage {
  @State currentIndex: number = 0
  private controller: TabsController = new TabsController()

  @Builder TabBuilder(title: string, index: number, icon: Resource) {
    Column() {
      Image(icon)
        .width(24).height(24)
        // 🌟 细节优化：选中颜色改为与主题呼应的亮橙色，未选中保持灰色
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
    .onChange((index: number) => {
      this.currentIndex = index
    })
    .barHeight(60)
    // 🌟 核心修改：设置底部导航栏的背景颜色为高级淡灰色
    .barBackgroundColor('#F7F7F7')
  }
}