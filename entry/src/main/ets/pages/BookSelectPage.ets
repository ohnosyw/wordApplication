// entry/src/main/ets/pages/BookSelectPage.ets
import router from '@ohos.router'
import promptAction from '@ohos.promptAction'
import { PlanData } from '../model/StudyPlan'
import { UserManager, UserInfo } from '../utils/UserManager';

// 定义列表项中每一本词书需要的展示信息
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

  private books: BookInfo[] = [
    {
      id: 'cet4',
      name: '四级必背词汇',
      description: '大学英语四级考试大纲词汇',
      totalWords: 3739,
      level: '基础',
      color: '#7EAC8A'
    },
    {
      id: 'cet6',
      name: '六级必背词汇',
      description: '大学英语六级考试大纲词汇',
      totalWords: 2078,
      level: '进阶',
      color: '#D1A075'
    },
    {
      id: 'kaoyan',
      name: '考研词汇',
      description: '全国硕士研究生入学考试词汇',
      totalWords: 4533,
      level: '高阶',
      color: '#CB8585'
    },
    {
      id: 'junior_high',
      name: '初中英语词汇',
      description: '义务教育初中英语大纲词汇',
      totalWords: 1420,
      level: '入门',
      color: '#A2B889'
    },
    {
      id: 'high_school',
      name: '高中英语词汇',
      description: '普通高中英语新课标大纲词汇',
      totalWords: 3668,
      level: '基础',
      color: '#829DBF'
    },
    {
      id: 'ielts',
      name: '雅思核心词汇',
      description: '雅思(IELTS)考试高频核心词汇',
      totalWords: 3427,
      level: '高阶',
      color: '#A68CB2'
    },
    {
      id: 'sat',
      name: 'SAT核心词汇',
      description: '美国大学入学考试(SAT)必备词汇',
      totalWords: 4423,
      level: '专家',
      color: '#7B88B5'
    },
    {
      id: 'gmat',
      name: 'GMAT核心词汇',
      description: '经企管理研究生入学考试词汇',
      totalWords: 3254,
      level: '专家',
      color: '#7AAEB5'
    },
    {
      id: 'test_book',
      name: 'test_book',
      description: '测试词书1',
      totalWords: 5,
      level: '基础',
      color: '#9CA3AF'
    },
    {
      id: 'test_book222',
      name: 'test_book2',
      description: '测试词书2',
      totalWords: 7,
      level: '基础',
      color: '#9CA3AF'
    }
  ]

  // 组件即将出现时触发
  aboutToAppear() {
    // 从全局内存 AppStorage 中拉取当前的用户的学习计划
    let currentPlan = AppStorage.get<PlanData>('studyPlan');
    if (currentPlan) {
      this.selectedBookId = currentPlan.bookId;
    }
  }

  // 页面主结构
  build() {
    Column() {
      // 标题栏
      Row() {
        Image($r('app.media.ic_back'))
          .width(24)
          .height(24)
          .margin({ left: 20 })
          .onClick(() => {
            router.back()
          })

        Text('选择词书')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333')
          .margin({ left: 16 })

        Blank()
      }
      .width('100%')
      .height(60)
      .backgroundColor(Color.White)

      // 词书列表
      List() {
        ForEach(this.books, (book: BookInfo) => {
          ListItem() {
            this.createBookRow(book)
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(Color.White)
      .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 84, endMargin: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }

  // 渲染单个词书卡片的 UI 模块
  @Builder
  createBookRow(book: BookInfo) {
    Row() {
      if (book.icon) {
        Image(book.icon)
          .width(48)
          .height(48)
          .borderRadius(8)
          .margin({ right: 16 })
      } else {
        // 颜色块图标
        Column() {
          Text(book.name.substring(0, 2))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .width(48)
        .height(48)
        .backgroundColor(book.color)
        .borderRadius(8)
        .margin({ right: 16 })
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }

      // 词书信息
      Column() {
        Row() {
          Text(book.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333')

          Blank()

          // 只有当前书的 ID 等于选中的 ID，才渲染这个高级灰标签
          if (this.selectedBookId === book.id) {
            Text('学习中')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#666666')
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#E6E6E6')
              .borderRadius(4)
              .margin({ right: 8 })
          }

          // 难度标签
          Text(book.level)
            .fontSize(11)
            .fontColor(Color.White)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(book.color)
            .borderRadius(4)
        }
        .width('100%')

        Row() {
          Text(book.description)
            .fontSize(13)
            .fontColor('#999')

          Blank()

          Text(book.totalWords + '词')
            .fontSize(13)
            .fontColor('#999')
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 18, bottom: 18 })
    .backgroundColor(Color.White)
    .onClick(() => {
      // 点击整行触发词书切换逻辑
      this.selectBook(book)
    })
  }

  // 处理词书的选中与切换
  async selectBook(book: BookInfo) {
    let currentUser = AppStorage.get<UserInfo>('currentUser');
    if (!currentUser) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    this.selectedBookId = book.id;
    let currentPlan = AppStorage.get<PlanData>('studyPlan');

    // 构建新的学习计划
    let updatedPlan: PlanData = {
      dailyNew: currentPlan ? currentPlan.dailyNew : 20,
      dailyReview: currentPlan ? currentPlan.dailyReview : 50,
      studyMode: currentPlan ? currentPlan.studyMode : 0,
      bookId: book.id,
      bookName: book.name,
      totalWords: book.totalWords
    };

    // 数据同步与持久化
    AppStorage.setOrCreate('studyPlan', updatedPlan);
    await UserManager.saveUserPlan(getContext(this), currentUser.userId, updatedPlan);

    // 交互反馈
    promptAction.showToast({ message: '已选择: ' + book.name, duration: 1500 });
    setTimeout(() => { router.back() }, 500);
  }
}