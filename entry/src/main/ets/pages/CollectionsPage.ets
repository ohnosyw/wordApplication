// entry/src/main/ets/pages/CollectionsPage.ets
import router from '@ohos.router'
import { CollectionManager, CollectionData } from '../utils/CollectionManager'

@Entry
@Component
struct CollectionsPage {
  @State collections: Record<string, CollectionData> = {};
  @State bookIds: string[] = [];

  // 🌟 莫兰迪颜色匹配函数
  private getBookColor(bookId: string): string {
    const colorMap: Record<string, string> = {
      'cet4': '#7EAC8A', 'cet6': '#D1A075', 'kaoyan': '#CB8585',
      'junior_high': '#A2B889', 'high_school': '#829DBF', 'ielts': '#A68CB2',
      'sat': '#7B88B5', 'gmat': '#7AAEB5'
    };
    return colorMap[bookId] || '#9CA3AF';
  }

  onPageShow() {
    this.loadData();
  }

  async loadData() {
    this.collections = await CollectionManager.getCollections(getContext(this));
    this.bookIds = Object.keys(this.collections);
  }

  build() {
    Column() {
      // 顶部导航栏 (透明化配合背景)
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => { router.back() })
        Text('我的收藏本').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 }).fontColor('#333')
      }.width('100%').padding(20)

      if (this.bookIds.length === 0) {
        Column() {
          Image($r('app.media.ic_duck_sleep')).width(100).height(100).opacity(0.5)
          Text('暂无收藏数据').fontSize(16).fontColor('#999').margin({ top: 20 })
          Text('在背单词时点击五角星即可收藏').fontSize(14).fontColor('#CCC').margin({ top: 10 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 15 }) {
          ForEach(this.bookIds, (bookId: string) => {
            ListItem() {
              Row() {
                // 🌟 核心修改：莫兰迪色块图标
                Column() {
                  Text(this.collections[bookId].bookName.substring(0, 2))
                    .fontSize(16).fontWeight(FontWeight.Medium).fontColor(Color.White)
                }
                .width(50).height(50).borderRadius(10).margin({ right: 16 })
                .backgroundColor(this.getBookColor(bookId))
                .alignItems(HorizontalAlign.Center).justifyContent(FlexAlign.Center)

                Column() {
                  Text(this.collections[bookId].bookName).fontSize(17).fontWeight(FontWeight.Bold).fontColor('#333')
                  Text(`已收藏 ${this.collections[bookId].wordIds.length} 个单词`).fontSize(13).fontColor('#999').margin({ top: 5 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)

                Text('>').fontSize(18).fontColor('#CCC')
              }
              .width('100%').padding(18).backgroundColor('#F7F7F7').borderRadius(15)
              .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })
              .onClick(() => {
                router.pushUrl({
                  url: 'pages/CollectionWordsPage',
                  params: { bookId: bookId, bookName: this.collections[bookId].bookName, wordIds: this.collections[bookId].wordIds }
                })
              })
            }
          })
        }.width('90%').layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
    })
  }
}