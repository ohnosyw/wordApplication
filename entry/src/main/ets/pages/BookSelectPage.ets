// entry/src/main/ets/pages/BookSelectPage.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { PlanData } from '../model/StudyPlan'
import { UserManager, UserInfo } from '../utils/UserManager';

// 定义词书接口
interface BookInfo {
  id: string
  name: string
  description: string
  totalWords: number
  icon?: Resource
  level: string
  color: string
}

@Entry
@Component
struct BookSelectPage {
  @State selectedBookId: string = ''
  // 词书数据
  private books: BookInfo[] = [
    {
      id: 'cet4',
      name: '四级必背词汇',
      description: '大学英语四级考试大纲词汇',
      totalWords: 3739,
      level: '基础',
      color: '#4CAF50'
    },
    {
      id: 'cet6',
      name: '六级必背词汇',
      description: '大学英语六级考试大纲词汇',
      totalWords: 2078,
      level: '进阶',
      color: '#FF9800'
    },
    {
      id: 'kaoyan',
      name: '考研词汇',
      description: '全国硕士研究生入学考试词汇',
      totalWords: 4533,
      level: '高阶',
      color: '#F44336'
    },
    // 以下为你新增的词书模块
    {
      id: 'junior_high',
      name: '初中英语词汇',
      description: '义务教育初中英语大纲词汇',
      totalWords: 1420,
      level: '入门',
      color: '#8BC34A' // 浅绿色，代表启蒙与生机
    },
    {
      id: 'high_school',
      name: '高中英语词汇',
      description: '普通高中英语新课标大纲词汇',
      totalWords: 3668,
      level: '基础',
      color: '#2196F3' // 蓝色，代表沉稳与理智
    },
    {
      id: 'ielts',
      name: '雅思核心词汇',
      description: '雅思(IELTS)考试高频核心词汇',
      totalWords: 3427,
      level: '高阶',
      color: '#9C27B0' // 紫色，代表雅思考试的经典色调
    },
    {
      id: 'sat',
      name: 'SAT核心词汇',
      description: '美国大学入学考试(SAT)必备词汇',
      totalWords: 4423,
      level: '专家',
      color: '#3F51B5' // 靛蓝色，代表学术与深度
    },
    {
      id: 'gmat',
      name: 'GMAT核心词汇',
      description: '经企管理研究生入学考试词汇',
      totalWords: 3254,
      level: '专家',
      color: '#00BCD4' // 青色，代表商业逻辑与清晰严谨
    }
  ]

  aboutToAppear() {
    // 页面加载时，读取当前的计划，让正在背的词书处于选中高亮状态
    let currentPlan = AppStorage.get<PlanData>('studyPlan');
    if (currentPlan) {
      this.selectedBookId = currentPlan.bookId;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .margin({ left: 16 })
          .onClick(() => {
            router.back()
          })

        Text('选择词书')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })

        Blank()
      }
      .width('100%')
      .height(56)
      .backgroundColor(Color.White)

      // 词书列表
      Scroll() {
        Column() {
          // 词书卡片列表 - 一行一个
          Column() {
            ForEach(this.books, (book: BookInfo) => {
              this.createBookRow(book)
            })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 16 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .backgroundColor('#F5F5F5')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  createBookRow(book: BookInfo) {
    Column() {
      Row() {
        if (book.icon) {
          Image(book.icon)
            .width(50)
            .height(50)
            .borderRadius(10)
            .margin({ right: 16 })
        } else {
          // 使用颜色块作为默认图标
          Column() {
            Text(book.name.substring(0, 2))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          }
          .width(50)
          .height(50)
          .backgroundColor(book.color)
          .borderRadius(10)
          .margin({ right: 16 })
          .alignItems(HorizontalAlign.Center)
          .justifyContent(FlexAlign.Center)
        }

        // 词书信息 - 占据剩余空间
        Column() {
          Row() {
            Text(book.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')

            Blank()

            // 难度标签
            Text(book.level)
              .fontSize(12)
              .fontColor(Color.White)
              .padding({
                left: 8,
                right: 8,
                top: 2,
                bottom: 2
              })
              .backgroundColor(book.color)
              .borderRadius(10)
          }
          .width('100%')

          Row() {
            Text(book.description)
              .fontSize(14)
              .fontColor('#666')

            Blank()

            Text(book.totalWords + '词')
              .fontSize(14)
              .fontColor('#999')
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(Color.White)
      .borderRadius(12)
      .border({
        width: this.selectedBookId === book.id ? 2 : 0,
        color: book.color
      })
      .onClick(() => {
        this.selectBook(book)
      })
    }
    .width('90%')
    .margin({ bottom: 12 })
  }

  // 核心：选书并保存到当前用户
  async selectBook(book: BookInfo) {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    this.selectedBookId = book.id;
    let currentPlan = AppStorage.get<PlanData>('studyPlan');

    // 💡 修复点：避免使用 ArkTS 不支持的 ... 展开运算符，手动赋值生成新对象
    let updatedPlan: PlanData = {
      dailyNew: currentPlan ? currentPlan.dailyNew : 20,
      dailyReview: currentPlan ? currentPlan.dailyReview : 50,
      studyMode: currentPlan ? currentPlan.studyMode : 0,
      bookId: book.id,
      bookName: book.name,
      totalWords: book.totalWords
    };

    // 1. 更新内存，触发 UI 刷新
    AppStorage.setOrCreate('studyPlan', updatedPlan);

    // 2. 写入当前用户的硬盘数据库
    await UserManager.saveUserPlan(getContext(this), currentUser.userId, updatedPlan);

    promptAction.showToast({ message: '已选择: ' + book.name, duration: 1500 });
    setTimeout(() => { router.back() }, 500);
  }
}