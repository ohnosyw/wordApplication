// entry/src/main/ets/pages/CollectionsPage.ets
import router from '@ohos.router'
import { CollectionManager, CollectionData } from '../utils/CollectionManager'

@Entry
@Component
struct CollectionsPage {
  @State collections: Record<string, CollectionData> = {};
  @State bookIds: string[] = [];

  onPageShow() {
    this.loadData();
  }

  async loadData() {
    this.collections = await CollectionManager.getCollections(getContext(this));
    this.bookIds = Object.keys(this.collections);
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => { router.back() })
        Text('我的收藏本').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
      }.width('100%').padding(20).backgroundColor(Color.White)

      if (this.bookIds.length === 0) {
        Column() {
          Text('暂无收藏数据').fontSize(16).fontColor('#999').margin({ top: 100 })
          Text('在背单词时点击右上角五角星即可收藏').fontSize(14).fontColor('#CCC').margin({ top: 10 })
        }.width('100%').layoutWeight(1).alignItems(HorizontalAlign.Center)
      } else {
        List({ space: 15 }) {
          ForEach(this.bookIds, (bookId: string) => {
            ListItem() {
              Row() {
                Text('📁').fontSize(24).margin({ right: 15 })
                Column() {
                  Text(this.collections[bookId].bookName).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333')
                  Text(`共 ${this.collections[bookId].wordIds.length} 个单词`).fontSize(14).fontColor('#999').margin({ top: 5 })
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('>').fontSize(18).fontColor('#CCC')
              }
              .width('100%').padding(20).backgroundColor(Color.White).borderRadius(15)
              .shadow({ radius: 10, color: '#0A000000', offsetX: 0, offsetY: 5 })
              .onClick(() => {
                // 点击进入具体单词列表
                router.pushUrl({
                  url: 'pages/CollectionWordsPage',
                  params: { bookId: bookId, bookName: this.collections[bookId].bookName, wordIds: this.collections[bookId].wordIds }
                })
              })
            }
          })
        }.width('90%').layoutWeight(1).margin({ top: 20 })
      }
    }.width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}