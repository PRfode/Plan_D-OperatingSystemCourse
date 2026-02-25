// Index.ets
// 感谢 https://github.com/siemens/ix-icons 提供的 Siemens Industrial Experience Icons 资源
import { InspirationPage } from './InspiringPage'
import { CalendarPage } from './CalendarPage'
import { EventManagerPage } from './EventManagerPage'
import { SchedulePage } from './SchedulePage'
import { SettingsPage } from './SettingsPage'

// 明确定义接口
interface TabBarItem {
  index: number;
  title: string;
  icon: Resource;
  page: object; // 使用object代替any
}

@Entry
@Component
struct Index {
  @State currentIndex: number = 2; // 默认选中管理事件视图（索引2）

  // 明确指定数组类型
  private tabBars: TabBarItem[] = [
    {
      index: 0,
      title: '灵感',
      icon: $r('app.media.ic_inspiration'),
      page: InspirationPage
    },
    {
      index: 1,
      title: '总览',
      icon: $r('app.media.ic_calendar'),
      page: CalendarPage
    },
    {
      index: 2,
      title: '事件',
      icon: $r('app.media.ic_event'),
      page: EventManagerPage
    },
    {
      index: 3,
      title: '排期',
      icon: $r('app.media.ic_schedule'),
      page: SchedulePage
    },
    {
      index: 4,
      title: '设置',
      icon: $r('app.media.ic_settings'),
      page: SettingsPage
    }
  ];

  build() {
    Column() {
      // 内容区域 - 使用条件渲染代替函数调用
      Column() {
        if (this.currentIndex === 0) {
          InspirationPage();
        } else if (this.currentIndex === 1) {
          CalendarPage();
        } else if (this.currentIndex === 2) {
          EventManagerPage();
        } else if (this.currentIndex === 3) {
          SchedulePage();
        } else if (this.currentIndex === 4) {
          SettingsPage();
        }
      }
      .layoutWeight(1) // 占据剩余空间
      .width('100%')

      // 底部导航栏
      this.buildNavigationBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5') // 浅灰色背景
  }

  @Builder
  buildNavigationBar() {
    Row() {
      ForEach(this.tabBars, (item: TabBarItem) => {
        Column() {
          // 图标
          Image(item.icon)
            .width(36)
            .height(36)
            .fillColor(this.currentIndex === item.index ? '#007DFF' : '#666666')
            .margin({ bottom: 4 })

          // 文字
          Text(item.title)
            .fontSize(12)
            .fontColor(this.currentIndex === item.index ? '#007DFF' : '#666666')
            .fontWeight(this.currentIndex === item.index ? FontWeight.Medium : FontWeight.Normal)
        }
        .width('20%')
        .height(64)
        .padding({ top: 8 })
        .justifyContent(FlexAlign.Center)
        // .backgroundColor('#FFFFFF') // 导航栏背景色比页面稍白
        .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0 })
        .onClick(() => {
          this.currentIndex = item.index;
        })
      })
    }
    .width('100%')
    .height(64)
    .backgroundColor('#FFFFFF')
    .shadow({ radius: 16, color: '#1A000000', offsetX: 0, offsetY: 0 })
    .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 0, bottomRight: 0 })
  }
}
