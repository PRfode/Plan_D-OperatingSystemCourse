// SchedulePage.ets
import {
  PointEvent,
  eventService
} from '../services/EventService';
import {
  Routine,
  scheduleService,
  SCState
} from '../services/ScheduleService';
import { DurationPickerDialog } from '../components/DurationPickerDialog';
import { FabButton } from '../components/FabButton';
import emitter from '@ohos.events.emitter';

interface RoutineIndices {
  prev: number;
  curr: number;
  next: number;
}

interface GeneratedTypeLiteralInterface_1 {
  idx: number;
  type: string;
}

@Component
export struct SchedulePage {
  /* ===================== 状态 ===================== */
  @State allEvents: PointEvent[] = [];          // 所有未完成事件
  @State chosenIds: Set<string> = new Set();    // 已选中的事件 id
  @State routines: Routine[] = [];              // 当前排期里的 routine（顺序即展示顺序）
  @State serviceState: SCState = scheduleService.state

  /* ===================== 页面变量 ===================== */
  @State totalSec: number = scheduleService.getDuration()
  @State timeLeft: number = 0  // 倒计时剩余时间（秒）
  /* 用下标缓存，-1 表示空 */
  // @State routine_prev: number = -1;
  // @State routine_curr: number = -1;
  // @State routine_next: number = -1;
  @State routineIndices: RoutineIndices = {prev:-1, curr:-1, next:-1};

  /* ===================== 定时更新器相关 ===================== */
  private timerId: number = 0
  private readonly TIMER_INTERVAL: number = 100 // 100ms更新一次

  /* ===================== emitter callback ===================== */
  private callback2(){
    console.log('AAAAAAA emitter callback 2');
    this.totalSec = scheduleService.getDuration();
  }

  private callback3(){
    console.log('AAAAAAA emitter callback 3');
    this.refreshRoutines();
  }

  private callback4(){
    console.log('AAAAAAA emitter callback 4, set pageState to ' + scheduleService.state);
    this.serviceState = scheduleService.state

    // 状态变化时重新计算当前routine
    // this.updateCurrentRoutines()
    this.countdownRoutineCheck()

    // 根据状态启动或停止定时器
    if (this.serviceState === SCState.scheduling || this.serviceState === SCState.pausing) {
      this.stopUpdateTimer()
    } else if ([SCState.countdowning, SCState.timeouting].includes(this.serviceState)) {
      this.startUpdateTimer()
    }
  }

  /* ===================== 生命周期 ===================== */
  aboutToAppear() {
    this.callback4();
    this.refreshAllEvents();
    this.refreshRoutines();
    this.checkConsistency();
    this.totalSec = scheduleService.getDuration();
    this.registerEmitter();
    this.chosenIds = new Set(
      this.routines?.map((item: Routine): string => item.eventId) ?? []
    );

    // 初始化当前routine信息
    // this.updateCurrentRoutines()
    this.initializeCountdownRoutine()
    this.countdownRoutineCheck()

    // 根据当前状态决定是否启动定时器
    if (![SCState.scheduling, SCState.pausing].includes(this.serviceState)) {
      this.startUpdateTimer()
    }
  }

  aboutToDisappear(): void {
    this.unregisterEmitter();
    this.stopUpdateTimer()
  }

  /* ===================== 定时器控制 ===================== */
  private startUpdateTimer() {
    // 先停止现有定时器
    this.stopUpdateTimer()

    // 创建新定时器
    this.timerId = setInterval(() => {
      this.updateTimer()
    }, this.TIMER_INTERVAL)
    console.log('AAAAAAA schedulePage UpdateTimer start')
  }

  private stopUpdateTimer() {
    if (this.timerId) {
      clearInterval(this.timerId)
      this.timerId = 0
    }
    console.log('AAAAAAA schedulePage UpdateTimer stop')
  }

  private counter: number = 0;
  private updateTimer() {
    // 更新剩余时间
    this.timeLeft = scheduleService.getTimeLeft()

    // 检查是否需要更新当前routine
    // this.updateCurrentRoutines()
    if (this.counter % 5 === 0) {
      this.countdownRoutineCheck();
      this.counter = 0;
    }
    this.counter++;


    // 检查超时
    if (this.serviceState === SCState.countdowning && this.timeLeft === 0) {
      // 超时事件已在service中处理，这里只需要更新状态
      this.serviceState = scheduleService.state
    }
  }
  /* ===================== 重叠检测 ===================== */
  // 返回 true 表示有重叠
  private hasOverlap(): boolean {
    const rs = this.routines;
    for (let i = 1; i < rs.length; i++) {
      const prevEnd = rs[i - 1].startAt + rs[i - 1].duration;
      if (rs[i].startAt < prevEnd) {
        return true;
      }
    }
    return false;
  }
  private hasOverLength(): boolean {
    let len = this.routines.length
    const rsl = this.routines[len-1];
    console.log('AAAA '+(rsl.duration+rsl.startAt)+' '+scheduleService.getDuration())
    return (rsl.startAt + rsl.duration > scheduleService.getDuration());
  }

  /* ===================== 更新当前routine信息 ===================== */
  private initializeCountdownRoutine(): void {
    // 先更新timeLeft
    this.timeLeft = scheduleService.getTimeLeft();
    // 计算已过去的时间（秒）
    const totalDuration = scheduleService.getDuration();
    const elapsedTime = totalDuration - this.timeLeft;
    console.log(`AAAA ${this.routines.length}, ${elapsedTime}`)

    let prev = -1, curr = -1, next = -1;

    for (let i = 0; i < this.routines.length; i++) {
      if (this.routines[i].startAt < elapsedTime &&
        this.routines[i].startAt + this.routines[i].duration > elapsedTime) {
        curr = i;
        if (curr !== 0) prev = i - 1;
      }
      if (this.routines[i].startAt > elapsedTime) {
        next = i;
        if (prev === -1 && next !== 1) prev = i - 1
        break
      }
    }
    this.routineIndices = { prev, curr, next };
    console.log(`AAAAAAA initialize routine thumbnail: ${prev} ${curr} ${next}`)
  }

  private countdownRoutineCheck(): void {
    // const rs = this.routines;           // 已按 startAt 升序排好

    const len = this.routines.length;
    if (len === 0) {                    // 无排程
      this.routineIndices = { prev:-1, curr:-1, next:-1 };
      return;
    }
    // 计算已过去的时间（秒）
    const totalDuration = scheduleService.getDuration();
    const elapsedTime = totalDuration - this.timeLeft;

    const isNextOutdated = this.routineIndices.next!==-1?
      (elapsedTime >= this.routines[this.routineIndices.next].startAt) : false;
    const isCurrOutdated = this.routineIndices.curr!==-1?
      (elapsedTime >= this.routines[this.routineIndices.curr].startAt +
                      this.routines[this.routineIndices.curr].duration) : false;

    if (isNextOutdated || isCurrOutdated) {
      // console.log(`AAAA countdownRoutineCheck: ${isCurrOutdated} ${isNextOutdated}`);
      let prev = this.routineIndices.prev;
      let curr = this.routineIndices.curr;
      let next = this.routineIndices.next;
      if (isCurrOutdated) {
        console.log('AAAAAAA CurrOutdated');
        prev = curr;
        curr = -1;
      }
      if (isNextOutdated) {
        console.log('AAAAAAA NextOutdated')
        curr = next;
        next = next===len-1 ? -1 : next + 1;
      }

      this.routineIndices = { prev, curr, next };
      console.log(`AAAAAAA change routine thumbnail: ${prev} ${curr} ${next}`)
    }
  } // TO(solved)DO 更新idx后页面不能正常刷新

  private registerEmitter() {
    let e: emitter.InnerEvent = {
      eventId: 2
    }
    emitter.on(e, (eventData: emitter.EventData) => {
      this.callback2();
    })

    e = { eventId: 3 }
    emitter.on(e, (eventData: emitter.EventData) => {
      this.callback3();
    })

    e = { eventId: 4 }
    emitter.on(e, (eventData: emitter.EventData) => {
      this.callback4();
    })
  }

  private unregisterEmitter() {
    emitter.off(2)
    emitter.off(3)
    emitter.off(4)
  }

  /* ===================== 数据同步 ===================== */
  private refreshAllEvents() {
    this.allEvents = eventService.getPendingEvents();
  }

  private refreshRoutines() {
    console.log('AAAAAAA refresh routine')
    this.routines = scheduleService.getAllRoutines()
      .sort((a, b) => a.startAt - b.startAt);
    this.routines = [...this.routines];
    for (let rt of this.routines) {
      console.log('AAAAAAA read routine: ' + rt.title)
    }
  }

  private checkConsistency() {
    for (let rt of this.routines)
      if (!eventService.haveEvent(rt.eventId))
        scheduleService.rmvRoutine(rt.eventId)
  }

  /* ===================== 选择/取消选择 ===================== */
  private choose(evt: PointEvent) {
    if (this.chosenIds.has(evt.id)) return;
    this.chosenIds.add(evt.id);

    // 自动生成 routine：开始时间 = 已占用的总时长，时长 = 5 min
    const occupied = this.routines
      .reduce((sum, r) => sum + r.duration, 0);
    const rt: Routine = {
      eventId: evt.id,
      startAt: occupied,
      duration: 5 * 60,
      title:evt.title
    };
    scheduleService.addRoutine(rt);
    this.refreshRoutines();
  }

  private unchoose(evt: PointEvent) {
    if (!this.chosenIds.has(evt.id)) return;
    this.chosenIds.delete(evt.id);
    scheduleService.rmvRoutine(evt.id);
    this.refreshRoutines();
  }

  /* ===================== 调整 routine ===================== */
  private setStartTime(rt: Routine) {
    const ctx = this.getUIContext();
    DurationPickerDialog.show({
      selected: rt.startAt,
      minDuration: 0,
      maxDuration: this.totalSec - rt.duration,
      onAccept: (v: number) => {
        rt.startAt = v;
        scheduleService.addRoutine(rt); // 内部会重建
        this.refreshRoutines();
      }
    }, ctx);
  }

  private setDuration(rt: Routine) {
    const ctx = this.getUIContext();
    DurationPickerDialog.show({
      selected: rt.duration,
      minDuration: 60,
      maxDuration: this.totalSec - rt.startAt,
      onAccept: (v: number) => {
        rt.duration = v;
        scheduleService.addRoutine(rt);
        this.refreshRoutines();
      }
    }, ctx);
  }

  private deleteRoutine(rt: Routine) {
    scheduleService.rmvRoutine(rt.eventId);
    this.chosenIds.delete(rt.eventId);
    this.refreshRoutines();
  }

  /* ===================== 顶部总时长 ===================== */
  private pickTotalDuration() {
    const ctx = this.getUIContext();
    DurationPickerDialog.show({
      selected: this.totalSec,
      minDuration: 60,
      maxDuration: 3 * 3600,
      onAccept: (v: number) => {
        scheduleService.setDuration(v);
        try {
          this.getUIContext().getPromptAction().showToast({ message: '已更新总时长', duration: 2000 });
        } catch (error) {
          // Implement error handling.
        }
      }
    }, ctx);
  }

  /* ===================== 倒计时控制 ===================== */
  private startScheduleCountdown() {
    if (this.routines.length === 0) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '请先选择事件', duration: 2000 });
      } catch (error) {
        // Implement error handling.
      }
      return;
    }
    /* ===== 新增：重叠检测 ===== */
    if (this.hasOverlap()) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '时间段存在重叠，请调整后重试', duration: 2000 })
        console.log('AAAAAAA overlap diaoyong')
      } catch (error) {}
      return;
    }
    if (this.hasOverLength()) {
      try {
        this.getUIContext().getPromptAction().showToast({ message: '时间段时长超过总时间，请调整后重试', duration: 2000 })
        console.log('AAAAAAA overlength diaoyong')
      } catch (error) {}
      return;
    }
    /* ========================= */
    scheduleService.startCountdown();
    this.initializeCountdownRoutine();
    try {
      this.getUIContext().getPromptAction().showToast({ message: '倒计时已开始', duration: 2000 });
    } catch (error) {
      // Implement error handling.
    }
  }

  private pauseCountdown() {
    scheduleService.pauseCountdown();
  }

  private resumeCountdown() {
    scheduleService.resumeCountdown();
  }

  private quitCountdown() {
    scheduleService.quitCountdown();
    this.routineIndices = { prev:-1, curr:-1, next:-1 }
  }

  /* ===================== UI ===================== */
  build() {
    Stack() {
      // 根据状态显示不同的UI
      if (this.serviceState === SCState.scheduling) {
        this.SchedulingView()
      } else {
        this.CountdownView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  /* ===================== scheduling状态下的UI ===================== */
  @Builder SchedulingView() {
    Column() {
      /* -------------- 顶部 -------------- */
      Row() {
        Text(this.formatTime(this.totalSec))
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor('#007DFF')
          .onClick(() => this.pickTotalDuration())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(16)

      /* -------------- 中部：选择列表 -------------- */
      Row() {
        List({ space: 8 }) {
          ForEach(this.allEvents, (evt: PointEvent) => {
            ListItem() {
              this.EventChoiceItem(evt)
            }
            .onClick(() => {
              if (this.chosenIds.has(evt.id)) this.unchoose(evt); else this.choose(evt);
            })
          }, (evt: PointEvent) => evt.id)
        }
        .lanes(2) // 两列
        .height(240)
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .padding(8)
        .width('100%')
        .height('100%')
      }
      .width('90%')
      .height('30%')
      .justifyContent(FlexAlign.Center)

      /* -------------- 下部：预览列表 -------------- */
      Row() {
        Column() {
          // 重置按钮
          Row() {
            Image($r('app.media.ic_reset'))
              .width(24).height(24).fillColor('#666666')
              .onClick(() => {
                scheduleService.rmvAllRoutines();
                this.chosenIds.clear();
                this.refreshRoutines();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .padding({ right: 12, bottom: 8 })

          // 列表
          List({ space: 6 }) {
            ForEach(this.routines, (rt: Routine) => {
              ListItem() {
                this.RoutinePreviewItem(rt)
              }
            }, (rt: Routine) => `${rt.eventId}-${rt.startAt}-${rt.duration}`)
          }
          .height(200)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .padding(8)
          .width('100%')
          .height('100%')
        }
      }
      .width('90%')
      .justifyContent(FlexAlign.Center)
      .padding({ top: 12 })
    }

    /* -------------- 悬浮按钮 -------------- */
    FabButton({
      icon: $r('app.media.ic_play'),
      onTap: (): void => this.startScheduleCountdown()
    })
  }

  /* ===================== 倒计时状态下的UI ===================== */
  @Builder CountdownView() {
    Column() {
      Blank().height(80)
      /* -------------- 顶部：倒计时显示 -------------- */
      Row() {
        Text(this.formatTime(this.timeLeft))
          .fontSize(72)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.serviceState === SCState.timeouting ? '#FF6B00' : '#007DFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(16)

      /* -------------- 中部：当前routine预览 -------------- */
      Row() {
        // 上一个routine
        Column() {
          Text('上一个')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ bottom: 2 })
          if (this.routineIndices.prev!==-1) {
            this.RoutineThumbnail({idx:this.routineIndices.prev, type:'prev'})
          } else {
            Column() {
              Text('无')
                .fontSize(14)
                .fontColor('#999999')
            }
            .width('80%')
            .height(80)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
          }
        }
        .width('30%')
        .justifyContent(FlexAlign.Center)

        // 当前routine
        Column() {
          Text('现在')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ bottom: 2 })
          if (this.routineIndices.curr!==-1) {
            this.RoutineThumbnail({idx:this.routineIndices.curr, type:'current'})
          } else {
            Column() {
              // if (this.routineIndices.prev) {
                Text('空闲')
                  .fontSize(14)
                  .fontColor('#999999')
              // } else if (this.routineIndices.next!==-1) {
              //   // const timeToStart = this.nextRoutine.startAt - (scheduleService.getDuration() - this.timeLeft)
              //   Text(`还有:${this.formatTime(this.routines[this.routineIndices.next].startAt - (scheduleService.getDuration() - this.timeLeft))}`)
              //     .fontSize(14)
              //     .fontColor('#007DFF')
              // } else {
              //   Text('空闲')
              //     .fontSize(14)
              //     .fontColor('#999999')
              // }
            }
            .width('80%')
            .height(80)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
          }
        }
        .width('30%')
        .justifyContent(FlexAlign.Center)

        // 下一个routine
        Column() {
          Text('下一个')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ bottom: 2 })
          if (this.routineIndices.next!==-1) {
            this.RoutineThumbnail({idx:this.routineIndices.next, type:'next'})
          } else {
            Column() {
              Text('无')
                .fontSize(14)
                .fontColor('#999999')
            }
            .width('80%')
            .height(80)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
          }
        }
        .width('30%')
        .justifyContent(FlexAlign.Center)
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding(16)

      /* -------------- 下部：控制按钮 -------------- */
      Blank()
      Row() {
        // 根据状态显示不同按钮
        if (this.serviceState === SCState.countdowning) {
          // 左侧暂停按钮
          Image($r('app.media.ic_pause'))
            .width(48).height(48)
            .fillColor('#007DFF')
            .onClick(() => this.pauseCountdown())

          Blank().width('40%')

          // 右侧退出按钮
          Image($r('app.media.ic_stop'))
            .width(48).height(48)
            .fillColor('#FF0000')
            .onClick(() => this.quitCountdown())

        } else if (this.serviceState === SCState.pausing) {
          // 左侧继续按钮
          Image($r('app.media.ic_play'))
            .width(48).height(48)
            .fillColor('#007DFF')
            .onClick(() => this.resumeCountdown())

          Blank().width('40%')

          // 右侧退出按钮
          Image($r('app.media.ic_stop'))
            .width(48).height(48)
            .fillColor('#FF0000')
            .onClick(() => this.quitCountdown())

        } else if (this.serviceState === SCState.timeouting) {
          // 只有退出按钮
          Image($r('app.media.ic_stop'))
            .width(48).height(48)
            .fillColor('#FF6B00')
            .onClick(() => this.quitCountdown())
        }
      }
      .width('90%')
      .justifyContent(FlexAlign.Center)
      .padding(32)
    }
    .width('100%')
    .height('100%')
  }

  /* ===================== 选择列表项 ===================== */
  @Builder EventChoiceItem(evt: PointEvent) {
    Row() {
      Column() {
        Text(evt.title)
          .fontSize(15)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column() {
        Text(`截止：${this.fmtDate(evt.deadline)}`)
          .fontSize(11).fontColor(evt.deadline < Date.now() ? '#FF6B00' : '#666666')
        Blank().height(4)
        Text(`创建：${this.fmtDate(evt.createdAt)}`)
          .fontSize(11).fontColor('#999999')
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .padding(this.chosenIds.has(evt.id) ? 6 : 8)
    .backgroundColor(evt.deadline < Date.now() ? '#FFF3E0' : '#EEEEEE')
    .borderRadius(8)
    .borderWidth(this.chosenIds.has(evt.id) ? 2 : 0)
    .borderColor('#90CAF9')
  }

  /* ===================== 预览列表项 ===================== */
  @Builder
  RoutinePreviewItem(rt: Routine) {
    Row() {
      Text(rt.title)
        .fontSize(15)
        .layoutWeight(1)

      Column() {
        Text(`${this.formatTimeToMS(rt.duration)}`)
          .fontSize(12).fontColor('#666666')
        Text(`开始于 ${this.formatTimeToMS(rt.startAt)}`)
          .fontSize(12).fontColor('#666666')
      }
      .alignItems(HorizontalAlign.End)
      .margin({ right: 8 })

      // 调整开始时间
      Image($r('app.media.ic_time_picker'))
        .width(20).height(20).fillColor('#007DFF')
        .onClick(() => this.setStartTime(rt))

      // 调整时长
      Image($r('app.media.ic_duration_picker'))
        .width(20).height(20).fillColor('#007DFF')
        .margin({ left: 6 })
        .onClick(() => this.setDuration(rt))

      // 删除
      Image($r('app.media.ic_delete'))
        .width(20).height(20).fillColor('#FF0000')
        .margin({ left: 6 })
        .onClick(() => this.deleteRoutine(rt))
    }
    .width('100%')
    .padding(8)
    .backgroundColor('#EEEEEE')
    .borderRadius(8)
  }

  /* ===================== routine缩略图 ===================== */
  @Builder RoutineThumbnail($$: GeneratedTypeLiteralInterface_1) {
    Column() {
      Text(this.routines[$$.idx].title)
        .fontSize($$.type === 'current' ? 16 : 14)
        .fontWeight($$.type === 'current' ? FontWeight.Bold : FontWeight.Normal)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Blank().height(4)

      // 计算相对开始时间（从倒计时开始算）
      // const totalDuration = scheduleService.getDuration()
      // const relativeStart = totalDuration - this.timeLeft - rt.startAt

      if ($$.type === 'prev') {
        Text('已完成')
          .fontSize(12)
          .fontColor('#999999')
      } else if ($$.type === 'current') {
        Text(`${this.formatTime(Math.max(0, this.routines[$$.idx].duration - (scheduleService.getDuration() - this.timeLeft - this.routines[$$.idx].startAt)))}`)
          .fontSize(12)
          .fontColor('#007DFF')
      } else { // next
        // const timeToStart = rt.startAt - (totalDuration - this.timeLeft)
        Text(`开始:${this.formatTime(this.routines[$$.idx].startAt - (scheduleService.getDuration() - this.timeLeft))}`)
          .fontSize(12)
          .fontColor('#666666')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($$.type === 'current' ? '#E3F2FD' : '#FFFFFF')
    .borderRadius(8)
    .borderWidth($$.type === 'current' ? 2 : 1)
    .borderColor($$.type === 'current' ? '#2196F3' : '#E0E0E0')
  }

  /* ===================== 工具函数 ===================== */
  private fmtDate(ts: number): string {
    const d = new Date(ts)
    const MM = (d.getMonth() + 1).toString().padStart(2, '0')
    const DD = d.getDate().toString().padStart(2, '0')
    const hh = d.getHours().toString().padStart(2, '0')
    const mm = d.getMinutes().toString().padStart(2, '0')
    return `${MM}/${DD} ${hh}:${mm}`
  }

  private formatTime(seconds: number): string {
    if (seconds < 0) seconds = 0
    const h = Math.floor(seconds / 3600).toString().padStart(2, '0')
    const m = Math.floor((seconds % 3600) / 60).toString().padStart(2, '0')
    const s = (seconds % 60).toString().padStart(2, '0')
    return `${h}:${m}:${s}`
  }
  private formatTimeToMS(seconds:number): string {
    if (seconds < 0) seconds = 0
    const m = Math.floor((seconds) / 60)
    const s = (seconds % 60)
    if (m === 0) {
      return `${s}秒`
    }
    if (s === 0) {
      return `${m}分`
    }
    return `${m}分${s}秒`

  }
}