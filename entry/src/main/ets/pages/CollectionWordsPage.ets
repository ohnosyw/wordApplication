// entry/src/main/ets/pages/CollectionWordsPage.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { DataLoader } from '../utils/DataLoader'
import { WordEntry } from '../model/WordModel'
import { CollectionManager } from '../utils/CollectionManager'

@Entry
@Component
struct CollectionWordsPage {
  @State bookId: string = '';
  @State bookName: string = '';
  @State wordIds: string[] = [];
  @State words: WordEntry[] = [];
  @State isLoading: boolean = true;

  @State isMasked: boolean = false;
  @State dailyLimit: number = 20;

  async onPageShow() {
    this.isLoading = true;
    let params = router.getParams() as Record<string, string | string[]>;
    if (params) {
      this.bookId = params['bookId'] as string;
      this.bookName = params['bookName'] as string;

      let cols = await CollectionManager.getCollections(getContext(this));
      if (cols[this.bookId]) {
        this.wordIds = cols[this.bookId].wordIds;
        this.dailyLimit = cols[this.bookId].dailyLimit || 20;
      }

      let allWords = await DataLoader.loadWordBook(getContext(this), `${this.bookId}.json`);
      this.words = allWords.filter(w => this.wordIds.includes(w.content.word.wordId));
    }
    this.isLoading = false;
  }

  @Builder SettingsMenu() {
    Menu() {
      MenuItem({ content: `设置单次任务量 (当前: ${this.dailyLimit})` })
        .onClick(() => {
          TextPickerDialog.show({
            range: ['10', '20', '30', '50', '100', '全部'],
            selected: 1,
            onAccept: async (value: TextPickerResult) => {
              let limitStr = (typeof value.value === 'string') ? value.value : value.value[0];
              let limit = limitStr === '全部' ? 9999 : parseInt(limitStr);
              this.dailyLimit = limit;
              await CollectionManager.setDailyLimit(getContext(this), this.bookId, limit);
              promptAction.showToast({ message: `单次特训量已设置为 ${limitStr}` });
            }
          })
        })

      MenuItem({ content: this.isMasked ? '取消遮挡释义' : '遮挡释义' })
        .onClick(() => {
          this.isMasked = !this.isMasked;
        })

      MenuItem({ content: '一键清空收藏词' })
        .onClick(() => {
          promptAction.showDialog({
            title: '⚠ 危险操作',
            message: '确定要清空本词书的所有收藏词吗？操作不可恢复。',
            buttons: [
              { text: '取消', color: '#999' },
              { text: '确认清空', color: '#F44336' }
            ]
          }).then(async (res) => {
            if (res.index === 1) {
              await CollectionManager.clearCollection(getContext(this), this.bookId);
              this.words = [];
              this.wordIds = [];
              promptAction.showToast({ message: '收藏词已清空' });
            }
          })
        })
    }
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => { router.back() })
        Text(this.bookName).fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 15 })
        Blank()
        Image($r('app.media.ic_settings')).width(24).height(24).bindMenu(this.SettingsMenu)
      }.width('100%').padding(20).backgroundColor(Color.White)

      if (this.isLoading) {
        LoadingProgress().width(50).height(50).color('#4CAF50').margin({ top: 100 })
      } else if (this.words.length === 0) {
        Text('收藏夹是空的哦').fontSize(16).fontColor('#999').margin({ top: 100 })
      } else {
        List({ space: 10 }) {
          ForEach(this.words, (word: WordEntry) => {
            ListItem() {
              Row() {
                Text(word.headWord).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333').width('40%')

                // 🌟 核心：高级的淡灰色方块遮挡效果
                if (this.isMasked) {
                  Row()
                    .layoutWeight(1)
                    .height(20)
                    .backgroundColor('#EEEEEE') // 柔和的淡灰色
                    .borderRadius(4)
                } else {
                  Text(word.content.word.content.trans ? word.content.word.content.trans[0].tranCn : '')
                    .fontSize(14).fontColor('#666').layoutWeight(1).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }

              }.width('100%').padding(15).backgroundColor(Color.White).borderRadius(10)
            }
          })
        }.width('90%').layoutWeight(1).margin({ top: 15, bottom: 15 })

        Button('开始学习收藏单词')
          .width('90%').height(50).backgroundColor('#4CAF50').fontSize(18).margin({ bottom: 30 })
          .onClick(() => {
            router.pushUrl({
              url: 'pages/LearningSessionPage',
              params: { mode: 'collection', bookId: this.bookId, bookName: this.bookName, wordIds: this.wordIds }
            })
          })
      }
    }.width('100%').height('100%').backgroundColor('#F5F5F5')
  }
}