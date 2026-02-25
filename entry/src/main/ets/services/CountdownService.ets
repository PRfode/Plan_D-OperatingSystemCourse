// CountdownService.ets
import emitter from '@ohos.events.emitter';
// import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
// import { util } from '@kit.ArkTS';

// 计时历史记录数据结构
// export interface CountdownHistory {
//   startTime: number;      // 开始时间戳
//   duration: number;       // 持续时间（秒）
//   endTime: number;        // 结束时间戳
// }

// 倒计时器状态
export interface CountdownState {
  isRunning: boolean;     // 是否正在运行
  isPaused: boolean;      // 是否暂停
  startTime: number;      // 开始时间戳
  pausedTime: number;     // 暂停时的时间戳
  duration: number;       // 总计时时长（秒）
  remainingTime: number;  // 剩余时间（秒）
}

// Emitter事件数据接口
interface EmitterEventData {
  message: string;
}


// function StringToBuffer(str: string): ArrayBuffer {
//   const encoder = util.TextEncoder.create('UTF-8')
//   const uint8Array = encoder.encodeInto(str)
//   return uint8Array.buffer
// }
//
// function bufferToString(buffer: ArrayBuffer): string {
//   let decoder = util.TextDecoder.create('UTF-8')
//   let uint8Array = new Uint8Array(buffer)
//   return decoder.decodeToString(uint8Array)
// }
//
//
// interface GeneratedObjectLiteralInterface_1 {
//   history: CountdownHistory[];
//   totalTimeCount: number;
// }

class CountdownService {
  private static instance: CountdownService;

  // 持久化数据
  // private countdownHistory: CountdownHistory[] = [];
  private totalTimeCount: number = 0; // 总计时时间（秒）

  // 运行时状态
  private isRunning: boolean = false;
  private isPaused: boolean = false;
  private startTime: number = 0;
  private pausedTime: number = 0;
  private duration: number = 0; // 总计时时长（秒）
  private remainingTime: number = 0;

  // 文件管理
  // private filePath: string = '';
  private context: common.UIAbilityContext | null = null;
  // private autoSaveTimer: number = 0;
  private isInitialized: boolean = false;
  // private savePending: boolean = false;

  // 定时器
  private countdownTimer: number = 0;
  // private lastUpdateTime: number = 0;

  /* ========================= 对外参数 ========================== */
  // private autoSaveServiceState: boolean = true;
  //
  // getAutoSave(): boolean { return this.autoSaveServiceState; }
  // setAutoSave(enable: boolean): void {
  //   if (enable) this.startAutoSave();
  //   else this.stopAutoSave();
  // }

  // 私有构造函数
  private constructor() {}

  // 获取单例实例
  public static getInstance(): CountdownService {
    if (!CountdownService.instance) {
      CountdownService.instance = new CountdownService();
    }
    return CountdownService.instance;
  }

  // 初始化服务
  initialize(context: common.UIAbilityContext): void {
    if (this.isInitialized) {
      return;
    }

    this.context = context;
    // this.filePath = context.filesDir + '/countdown_history.json';
    // this.loadHistory();
    // this.startAutoSave();
    this.isInitialized = true;

    console.log('####### [INFO] countdown service started normally.');
  }

  // 加载历史记录
  // private loadHistory(): void {
  //   try {
  //     if (fs.accessSync(this.filePath)) {
  //       const file = fs.openSync(this.filePath, fs.OpenMode.READ_ONLY);
  //       const stat = fs.statSync(file.fd);
  //
  //       if (stat.size > 0) {
  //         const arrayBuf: ArrayBuffer = new ArrayBuffer(stat.size);
  //         const readSize = fs.readSync(file.fd, arrayBuf);
  //
  //         if (readSize > 0) {
  //           const data: GeneratedObjectLiteralInterface_1 = JSON.parse(bufferToString(arrayBuf));
  //           this.countdownHistory = data.history || [];
  //           this.totalTimeCount = data.totalTimeCount || 0;
  //           console.info('####### [INFO] Countdown history loaded successfully.');
  //         }
  //       }
  //
  //       fs.closeSync(file);
  //     } else {
  //       console.info('####### [INFO] Countdown history file does not exist, initializing empty data.');
  //       this.countdownHistory = [];
  //       this.totalTimeCount = 0;
  //     }
  //   } catch (error) {
  //     console.error('####### [WARN] Failed to load countdown history, initializing empty data: ', error, '.');
  //     this.backupAndInitialize();
  //   }
  // }
  //
  // 备份并初始化
  // private backupAndInitialize(): void {
  //   try {
  //     if (fs.accessSync(this.filePath)) {
  //       const backupPath = this.filePath + '.bak';
  //       fs.copyFileSync(this.filePath, backupPath);
  //       console.info('Backup created:', backupPath);
  //     }
  //   } catch (error) {
  //     console.warn('Backup failed:', error);
  //   }
  //   this.countdownHistory = [];
  //   this.totalTimeCount = 0;
  // }
  //
  // 保存数据到文件
  // private saveToFile(): void {
  //   if (!this.context) {
  //     console.error('####### [WARN] Failed to save to file: countdownService not initialized.');
  //     return;
  //   }
  //
  //   try {
  //     const data: GeneratedObjectLiteralInterface_1 = {
  //       history: this.countdownHistory,
  //       totalTimeCount: this.totalTimeCount
  //     };
  //     const content = JSON.stringify(data);
  //     const file = fs.openSync(this.filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  //     const arrayBuffer = StringToBuffer(content);
  //     fs.writeSync(file.fd, arrayBuffer);
  //     fs.closeSync(file);
  //     this.savePending = false;
  //     console.info('####### [INFO] Countdown history saved to file.');
  //   } catch (error) {
  //     console.error('####### [WARN] Failed to save countdown history: ', error, '.');
  //   }
  // }
  //
  // 开始自动保存
  // private startAutoSave(): void {
  //   // 每30秒自动保存一次
  //   this.autoSaveTimer = setInterval(() => {
  //     if (this.savePending) {
  //       this.saveToFile();
  //     }
  //   }, 30000) as number;
  //   this.autoSaveServiceState = true;
  // }
  //
  // 停止自动保存
  // private stopAutoSave(): void {
  //   this.autoSaveServiceState = false;
  //   if (this.autoSaveTimer) {
  //     clearInterval(this.autoSaveTimer);
  //     this.autoSaveTimer = 0;
  //   }
  // }

  // 标记需要保存并触发变更事件
  private markDirty(): void {
    // this.savePending = true;
    this.emitChangeEvent();
  }

  // 发射变更事件
  private emitChangeEvent(): void {
    const eventData: emitter.InnerEvent = {
      eventId: 1,
      priority: emitter.EventPriority.HIGH
    };

    const emitterData: EmitterEventData = {
      message: "countdownStateChanged"
    };

    emitter.emit(eventData, { data: emitterData });
  }

  // 更新倒计时
  private updateCountdown(): void {
    if (!this.isRunning || this.isPaused) {
      return;
    }

    const currentTime = Math.floor(Date.now() / 1000); // 转换为秒
    const elapsed = currentTime - Math.floor(this.startTime / 1000);
    this.remainingTime = this.duration - elapsed;

    if (this.remainingTime <= 0) {
      this.finishCountdown();
    }
  }

  // 完成倒计时
  private finishCountdown(): void {
    this.stopCountdownTimer();

    // 记录历史
    // const history: CountdownHistory = {
    //   startTime: this.startTime,
    //   duration: this.duration,
    //   endTime: Date.now()
    // };
    //
    // this.countdownHistory.push(history);
    this.totalTimeCount += this.duration;

    // 重置状态
    this.isRunning = false;
    this.isPaused = false;
    this.startTime = 0;
    this.pausedTime = 0;
    this.remainingTime = 0;

    this.markDirty();
    console.info('####### [INFO] Countdown finished and recorded to history.');
  }

  // 停止倒计时定时器
  private stopCountdownTimer(): void {
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer);
      this.countdownTimer = 0;
    }
  }

  // 开始倒计时定时器
  private startCountdownTimer(): void {
    this.stopCountdownTimer();

    // 每秒更新一次
    this.countdownTimer = setInterval(() => {
      this.updateCountdown();
      this.emitChangeEvent(); // 每秒触发一次更新事件
    }, 1000) as number;
  }

  /* ========================= 公共方法 ========================== */

  // 开始计时
  start(duration: number): void {
    if (this.isRunning) {
      console.warn('####### [WARN] Countdown is already running.');
      return;
    }

    this.duration = duration;
    this.remainingTime = duration;
    this.startTime = Date.now();
    this.isRunning = true;
    this.isPaused = false;
    this.pausedTime = 0;

    this.startCountdownTimer();
    this.markDirty();
    console.info('####### [INFO] Countdown started with duration:', duration, 'seconds.');
  }

  // 暂停计时
  pause(): void {
    if (!this.isRunning || this.isPaused) {
      console.warn('####### [WARN] Countdown is not running or already paused.');
      return;
    }

    this.isPaused = true;
    this.pausedTime = Date.now();
    this.stopCountdownTimer();

    this.markDirty();
    console.info('####### [INFO] Countdown paused.');
  }

  // 恢复计时
  resume(): void {
    if (!this.isRunning || !this.isPaused) {
      console.warn('####### [WARN] Countdown is not running or not paused.');
      return;
    }

    // 调整开始时间以补偿暂停时间
    const pauseDuration = Date.now() - this.pausedTime;
    this.startTime += pauseDuration;
    this.isPaused = false;
    this.pausedTime = 0;

    this.startCountdownTimer();
    this.markDirty();
    console.info('####### [INFO] Countdown resumed.');
  }

  // 重置计时器
  reset(): void {
    this.stopCountdownTimer();

    this.isRunning = false;
    this.isPaused = false;
    this.startTime = 0;
    this.pausedTime = 0;
    this.duration = 0;
    this.remainingTime = 0;

    this.markDirty();
    console.info('####### [INFO] Countdown reset.');
  }

  // 设置计时长度（只能在未运行时设置）
  setDuration(duration: number): void {
    if (this.isRunning) {
      console.warn('####### [WARN] Cannot set duration while countdown is running.');
      return;
    }

    this.duration = duration;
    this.remainingTime = duration;
    this.markDirty();
    console.info('####### [INFO] Countdown duration set to:', duration, 'seconds.');
  }

  // 获取剩余时间（秒）
  getTimeRemain(): number {
    if (!this.isRunning) {
      return this.remainingTime;
    }

    if (this.isPaused) {
      return this.remainingTime;
    }

    // 实时计算剩余时间
    const currentTime = Math.floor(Date.now() / 1000);
    const elapsed = currentTime - Math.floor(this.startTime / 1000);
    return Math.max(0, this.duration - elapsed);
  }

  // 获取剩余时间的时分秒
  getHMSRemain(): [number, number, number] {
    const totalSeconds = this.getTimeRemain();
    const hours = Math.floor(totalSeconds / 3600);
    const minutes = Math.floor((totalSeconds % 3600) / 60);
    const seconds = totalSeconds % 60;

    return [hours, minutes, seconds];
  }

  // 获取当前状态
  getCurrentState(): CountdownState {
    return {
      isRunning: this.isRunning,
      isPaused: this.isPaused,
      startTime: this.startTime,
      pausedTime: this.pausedTime,
      duration: this.duration,
      remainingTime: this.getTimeRemain()
    };
  }

  // // 获取计时历史
  // getCountdownHistory(): CountdownHistory[] {
  //   return this.countdownHistory.slice(); // 返回副本
  // }

  // 获取总计时时间
  getTotalTimeCount(): number {
    return this.totalTimeCount;
  }

  // 清空历史记录
  clearHistory(): void {
    // this.countdownHistory = [];
    this.totalTimeCount = 0;
    this.markDirty();
    console.info('####### [INFO] Countdown history cleared.');
  }

  // 应用退出时保存数据
  onAppExit(): void {
    console.info('App exiting, saving countdown data to file...');
    // this.stopAutoSave();
    this.stopCountdownTimer();

    // if (this.savePending) {
    //   this.saveToFile();
    // }

    console.log('####### [INFO] countdown service terminated normally #######');
  }

  // 强制立即保存
  // forceSave(): void {
  //   this.saveToFile();
  // }

  // 检查是否已初始化
  isServiceInitialized(): boolean {
    return this.isInitialized;
  }
}

export const countdownService = CountdownService.getInstance();