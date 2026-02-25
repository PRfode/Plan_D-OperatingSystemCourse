// ScheduleService.ets
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { util } from '@kit.ArkTS';

import emitter from '@ohos.events.emitter';

/* =============================  数据接口  ============================= */
export interface Routine {
  eventId: string;   // 全局唯一
  startAt: number;   // 相对 schedule 起点 秒
  duration: number;  // 秒
  title: string;
}

export interface OnGoingSchedule {
  scheduleDuration: number; // 秒
  startTime: number;        // ms
  timeLeft: number;         // 秒  -1 表示尚未启动
  routines: Routine[];
}

export interface HistoryItem {
  startTime: number;
  scheduleDuration: number;
  endTime: number;
}

interface HistoryFile {
  history: HistoryItem[];
  totalDurationTime: number; // 累计已完成时长 秒
}

/* =============================  状态枚举  ============================= */
export enum SCState {
  scheduling  = 'scheduling',
  countdowning = 'countdowning',
  pausing     = 'pausing',
  timeouting  = 'timeouting',
}

/* =============================  工具函数  ============================= */
function strToBuf(str: string): ArrayBuffer {
  const encoder = util.TextEncoder.create('utf-8');
  return encoder.encodeInto(str).buffer;
}
function bufToStr(buf: ArrayBuffer): string {
  const decoder = util.TextDecoder.create('utf-8');
  return decoder.decodeToString(new Uint8Array(buf));
}

/* =============================  服务实现  ============================= */
class ScheduleService {
  /* --------------  单例  -------------- */
  private static instance: ScheduleService;
  public static getInstance(): ScheduleService {
    if (!ScheduleService.instance) {
      ScheduleService.instance = new ScheduleService();
    }
    return ScheduleService.instance;
  }
  private constructor() {}

  /* --------------  对外只读  -------------- */
  get state() { return this._state; }
  get onGoingSchedule() { return this.onGoing; }
  get onGoingRoutine() { return this.onGoing?.routines ?? []; }
  get historySchedules() { return this.history.slice(); }
  get totalDurationTime() { return this.totalDuration; }

  /* ============================================================
   *  生命周期：初始化
   * ============================================================ */
  private context: common.UIAbilityContext | null = null;
  private fileDir: string = '';
  private historyFile: string = '';
  private onGoingFile: string = '';

  public initialize(ctx: common.UIAbilityContext): void {
    if (this.context) return;
    this.context = ctx;
    this.fileDir = ctx.filesDir;
    this.historyFile = `${this.fileDir}/history_schedule.json`;
    this.onGoingFile = `${this.fileDir}/onGoing_schedule.json`;
    this.loadFromDisk();
    if (this.autoSaveFlag) this.startAutoSave();
  }

  public onAppExit(): void {
    try {
      // 1. 立即保存当前排期
      this.saveOnGoing();
      // 2. 把已完成的 history 也顺带写一次（防止前面崩溃未写盘）
      this.saveHistory();
      // 3. 停掉定时器，防止退出后残留
      this.stopAutoSave();
      console.info('####### [INFO] ScheduleService: onAppExit saved.');
      console.info('AAAAAAA quit schedule state: ' + this.state)
    } catch (e) {
      console.error('####### [WARNING] ScheduleService: onAppExit failed', e);
    }
  }

  /* ============================================================
   *  对外 API —— 倒计时控制
   * ============================================================ */
  public startCountdown() {
    if (this._state !== SCState.scheduling) return;
    const now = Date.now();
    this.startTimestamp = now;
    this.pauseTimestamp = now;
    this.countdownTimeLeftAtLastPause = this.onGoing!.scheduleDuration * 1000;
    // 首次启动，timeLeft 由 -1 变为 scheduleDuration
    this.onGoing!.timeLeft = this.onGoing!.scheduleDuration;
    this.saveOnGoing();            // 落盘
    this._state = SCState.countdowning;
    this.emitChange(4); // 4表示发生状态机状态的变更
  }

  public pauseCountdown() {
    if (this._state !== SCState.countdowning) return;
    const now = Date.now();
    this.countdownTimeLeftAtLastPause -= (now - this.pauseTimestamp);
    this.pauseTimestamp = now;
    this.onGoing!.timeLeft = Math.round(this.countdownTimeLeftAtLastPause / 1000);
    this.saveOnGoing();
    this._state = SCState.pausing;
    this.emitChange(4);
  }

  public resumeCountdown() {
    if (this._state !== SCState.pausing) return;
    this.pauseTimestamp = Date.now();
    this.saveOnGoing();
    this._state = SCState.countdowning;
    this.emitChange(4);
  }

  public quitCountdown() {
    // 任意状态均可 quit → scheduling
    this.saveOnGoing();   // 保留现场
    this._state = SCState.scheduling;
    if (this.onGoing?.timeLeft) this.onGoing.timeLeft = -1;
    this.emitChange(4);
    console.log('AAAAAAA scheduleService quiting')
  }

  public resetCountdown() {
    // 仅 scheduling 下可重置
    if (this._state !== SCState.scheduling) return;
    this.clearOnGoing();  // 删除磁盘文件
    this.initNewOnGoing(this.defaultDuration); // 新建空排期
    this.totalDuration = 0; // 可选：同时清零累计时长
  }

  /* ============================================================
   *  对外 API —— duration 读写
   * ============================================================ */
  public setDuration(sec: number) {
    if (sec <= 0) return;
    if (this._state === SCState.scheduling) {
      // 空闲时直接改
      this.onGoing!.scheduleDuration = sec;
      this.onGoing!.timeLeft = -1;
      console.log('AAAAAAA scheduleService setDuration');
      this.emitChange(2);
    } else {
      // 运行中仅作缓存，等下次 reset 后生效
      this.pendingDuration = sec;
    }
  }
  public getDuration(): number {
    // console.info('AAAAAAA getDuration onGoing=' + JSON.stringify(this.onGoing));
    return this.onGoing?.scheduleDuration ?? 0;
  }

  /* ============================================================
   *  对外 API —— routine CRUD
   * ============================================================ */
  public addRoutine(rt: Routine) {
    // if (!rt.createTs) rt.createTs = Date.now();
    if (rt.eventId && !this.routineIDMapping.has(rt.eventId)) {
      this.onGoing!.routines.push(rt);
      this.rebuildMapping();
      this.saveOnGoing();
    }
  }
  public rmvRoutine(eventId: string) {
    const idx = this.onGoing!.routines.findIndex(r => r.eventId === eventId);
    if (idx === -1) return;
    this.onGoing!.routines.splice(idx, 1);
    this.rebuildMapping();
    this.saveOnGoing();
  }
  public rmvAllRoutines() {
    this.onGoing!.routines.length = 0;
    this.routineIDMapping.clear();
    this.saveOnGoing();
  }
  public getRoutine(eventId: string) {
    return this.routineIDMapping.get(eventId) ?? null;
  }
  public getAllRoutines() { return this.onGoingRoutine.slice(); }

  /* ============================================================
   *  对外 API —— 自动保存开关
   * ============================================================ */
  get autoSave() { return this.autoSaveFlag; }
  set autoSave(v: boolean) {
    this.autoSaveFlag = v;
    v ? this.startAutoSave() : this.stopAutoSave();
  }

  /* ============================================================
   *  内部状态机变量
   * ============================================================ */
  private _state: SCState = SCState.scheduling;
  private onGoing: OnGoingSchedule | null = null;
  private history: HistoryItem[] = [];
  private totalDuration: number = 0; // 累计已完成时长 秒
  private routineIDMapping: Map<string, Routine> = new Map();

  /* --------------  计时戳  -------------- */
  private startTimestamp = 0;
  private pauseTimestamp = 0;
  private countdownTimeLeftAtLastPause = 0; // ms

  /* --------------  自动保存  -------------- */
  private autoSaveInterval: number = 0;
  private autoSaveFlag: boolean = true;
  private defaultDuration = 25 * 60; // 默认 25 min
  private pendingDuration = 0;       // 运行中暂存的新时长

  /* --------------  发射变更  -------------- */
  private emitChange(innerEventID:number){
    let e: emitter.InnerEvent = {
      eventId: innerEventID
    }
    emitter.emit(e)
  }

  /* ============================================================
   *  磁盘 IO
   * ============================================================ */
  private loadFromDisk() {
    this.loadHistory();
    this.loadOnGoing();
    // 策略：存在未结束 schedule → pausing
    if (this.onGoing && this.onGoing.timeLeft > 0) {
      this._state = SCState.pausing;
      this.countdownTimeLeftAtLastPause = this.onGoing.timeLeft * 1000;
      this.pauseTimestamp = Date.now();
    } else {
      this._state = SCState.scheduling;
    }
  }
  private loadHistory() {
    try {
      if (!fs.accessSync(this.historyFile)) return;
      const file = fs.openSync(this.historyFile, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      if (stat.size) {
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        const obj: HistoryFile = JSON.parse(bufToStr(buf));
        this.history = obj.history ?? [];
        this.totalDuration = obj.totalDurationTime ?? 0;
      }
      fs.closeSync(file.fd);
    } catch (e) {
      console.warn('####### [WARNING] load history error', e);
    }
  }
  private loadOnGoing() {
    try {
      if (!fs.accessSync(this.onGoingFile)) {
        // 不存在则新建
        this.initNewOnGoing(this.defaultDuration);
        return;
      }
      const file = fs.openSync(this.onGoingFile, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      if (stat.size) {
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        this.onGoing = JSON.parse(bufToStr(buf));
        this.rebuildMapping();
      } else {
        this.initNewOnGoing(this.defaultDuration);
      }
      fs.closeSync(file.fd);
    } catch (e) {
      console.warn('####### [WARNING] load onGoing error', e);
      this.initNewOnGoing(this.defaultDuration);
    }
  }
  private saveOnGoing() {
    if (!this.onGoing) return;
    // 按 startAt 升序排序
    this.onGoing.routines.sort((a, b) => (a.startAt - b.startAt));
    try {
      const file = fs.openSync(this.onGoingFile, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, strToBuf(JSON.stringify(this.onGoing)));
      fs.closeSync(file.fd);
      console.log('AAAAAAA scheduleService save onGoing!')
    } catch (e) {
      console.error('####### [WARNING] save onGoing failed', e);
    }
  }
  private saveHistory() {
    try {
      const data: HistoryFile = { history: this.history, totalDurationTime: this.totalDuration };
      const file = fs.openSync(this.historyFile, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, strToBuf(JSON.stringify(data)));
      fs.closeSync(file.fd);
      console.log('AAAAAAA scheduleService save History!')
    } catch (e) {
      console.error('####### [WARNING] save history failed', e);
    }
  }
  private clearOnGoing() {
    try { fs.unlinkSync(this.onGoingFile); } catch {}
    this.onGoing = null;
    this.routineIDMapping.clear();
  }
  private initNewOnGoing(durationSec: number) {
    this.onGoing = {
      scheduleDuration: durationSec,
      startTime: Date.now(),
      timeLeft: -1,
      routines: [],
    };
    this.routineIDMapping.clear();
  }

  /* ============================================================
   *  自动保存
   * ============================================================ */
  private startAutoSave() {
    this.stopAutoSave();
    this.autoSaveInterval = setInterval(() => {
      if (this.autoSaveFlag && this.onGoing) this.saveOnGoing();
    }, 30_000) as number;
  }
  private stopAutoSave() {
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval);
      this.autoSaveInterval = 0;
    }
  }

  /* ============================================================
   *  工具：重建 mapping + 排序
   * ============================================================ */
  private rebuildMapping() {
    this.routineIDMapping.clear();
    for (const rt of this.onGoing!.routines) {
      this.routineIDMapping.set(rt.eventId, rt);
    }
  }

  /* ============================================================
   *  超时处理
   * ============================================================ */
  public checkTimeout(): boolean {
    if (this._state === SCState.timeouting) return true;
    const leftMs = this.countdownTimeLeftAtLastPause - (Date.now() - this.pauseTimestamp);
    if (this._state === SCState.countdowning && leftMs < 0) {
      this._state = SCState.timeouting;
      // 写入历史
      const item: HistoryItem = {
        startTime: this.onGoing!.startTime,
        scheduleDuration: this.onGoing!.scheduleDuration,
        endTime: Date.now(),
      };
      this.history.push(item);
      this.totalDuration += item.scheduleDuration;
      this.saveHistory();
      return true;
    }
    return false;
  }

  /* ============================================================
   *  供外部轮询的剩余时间（秒）
   * ============================================================ */
  public getTimeLeft(): number {
    if (this._state === SCState.timeouting) return 0;
    if (this._state === SCState.pausing) return Math.max(0, this.onGoing!.timeLeft);
    if (this._state === SCState.countdowning) {
      const leftMs = this.countdownTimeLeftAtLastPause - (Date.now() - this.pauseTimestamp);
      if (leftMs <= 0) {
        this.checkTimeout();
        return 0;
      }
      return Math.ceil(leftMs / 1000);
    }
    return -1;
  }
}

export const scheduleService = ScheduleService.getInstance();