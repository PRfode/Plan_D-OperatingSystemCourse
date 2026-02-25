// SettingsPage.ets
import { eventService } from '../services/EventService';
import promptAction from '@ohos.promptAction';

@Component
export struct SettingsPage {
  // 自动保存开关状态（从 EventService 实时读取）
  @State private autoSaveOn: boolean = eventService.getAutoSave();

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .padding(16)
      }
      .width('100%')
      .backgroundColor('#FFFFFF')

      // 设置主列表
      List({ space: 8 }) {
        // 事件分类
        ListItemGroup({ header: this.GroupHeader('事件') }) {
          ListItem() { this.ClearAllEventsItem() }
        }

        // 通用分类
        ListItemGroup({ header: this.GroupHeader('通用') }) {
          ListItem() { this.AutoSaveToggleItem() }
        }
      }
      .width('100%')
      .height('100%')
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  /* ======================== Builder 函数 ======================== */

  // 分组标题
  @Builder
  GroupHeader(title: string) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor('#FFF')
    }
    .width('100%')
    .height(36)
    .backgroundColor('#AAAAAA')
    .justifyContent(FlexAlign.Center)
  }

  // 删除所有点事件
  @Builder
  ClearAllEventsItem() {
    Row() {
      Text('删除所有点事件')
        .fontSize(16)
        .layoutWeight(1)

      Image($r('app.media.ic_delete'))
        .width(24)
        .height(24)
        .fillColor('#FF6B6B')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .onClick(() => this.confirmClearAll())
  }

  // 自动保存开关
  @Builder
  AutoSaveToggleItem() {
    Row() {
      Text('自动保存')
        .fontSize(16)
        .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn: this.autoSaveOn })
        .onChange((isOn: boolean) => {
          // EventService 内部已暴露 setAutoSave 方法（见下方补充）
          eventService.setAutoSave(isOn);
          this.autoSaveOn = isOn;
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  /* ======================== 业务逻辑 ======================== */

  // 二次确认后清空事件
  private async confirmClearAll() {
    try {
      const res = await this.getUIContext().getPromptAction().showDialog({
        title: '？你确定吗？',
        message: '确定清空所有点事件？此操作不可恢复。',
        buttons: [
          { text: '取消', color: '#666666' },
          { text: '确定', color: '#FF0000' }
        ],
        alignment: DialogAlignment.Center
      });
      if (res.index === 1) {
        eventService.deprecateAllEvent(); // 调用 EventService 已实现的清空方法
        this.getUIContext().getPromptAction().showToast({ message: '已清空', duration: 2000 });
      }
    } catch (e) {}
  }
}