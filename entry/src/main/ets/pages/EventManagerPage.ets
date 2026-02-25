// EventManagement.ets
import { eventService, PointEvent, copyPointEvent } from '../services/EventService';
import { FabButton } from '../components/FabButton'
import emitter from '@ohos.events.emitter';
import promptAction from '@ohos.promptAction';
import { BusinessError } from '@ohos.base';
// import

// TO(solved)DO: 更改事件后显示的内容无法刷新
// TODO: 剩余时间多少时弹窗提醒
// TODO 删除事件不工作

@Component
export struct EventManagerPage {

  private readonly EMPTY_EVENT: PointEvent = {
    id: '',
    title: '',
    description: '',
    deadline: -1,
    isDone: false,
    createdAt: -1,
    finishedAt: -1
  };

  private readonly MAX_TITLE_LEN: number = 30;
  private readonly MAX_DESCRIPTION_LEN: number = 1000;

  @State currentIndex: number = 1;
  @State pendingPointEvents: PointEvent[] = [];
  @State outdatedPointEvents: PointEvent[] = [];
  @State update: boolean= true; // 搭配 toggleUpdate 用于提示ui PointEvent 已更新

  @State newEventDescription: string = '';
  @State newEventDeadline: string = '';

  /* ===== 折叠状态 ===== */
  @State pendingFolded: boolean = false;
  @State outdatedFolded: boolean = true;

  /* ===== 编辑弹窗状态 ===== */
  @State isEventAdding: boolean = false;              // 是否正在新建
  @State editingEvent: PointEvent = this.EMPTY_EVENT; // 当前编辑的事件副本
  @State isEventEditing: boolean = false;

  /* ===== 动画参数 ===== */
  @State isInwardAnimation: boolean = false; // 播放 渐入/渐出 动画
  @State editorYOffset: number = 0;

  toggleUpdate(): void {
    this.update = !this.update
  }

  aboutToAppear(): void {
    this.loadPointEvents();
    this.registerEmitter();
  }

  aboutToDisappear(): void {
    this.unregisterEmitter();
  }

  loadPointEvents(): void {
    this.pendingPointEvents = eventService.getPendingEvents();
    this.outdatedPointEvents = eventService.getOutDatedEvent();
  }

  registerEmitter(): void {
    const innerEvent: emitter.InnerEvent = {
      eventId: 1
    };

    emitter.on(innerEvent, (eventData: emitter.EventData) => {
      console.info('####### [INFO] ManagerPage: Point events changed, reloading...');
      this.loadPointEvents();
      this.toggleUpdate();
    });
  }

  unregisterEmitter(): void {
    emitter.off(1);
  }

  switchPage(index: number): void {
    this.currentIndex = index;
  }

  onPageChange(index: number): void {
    this.currentIndex = index;
  }

  toggleEventDone(event: PointEvent): void {
    eventService.toggleDone(event.id);
  }

  // 检查是否过期的辅助方法
  isEventOverdue(event: PointEvent): boolean {
    return event.deadline < Date.now() && !event.isDone;
  }

  formatDate(timestamp: number): string {
    const date = new Date(timestamp);
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const eventDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());

    const diffTime = eventDate.getTime() - today.getTime();
    const diffDays = Math.round(diffTime / (1000 * 60 * 60 * 24)); // round 防夏令时

    /* ===== 日期部分 ===== */
    let dateStr: string;
    // if (diffDays === 0 || ) dateStr = '今天';
    if (diffDays === 0) dateStr = '今天';
    else if (diffDays === -1) dateStr = '昨天';
    else if (diffDays === -2) dateStr = '前天';
    else if (diffDays === 1) dateStr = '明天';
    else if (diffDays === 2) dateStr = '后天';
    else if (date.getFullYear() === now.getFullYear()) {
      // 今年 → MM/DD
      const MM = (date.getMonth() + 1).toString().padStart(2, '0');
      const DD = date.getDate().toString().padStart(2, '0');
      dateStr = `${MM}/${DD}`;
    } else {
      // 非今年 → YYYY/MM/DD
      const YYYY = date.getFullYear();
      const MM = (date.getMonth() + 1).toString().padStart(2, '0');
      const DD = date.getDate().toString().padStart(2, '0');
      dateStr = `${YYYY}/${MM}/${DD}`;
    }

    /* ===== 时间部分 ===== */
    const hh = date.getHours().toString().padStart(2, '0');
    const mm = date.getMinutes().toString().padStart(2, '0');
    const timeStr = `${hh}:${mm}`;

    return `${dateStr} ${timeStr}`;
  }

  build() {
    Stack() {
      Column() {
        // 顶部切换按钮
        Row() {
          Button('事段')
            .fontSize(16)
            .fontWeight(this.currentIndex === 0 ? FontWeight.Bold : FontWeight.Normal)
            .backgroundColor(this.currentIndex === 0 ? '#007DFF' : '#F1F3F5')
            .fontColor(this.currentIndex === 0 ? '#FFFFFF' : '#000000')
            .borderRadius(20)
            .width('25%')
            .onClick(() => this.switchPage(0))

          Button('事件')
            .fontSize(16)
            .fontWeight(this.currentIndex === 1 ? FontWeight.Bold : FontWeight.Normal)
            .backgroundColor(this.currentIndex === 1 ? '#007DFF' : '#F1F3F5')
            .fontColor(this.currentIndex === 1 ? '#FFFFFF' : '#000000')
            .borderRadius(20)
            .width('25%')
            .margin({ left: 8, right: 8 })
            .onClick(() => this.switchPage(1))

          Button('象限')
            .fontSize(16)
            .fontWeight(this.currentIndex === 2 ? FontWeight.Bold : FontWeight.Normal)
            .backgroundColor(this.currentIndex === 2 ? '#007DFF' : '#F1F3F5')
            .fontColor(this.currentIndex === 2 ? '#FFFFFF' : '#000000')
            .borderRadius(20)
            .width('25%')
            .onClick(() => this.switchPage(2))
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')

        // 页面内容区域
        Swiper() {
          // 段事件子页面
          Column() {
            Text('段事件页面')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 20 })

            Text('段事件功能开发中...')
              .fontSize(16)
              .fontColor('#666666')
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')

          // 点事件子页面
          Stack() {
            Column() {
              // 点事件列表
              List({ space: 8 }) {
                ListItemGroup({
                  header: this.GroupHeader('未完成', () => {
                    this.pendingFolded = !this.pendingFolded;
                  })
                }) {
                  if (!this.pendingFolded) {
                    ForEach(this.pendingPointEvents, (event: PointEvent) => {
                      ListItem() {
                        this.PointEventItem(event)
                      }
                      .padding(4)
                    }, (event: PointEvent) => `${event.id}-${event.title}-${event.description}-${event.deadline}`)
                  }
                }
                .width('100%')

                ListItemGroup({
                  header: this.GroupHeader('已完成', () => {
                    this.outdatedFolded = !this.outdatedFolded;
                  })
                }) {
                  if (!this.outdatedFolded) {
                    ForEach(this.outdatedPointEvents, (event: PointEvent) => {
                      ListItem() {
                        this.PointEventItem(event)
                      }
                      .padding(4)
                    }, (event: PointEvent) => event.id)
                  }
                }
                .width('100%')
              }
              .width('100%')
              .height('100%')
              .layoutWeight(1)
              .padding(8)

              // this.BuildNewEventInput()
            }
            .width('100%')
            .height('100%')
            .backgroundColor('#F5F5F5')

            FabButton({
              icon: $r('app.media.ic_add'),
              onTap: () => {
                this.isEventEditing = false;
                this.editingEvent = this.EMPTY_EVENT
                this.isEventAdding = true;
              }
            })
          }

          // 四象限子页面
          Column() {
            Text('四象限页面')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 20 })

            Text('四象限功能开发中...')
              .fontSize(16)
              .fontColor('#666666')
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
        }
        .index(this.currentIndex)
        .autoPlay(false)
        .indicator(false)
        .loop(false)
        .vertical(false)
        .onChange((index: number) => this.onPageChange(index))
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      if (this.isEventEditing || this.isEventAdding) {
        this.editingDialog()
      }
    }
  }

  /* ============================ 列表行 ============================ */
  // 列表中的每一项点事件
  @Builder
  PointEventItem(event: PointEvent) {
    Row() {
      Checkbox()
        .select(event.isDone)
        .onChange((value: boolean) => {
          if (value !== event.isDone) {
            this.toggleEventDone(event);
          }
        })
        .width(24)
        .height(24)

      Text(event.title)
        .fontSize(16)
        .fontColor(event.isDone ? '#999999' : '#000000')
        .decoration({
          type: event.isDone ? TextDecorationType.LineThrough : TextDecorationType.None
        })
        .layoutWeight(1)
        .margin({ left: 12 })

      Text(this.formatDate(event.deadline))
        .fontSize(14)
        .fontColor(event.isDone ? '#999999' : ((event.deadline < Date.now() && !event.isDone) ? '#FF6B00' : '#666666'))
        .decoration({
          type: event.isDone ? TextDecorationType.LineThrough : TextDecorationType.None
        })
        .margin({ right: 12 })

      Button('编辑')
        .fontSize(12)
        .fontColor('#007DFF')
        .backgroundColor(Color.Transparent)
        .borderColor('#007DFF')
        .borderWidth(1)
        .width(48)
        .height(28)
        .onClick(() => {
          this.editingEvent = copyPointEvent(event)
          this.isEventAdding = false
          this.isEventEditing = true
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor((event.deadline < Date.now() && !event.isDone) ? '#FFF3E0' : '#EEEEEE')
    .borderRadius(8)
    .alignItems(VerticalAlign.Center)
  }

  // 列表的头部，点击可以切换展开或是折叠
  @Builder
  GroupHeader(title: string, onToggle: () => void) {
    Row() {
      Text(title)
        .fontSize(14)
        .fontColor('#FFF')
    }
    .width('100%')
    .height(36)
    // 1. 内容居中
    .justifyContent(FlexAlign.Center)
    // 2. 点击检测
    .onClick(() => {
      console.info('AAAAAAAA GroupHeader clicked: ${title}.');
      onToggle();
      // 这里可抛事件、改数据、弹 Dialog 等
    })
    .backgroundColor('#AAAAAA')
  }

  // // (旧版)新建新的点事件
  // @Builder
  // BuildNewEventInput() {
  //   Column() {
  //     Row() {
  //       TextInput({ placeholder: '输入事件描述', text: this.newEventDescription })
  //         .onChange((value: string) => {
  //           this.newEventDescription = value;
  //         })
  //         .layoutWeight(1)
  //         .margin({ right: 12 })
  //         .padding(8)
  //         .backgroundColor('#FFFFFF')
  //         .borderRadius(4)
  //
  //       Column() {
  //         Image($r('app.media.ic_time_picker'))
  //           .width(24).height(24).fillColor('#FFFFFF')
  //       }
  //       .width(48).height(48)
  //       .backgroundColor('#007DFF')
  //       .borderRadius(24)
  //       .justifyContent(FlexAlign.Center)
  //       .onClick(() => {
  //         this.getUIContext().showDatePickerDialog({
  //           showTime: true,
  //           useMilitaryTime: true,
  //           onDateAccept: (v) => this.newEventDeadline = v.toString()
  //         });
  //       })
  //
  //       Button('+')
  //         .fontSize(20)
  //         .fontWeight(FontWeight.Bold)
  //         .fontColor('#FFFFFF')
  //         .backgroundColor('#007DFF')
  //         .width(48)
  //         .height(48)
  //         .borderRadius(24)
  //         .onClick(() => {
  //           this.addNewPointEvent();
  //         })
  //     }
  //     .width('100%')
  //     .padding(16)
  //     .backgroundColor('#FFFFFF')
  //   }
  // }

  // /* ================================ 悬浮按钮 ================================ */
  // @Builder
  // FabButton(icon: Resource, onTap: () => void) {
  //   Column(){
  //     Stack() {
  //       Circle()
  //         .width(56)
  //         .height(56)
  //         .fill('#007DFF')
  //         .borderRadius(28)
  //         .shadow({
  //           radius: 16, // 模糊半径
  //           color: '#77000000', // 半透明黑
  //           offsetX: 0,
  //           offsetY: 0
  //         })
  //
  //       Image(icon)
  //         .width(36)
  //         .height(36)
  //         .fillColor(Color.White)
  //     }
  //     .onClick(onTap)
  //   }
  //   .hitTestBehavior(HitTestMode.Transparent)
  //   .width('100%')
  //   .height('100%')
  //   .justifyContent(FlexAlign.End)
  //   .alignItems(HorizontalAlign.Center)
  //   .padding({ bottom: 24 })
  // }

  /* ============================ 编辑弹窗 ============================ */
  @Builder
  editingDialog() {
    Stack() {
      /* 1. 半透明黑背景：点击任意位置关闭 */
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#000000')
        .backdropBlur(12)
        .opacity(0.2)
        .onClick(() => this.closeEditor())   // ← 点击外部即返回
        .transition(
          TransitionEffect.OPACITY
            .animation({ duration: 300 })
        )

      Column() {
        Column() {
          // 顶部
          Row() {
            TextInput({
              text: this.isEventEditing ? this.editingEvent?.title : '',
              placeholder: '请输入标题...'
            })
              .onChange((v) => {
                if (this.editingEvent) this.editingEvent.title = v.slice(0, 30);
              })
              .layoutWeight(1)
              .fontSize(16)
          }
          .width('100%')
          .padding(8)

          if(this.isEventEditing) {
            Text('创建：' + this.formatDate(this.editingEvent?.createdAt ?? Date.now()))
              .fontSize(12)
              .fontColor('#999999')
              .margin({ left: 12 })
          }

          // 中部
          TextArea({
            text: this.isEventEditing ? this.editingEvent?.description : '',
            placeholder: '请输入描述...'
          })
            .onChange((v) => {
              if (this.editingEvent) this.editingEvent.description = v;
            })
            .width('100%')
            .layoutWeight(1)
            .padding(8)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)

          Blank().height(8)

          // 底部
          Row() {
            Column() {
              Image($r('app.media.ic_time_picker'))
                .width(28).height(28).fillColor('#FFFFFF')
            }
            .width(36)
            .height(36)
            .backgroundColor('#007DFF')
            .borderRadius(18)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.getUIContext().showDatePickerDialog({
                showTime: true,
                useMilitaryTime: true,
                onDateAccept: (v) => this.editingEvent.deadline = v.getTime()
              });
            })

            Text((this.editingEvent.deadline!==-1) ? ('deadline: ' + this.formatDate(this.editingEvent.deadline)) : '请选择截止时间...' )
              .fontSize(12)
              .width('50%')
              .padding(8)
              .backgroundColor('#FFFFFF')
              .fontColor('#999999')
              .borderRadius(4)

            Blank().layoutWeight(1)
          }

          Row(){
            Blank().layoutWeight(1)

            Image($r('app.media.ic_delete'))
              .width(28).height(28).fillColor('#FF0000')
              .onClick(() => {
                console.log('AAAAAAA delete button click AAAAAAA');
                this.closeEditor();
                this.deleteEvent(this.editingEvent);
              })
            Image($r('app.media.ic_save'))
              .width(28).height(28).fillColor('#007DFF')
              .onClick(() => {
                console.log('AAAAAAA save button click AAAAAAA');
                this.saveEditingEvent();
              })
            Image($r('app.media.ic_cancel'))
              .width(28).height(28).fillColor('#666666')
              .onClick(() => {
                console.log('AAAAAAA cancel button click AAAAAAA');
                this.closeEditor();
              })
          }
          .width('100%')
          .padding({ top: 12 })
        }
        .width('100%')
        .padding(16)
      }
      .width('80%')
      .height('70%')
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .shadow({ radius: 20, color: '#33000000' })
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.SpaceBetween)
      .offset({
        y: this.editorYOffset
      })

      // .transition(
      //   TransitionEffect.translate({ y: -800 }) // 从上方 80vp 滑入
      //     .animation({ duration: 300, curve: Curve.ExtremeDeceleration })
      // )
      // .onAppear(() => {
      //   this.getUIContext().animateTo({
      //     duration: 300,
      //     curve: Curve.ExtremeDeceleration
      //   }, () => {
      //     this.editorYOffset = 0
      //   })
      // })
      // .onDisAppear(() => {
      //   this.getUIContext().animateTo({
      //     duration: 300,
      //     curve: Curve.EaseInOut
      //   }, () => {
      //     this.editorYOffset = -800
      //     console.log('AAAAAAA trigger editor out animation AAAAAAA')
      //   })
      // })
    }
    .width('100%')
    .height('100%')
    /* 关键：让内部两个子节点上下左右居中 */
    .alignContent(Alignment.Center)
  }

  /* ============================ 工具方法 ============================ */

  private checkTitleLen(t: string) {
    return 0 < t.length && t.length < 30;
  }

  private checkDescriptionLen(d: string) {
    return d.length < 1000;
  }

  private saveEditingEvent() {
    try{
      if(!this.checkTitleLen(this.editingEvent.title)) {
        this.getUIContext().getPromptAction().showToast({
          message: '标题未填写或标题过长',
          duration: 2000
        });
      }
      else if(!this.checkDescriptionLen(this.editingEvent.description)) {
        this.getUIContext().getPromptAction().showToast({
          message: '事件描述过长',
          duration: 2000
        });
      }
      else if(this.editingEvent.deadline === -1) {
        this.getUIContext().getPromptAction().showToast({
          message: '请选择截止时间',
          duration: 2000
        });
      }
      else
      {
        if(this.isEventAdding) {
          eventService.addEvent(
            this.editingEvent.title,
            this.editingEvent.description,
            this.editingEvent.deadline
          );
          this.getUIContext().getPromptAction().showToast({
            message: '添加成功',
            duration: 2000
          });
        }
        else if(this.isEventEditing) {
          eventService.updateEvent(this.editingEvent.id, this.editingEvent);
          this.getUIContext().getPromptAction().showToast({
            message: '修改成功',
            duration: 2000
          });
        }
        this.closeEditor();
      }
    }
    catch (error) {

    }
  }

  /* ============================ 打开/关闭编辑器 ============================ */

  // private openNewEditor() {
  //   this.isNewEvent = true;
  //   this.editingEvent = {
  //     id: '',
  //     title: '',
  //     description: '',
  //     deadline: Date.now() + 24 * 3600 * 1000,
  //     isDone: false,
  //     createdAt: Date.now(),
  //     finishedAt: -1
  //   };
  //   this.isEditing = true;
  // }
  // private openEditor(evt: PointEvent) {
  //   this.isNewEvent = false;
  //   this.editingEvent = JSON.parse(JSON.stringify(evt)); // 深拷贝
  //   this.isEditing = true;
  // }
  private closeEditor() {
    // this.getUIContext().animateTo({ duration: 300 }, () => this.isInwardAnimation = false);
    // setTimeout(() => {
    //   this.isEventEditing = false;
    //   this.isEventAdding = false;
    //   console.log('AAAAAAA PointEvent editor animation play normally AAAAAAAA')
    // }, 300);
    // console.log('AAAAAAA PointEvent editor closed properly AAAAAAAA')
    this.isEventEditing = false;
    this.isEventAdding = false;
  }
  // private saveEdit() {
  //   if (!this.editingEvent) return;
  //   if (this.isNewEvent) {
  //     eventService.addEvent(this.editingEvent.title, this.editingEvent.description, this.editingEvent.deadline);
  //   } else {
  //     eventService.updateEvent(this.editingEvent.id, {
  //       title: this.editingEvent.title,
  //       description: this.editingEvent.description,
  //       deadline: this.editingEvent.deadline
  //     });
  //   }
  //   this.cancelEdit();
  // }

  // private async confirmDelete() {
  //   if (!this.editingEvent) return;
  //   try {
  //     const r = await this.getUIContext().getPromptAction().showDialog({
  //       title: '确认删除',
  //       message: '确定删除该事件？',
  //       buttons: [{ text: '确定', color: '#FF0000' }, { text: '取消', color: '#666666' }]
  //     });
  //     if (r && r.index === 0) {
  //       eventService.deleteEvent(this.editingEvent.id);
  //       this.cancelEdit();
  //     }
  //   } catch (e) {}
  // }

  /* ============================ 生命周期 ============================ */
  async deleteEvent(event: PointEvent): Promise<void> {
    try {
      const deleteResult = await this.getUIContext().getPromptAction().showDialog({
        title: '确认删除',
        message: '确认删除 '+event.title+' 事件？',
        buttons: [
          {
            text: '确定',
            color: '#FF0000'
          },
          {
            text: '取消',
            color: '#666666'
          }
        ]
      });

      if (deleteResult && deleteResult.index === 0) {
        eventService.deleteEvent(event.id);
        this.getUIContext().getPromptAction().showToast({ message: '事件已删除', duration: 2000 });
      }
    } catch (error) {
      console.error(`Delete dialog failed: ${(error as BusinessError).code} - ${(error as BusinessError).message}`);
    }
  }
}