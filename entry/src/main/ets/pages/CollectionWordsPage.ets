// entry/src/main/ets/pages/CollectionWordsPage.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { DataLoader } from '../utils/DataLoader'
import { WordEntry, TransItem, SentenceItem } from '../model/WordModel'
import { CollectionManager } from '../utils/CollectionManager'

// 单次任务量设置弹窗
@CustomDialog
struct LimitSettingDialog {
  controller: CustomDialogController
  currentLimit: number = 20
  onConfirm: (limit: number) => void = () => {}

  private options: string[] = ['10', '20', '30', '50', '100', '全部']
  private limits: number[] = [10, 20, 30, 50, 100, 9999]
  @State selectedIndex: number = 1

  aboutToAppear() {
    let idx = this.limits.indexOf(this.currentLimit);
    this.selectedIndex = idx >= 0 ? idx : 1;
  }

  build() {
    Column() {
      Image($r('app.media.ic_duck'))
        .width(80).height(80)
        .margin({ top: -40, bottom: 10 })

      Text('设置单次特训量')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333').margin({ bottom: 10 })

      Text('每日温故知新，定个小目标吧鸭！')
        .fontSize(13).fontColor('#999').margin({ bottom: 20 })

      TextPicker({ range: this.options, selected: this.selectedIndex })
        .canLoop(false)
        .textStyle({ color: '#999', font: { size: 16 } })
        .selectedTextStyle({ color: '#FF9800', font: { size: 20, weight: FontWeight.Bold } })
        .onChange((value: string | string[], index: number | number[]) => {
          this.selectedIndex = typeof index === 'number' ? index : index[0];
        })
        .width('100%').height(140).margin({ bottom: 25 })

      Button('确认设置')
        .width('100%').height(45).backgroundColor('#FFCA28').fontColor('#333')
        .margin({ bottom: 12 })
        .onClick(() => {
          this.onConfirm(this.limits[this.selectedIndex])
          this.controller.close()
        })

      Button('取消')
        .width('100%').height(45).backgroundColor('#F7F7F7').fontColor('#999')
        .border({ width: 1, color: '#DDD' })
        .onClick(() => {
          this.controller.close()
        })
    }
    .width('85%')
    .padding({ left: 25, right: 25, top: 20, bottom: 25 })
    .borderRadius(20)
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 1.0]]
    })
    .shadow({ radius: 30, color: '#33000000', offsetX: 0, offsetY: 10 })
  }
}

// 一键清空收藏词弹窗
@CustomDialog
struct ClearCollectionDialog {
  controller: CustomDialogController
  onConfirm: () => void = () => {}

  build() {
    Column() {
      Image($r('app.media.ic_duck_sleep'))
        .width(90).height(90).margin({ top: -45, bottom: 10 })

      Text('一键清空')
        .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#333').margin({ bottom: 12 })

      Text('确定要清空本词书的所有收藏词吗？清空后将无法恢复哦鸭！')
        .fontSize(14).fontColor('#666').textAlign(TextAlign.Center).lineHeight(20)
        .padding({ left: 10, right: 10 }).margin({ bottom: 25 })

      Button('确认清空')
        .width('100%').height(45).backgroundColor('#F7F7F7').fontColor('#F44336')
        .border({ width: 1, color: '#F44336' }).margin({ bottom: 12 })
        .onClick(() => {
          this.onConfirm()
          this.controller.close()
        })

      Button('手滑了，留下来')
        .width('100%').height(45).backgroundColor('#FFCA28').fontColor('#333')
        .onClick(() => { this.controller.close() })
    }
    .width('85%').padding(20).borderRadius(20)
    .linearGradient({ direction: GradientDirection.Bottom, colors: [['#FFFDE7', 0.0], ['#FFF9C4', 1.0]] })
    .shadow({ radius: 30, color: '#33000000', offsetX: 0, offsetY: 10 })
  }
}

// 精美的单词详情弹窗
@CustomDialog
struct WordDetailDialog {
  controller: CustomDialogController
  word: WordEntry | null = null

  build() {
    Column() {
      if (this.word) {
        Row() {
          Blank()
          Image($r('app.media.ic_duck')).width(30).height(30).margin({ right: 10 })
          Text('✖').fontSize(20).fontColor('#999').onClick(() => { this.controller.close() })
        }.width('100%').margin({ bottom: 10 })

        Scroll() {
          Column() {
            Text(this.word.headWord).fontSize(36).fontWeight(FontWeight.Bold).fontColor('#333').margin({ bottom: 5 })
            if (this.word.content.word.content.usphone) {
              Text(`美 [${this.word.content.word.content.usphone}]`).fontSize(15).fontColor('#999').margin({ bottom: 20 })
            }

            if (this.word.content.word.content.trans && this.word.content.word.content.trans.length > 0) {
              Column() {
                ForEach(this.word.content.word.content.trans, (tran: TransItem) => {
                  Row() {
                    Text(tran.pos + ".").fontSize(15).fontColor('#FF9800').fontWeight(FontWeight.Bold).margin({ right: 8 })
                    Text(tran.tranCn).fontSize(15).fontColor('#333').layoutWeight(1)
                  }.width('100%').margin({ bottom: 6 }).alignItems(VerticalAlign.Top)
                })
              }.padding(15).backgroundColor('#F7F7F7').borderRadius(12).width('100%').margin({ bottom: 20 })
            }

            if (this.word.content.word.content.sentence && this.word.content.word.content.sentence.sentences.length > 0) {
              Column() {
                Text('语境例句').fontSize(13).fontColor('#999').width('100%').margin({ bottom: 10 })
                ForEach(this.word.content.word.content.sentence.sentences, (sen: SentenceItem) => {
                  Column() {
                    Text(sen.sContent).fontSize(15).fontColor('#333').fontWeight(FontWeight.Medium).width('100%').margin({ bottom: 4 })
                    Text(sen.sCn).fontSize(13).fontColor('#999').width('100%')
                  }.margin({ bottom: 12 })
                })
              }.width('100%')
            }
          }.width('100%').alignItems(HorizontalAlign.Start)
        }.layoutWeight(1)
      }
    }
    .width('90%').height('70%').padding(25).borderRadius(20).backgroundColor(Color.White)
    .shadow({ radius: 30, color: '#33000000', offsetX: 0, offsetY: 10 })
  }
}

@Entry
@Component
struct CollectionWordsPage {
  @State bookId: string = '';
  @State bookName: string = '';
  @State wordIds: string[] = [];
  @State words: WordEntry[] = [];
  @State isLoading: boolean = true;

  @State isMasked: boolean = false;// 是否开启“遮挡释义”模式
  @State dailyLimit: number = 20;// 单次特训上限

  @State isEditMode: boolean = false;// 是否处于“管理模式”
  @State selectedWordIds: string[] = [];// 当前勾选准备删除的单词 ID

  @State currentSelectedWord: WordEntry | null = null;// 用于传递给详情弹窗的数据源

  // 声明弹窗控制器
  detailDialogController: CustomDialogController = new CustomDialogController({
    builder: WordDetailDialog({ word: this.currentSelectedWord }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  limitDialogController: CustomDialogController = new CustomDialogController({
    builder: LimitSettingDialog({
      currentLimit: this.dailyLimit,
      onConfirm: async (limit: number) => {
        this.dailyLimit = limit;
        await CollectionManager.setDailyLimit(getContext(this), this.bookId, limit);
        promptAction.showToast({ message: `单次特训量已设置为 ${limit === 9999 ? '全部' : limit}` });
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  clearDialogController: CustomDialogController = new CustomDialogController({
    builder: ClearCollectionDialog({
      onConfirm: async () => {
        await CollectionManager.clearCollection(getContext(this), this.bookId);
        this.words = [];
        this.wordIds = [];
        this.isEditMode = false;
        promptAction.showToast({ message: '收藏词已全部清空' });
      }
    }),
    autoCancel: true,
    customStyle: true,
    alignment: DialogAlignment.Center
  })

  // 页面回到前台时重新加载数据
  async onPageShow() {
    await this.loadData();
  }

  // 核心数据装载逻辑
  async loadData() {
    this.isLoading = true;
    let params = router.getParams() as Record<string, string | string[]>;
    if (params) {
      this.bookId = params['bookId'] as string;
      this.bookName = params['bookName'] as string;

      let cols = await CollectionManager.getCollections(getContext(this));

      // 如果这本书有收藏 → 取出收藏的单词ID数组 & 每日学习限制
      if (cols[this.bookId]) {
        this.wordIds = cols[this.bookId].wordIds;
        this.dailyLimit = cols[this.bookId].dailyLimit || 20;
      }

      let allWords = await DataLoader.loadWordBook(getContext(this), `${this.bookId}.json`);
      // 只保留“被收藏”的单词
      this.words = allWords.filter(w => this.wordIds.includes(w.content.word.wordId));
    }
    this.isLoading = false;
  }

  // 批量移除选中的单词
  async removeSelectedWords() {
    if (this.selectedWordIds.length === 0) return;

    this.isLoading = true;

    // 遍历所有选中的单词，逐个取消收藏
    for (let wid of this.selectedWordIds) {
      await CollectionManager.toggleCollection(getContext(this), this.bookId, this.bookName, wid);
    }
    promptAction.showToast({ message: `成功移除 ${this.selectedWordIds.length} 个单词` });

    this.isEditMode = false;
    this.selectedWordIds = [];
    await this.loadData();
  }

  // 设置菜单面板
  @Builder SettingsMenu() {
    Menu() {
      MenuItem({ content: '移除单词' })
        .onClick(() => {
          this.isEditMode = true;
          this.selectedWordIds = [];
        })

      MenuItem({ content: `设置单次任务量 (当前: ${this.dailyLimit === 9999 ? '全部' : this.dailyLimit})` })
        .onClick(() => { this.limitDialogController.open() })

      MenuItem({ content: this.isMasked ? '取消遮挡释义' : '遮挡释义' })
        .onClick(() => { this.isMasked = !this.isMasked; })

      MenuItem({ content: '一键清空收藏词' })
        .onClick(() => { this.clearDialogController.open() })
    }
  }

  build() {
    Column() {
      // 动态顶部栏
      Row() {
        Image($r('app.media.ic_back')).width(24).height(24).onClick(() => {
          if (this.isEditMode) {
            this.isEditMode = false;
          } else {
            router.back()
          }
        })

        Text(this.isEditMode ? '选择移除的单词' : this.bookName)
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#333').margin({ left: 15 })

        Blank()

        if (this.isEditMode) {
          Text('全选').fontSize(16).fontColor('#FF9800').margin({ right: 15 })
            .onClick(() => {
              if (this.selectedWordIds.length === this.words.length) {
                this.selectedWordIds = [];
              } else {
                this.selectedWordIds = this.words.map(w => w.content.word.wordId);
              }
            })
          Text('取消').fontSize(16).fontColor('#999')
            .onClick(() => { this.isEditMode = false; })
        } else {
          Image($r('app.media.ic_settings')).width(24).height(24).bindMenu(this.SettingsMenu)
        }
      }.width('100%').padding({ left: 20, right: 20, top: 20, bottom: 10 })

      // 状态渲染
      if (this.isLoading) {
        Column() {
          LoadingProgress().width(50).height(50).color('#FFCA28')
          Text('正在加载收藏鸭...').fontSize(14).fontColor('#999').margin({ top: 10 })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.words.length === 0) {
        Column() {
          Image($r('app.media.ic_duck_sleep')).width(100).height(100).opacity(0.6).margin({ bottom: 20 })
          Text('收藏夹是空的哦').fontSize(16).fontColor('#999')
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        // 单词列表视图
        List({ space: 12 }) {
          ForEach(this.words, (word: WordEntry) => {
            ListItem() {
              Row() {
                if (this.isEditMode) {
                  Row() {
                    if (this.selectedWordIds.includes(word.content.word.wordId)) {
                      Text('✓').fontSize(14).fontColor('#666666').fontWeight(FontWeight.Bold)
                    }
                  }
                  .width(22).height(22)
                  .backgroundColor(this.selectedWordIds.includes(word.content.word.wordId) ? '#D4D4D4' : '#EAEAEA')
                  .borderRadius(11)
                  .justifyContent(FlexAlign.Center)
                  .margin({ right: 12 })
                }

                Text(word.headWord).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#333').width(this.isEditMode ? '35%' : '40%')

                Column() {
                  if (this.isMasked && !this.isEditMode) {
                    Row().width('100%').height(20).backgroundColor('#EAEAEA').borderRadius(6)
                  } else {
                    Text(word.content.word.content.trans ? word.content.word.content.trans[0].tranCn : '')
                      .fontSize(14).fontColor('#666').width('100%')
                      .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Start)
                  }
                }.layoutWeight(1).padding({ left: 15 })
              }
              .width('100%').padding(18)
              .backgroundColor('#F7F7F7').borderRadius(15)
              .shadow({ radius: 8, color: '#0A000000', offsetX: 0, offsetY: 4 })
            }
            .onClick(() => {
              if (this.isEditMode) {
                // 如果是管理模式：点击则反转该单词的勾选状态
                let wid = word.content.word.wordId;
                if (this.selectedWordIds.includes(wid)) {
                  this.selectedWordIds = this.selectedWordIds.filter(id => id !== wid);
                } else {
                  this.selectedWordIds.push(wid);
                }
              } else {
                // 如果是正常模式：点击呼出单词详情弹窗
                this.currentSelectedWord = word;
                this.detailDialogController.open();
              }
            })
          })
        }.width('90%').layoutWeight(1).margin({ top: 10, bottom: 15 })

        // 底部按钮
        if (this.isEditMode) {
          Button(`移除选中 (${this.selectedWordIds.length})`)
            .width('90%').height(50).fontSize(18).fontWeight(FontWeight.Medium).margin({ bottom: 30 })
            .backgroundColor(this.selectedWordIds.length > 0 ? '#FFF8E1' : '#F5F5F5')
            .fontColor(this.selectedWordIds.length > 0 ? '#FF9800' : '#CCC')
            .onClick(() => { this.removeSelectedWords() })
        } else {
          Button('开始复习')
            .width('90%').height(50).backgroundColor('#FFCA28').fontColor('#333').fontSize(18).fontWeight(FontWeight.Medium).margin({ bottom: 30 })
            .onClick(() => {
              router.pushUrl({
                url: 'pages/LearningSessionPage',
                params: { mode: 'collection', bookId: this.bookId, bookName: this.bookName, wordIds: this.wordIds }
              })
            })
        }
      }
    }
    .width('100%').height('100%')
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#FFFDE7', 0.0], ['#FFF9C4', 0.3], ['#F5F5F5', 1.0]]
    })
  }
}