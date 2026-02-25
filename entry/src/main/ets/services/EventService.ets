// EventService.ets
import emitter from '@ohos.events.emitter';
import fs from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { util } from '@kit.ArkTS';

// 事件数据结构
export interface  PointEvent {
  id: string;
  title: string;
  description: string;
  deadline: number;
  isDone: boolean;
  createdAt: number;
  finishedAt: number;


}

export function copyPointEvent(src: PointEvent): PointEvent {
  return {
    id: src.id,
    title: src.title,
    description: src.description,
    deadline: src.deadline,
    isDone: src.isDone,
    createdAt: src.createdAt,
    finishedAt: src.finishedAt
  };
}

// Emitter事件数据接口
interface EmitterEventData {
  message: string;
}

function StringToBuffer(str: string): ArrayBuffer {
  const encoder = util.TextEncoder.create('UTF-8')
  const uint8Array = encoder.encodeInto(str)
  return uint8Array.buffer
}

function bufferToString(buffer: ArrayBuffer): string {
  let decoder = util.TextDecoder.create('UTF-8')
  let uint8Array = new Uint8Array(buffer)
  return decoder.decodeToString(uint8Array)
}



class EventService {
  private static instance: EventService;
  private pointEvents: PointEvent[] = [];
  private pointEventSet: Set<string> = new Set();

  private filePath: string = '';
  private context: common.UIAbilityContext | null = null;
  private autoSaveTimer: number = 0;
  private isInitialized: boolean = false;
  private savePending: boolean = false; // 是否有需要保存到磁盘

  private debt: number = 0; // 用于亚毫秒级的创建时间戳
  private last_ts: number = 0;

  /* ========================= 对外参数 ========================== */

  private autoSaveServiceState: boolean = true;
  getAutoSave(): boolean { return this.autoSaveServiceState; }
  setAutoSave(enable: boolean): void {
    if (enable) this.startAutoSave();
    else this.stopAutoSave();
  }

  // 私有构造函数
  private constructor() {}

  // //二进制数据数组转字符串
  // private uint8ArrayToString(array: Uint8Array)  : string{
  //   //设置文字描述类
  //   let textDecoderOptions: util.TextDecoderOptions = {
  //     fatal: false,
  //     ignoreBOM: true
  //   }
  //   //设置文字解码配置类
  //   let decodeToStringOptions: util.DecodeToStringOptions = {
  //     stream: false
  //   }
  //   //创建一个文字解码器
  //   let textDecoder = util.TextDecoder.create('utf-8', textDecoderOptions);
  //   //使用文字解码器对二维数组做解码
  //   let retStr = textDecoder.decodeToString(array, decodeToStringOptions);
  //   console.info('字节流转成可理解的字符串：' + retStr);
  //   return retStr;
  // }

  // 获取单例实例
  public static getInstance(): EventService {
    if (!EventService.instance) {
      EventService.instance = new EventService();
    }
    return EventService.instance;
  }

  // 初始化服务
  initialize(context: common.UIAbilityContext): void {
    if (this.isInitialized) {
      return;
    }

    this.context = context;
    this.filePath = context.filesDir + '/point_events.json';
    this.loadEvents();
    this.startAutoSave();
    this.isInitialized = true;

    console.log('####### [INFO] event service started normally.')
  }

  // 加载事件列表
  private loadEvents(): void {
    try {
      // 正确检查文件是否存在
      if (fs.accessSync(this.filePath)) {
        const file = fs.openSync(this.filePath, fs.OpenMode.READ_ONLY);
        const stat = fs.statSync(file.fd);

        if (stat.size > 0) {
          const arrayBuf: ArrayBuffer = new ArrayBuffer(stat.size);
          const readSize = fs.readSync(file.fd, arrayBuf);

          if (readSize > 0) {
            this.pointEvents = JSON.parse(bufferToString(arrayBuf));
            for (let pe of this.pointEvents)
              this.pointEventSet.add(pe.id)

            console.info('####### [INFO] Events loaded successfully.');
          }
        }

        fs.closeSync(file);
      } else {
        console.info('####### [INFO] Events file does not exist, initializing empty array.');
        this.pointEvents = [];
        this.pointEventSet.clear();
      }
    } catch (error) {
      console.error('####### [WARN] Failed to load events, initializing empty array: ', error, '.');
      this.backupAndInitialize();
    }
  }

  // 备份并初始化
  private backupAndInitialize(): void {
    try {
      if (fs.accessSync(this.filePath)) {
        const backupPath = this.filePath + '.bak';
        fs.copyFileSync(this.filePath, backupPath);
        console.info('Backup created:', backupPath);
      }
    } catch (error) {
      console.warn('Backup failed:', error);
    }
    this.pointEvents = [];
    this.pointEventSet.clear();
  }

  // 保存事件到文件
  private saveToFile(): void {
    if (!this.context) {
      console.error('####### [WARN] Failed to Save to file: eventService not initialized.');
      return;
    }

    try {
      const content = JSON.stringify(this.pointEvents);
      const file = fs.openSync(this.filePath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      const arrayBuffer = StringToBuffer(content);
      fs.writeSync(file.fd, arrayBuffer);
      fs.closeSync(file);
      this.savePending = false;
      console.info('####### [INFO] Events saved to file.');
    } catch (error) {
      console.error('####### [WARN] Failed to save events: ', error, '.');
    }
  }

  // 开始自动保存
  private startAutoSave(): void {
    // 每30秒自动保存一次
    this.autoSaveTimer = setInterval(() => {
      if (this.savePending) {
        this.saveToFile();
      }
    }, 30000) as number;
    this.autoSaveServiceState = true
  }

  // 停止自动保存
  private stopAutoSave(): void {
    this.autoSaveServiceState = false
    if (this.autoSaveTimer) {
      clearInterval(this.autoSaveTimer);
      this.autoSaveTimer = 0;
    }
  }

  // 标记需要保存并触发变更事件
  private markDirty(): void {
    this.savePending = true;
    this.emitChangeEvent();
  }

  deprecateAllEvent() {
    this.pointEvents = []; // 清空点事件列表
    this.pointEventSet.clear()

    this.saveToFile();
    this.markDirty();
    console.log('####### [INFO] All point events is deprecated.')
  }

  private genID(): string {
    const ts = Date.now()
    const dt = ts - this.last_ts

    if (dt === 0) { this.debt++; }
    else {
      this.debt = this.debt - dt > 0 ? this.debt - dt : 0
    }
    // 格式：毫秒时间戳 13位字符串
    return (ts+this.debt).toString();
  }

  // 添加事件
  addEvent(title: string, description: string, deadline: number): void {
    if (title === '') {
      title = description.substring(0, 10)
    }
    const nid = this.genID()
    const newEvent: PointEvent = {
      id: nid,
      title,
      description,
      deadline,
      isDone: false,
      createdAt: Date.now(),
      finishedAt: -1
    };
    this.pointEvents.push(newEvent);
    this.pointEventSet.add(nid);
    this.markDirty();
    console.info('####### [INFO] PointEvent with id', nid, ' is created and added to list.');
  }

  // 切换完成状态
  toggleDone(id: string): void {
    const event = this.pointEvents.find(e => e.id === id);
    if (event) {
      event.isDone = !event.isDone;
      if (event.isDone) {
        event.finishedAt = Date.now()
      }
      else {
        event.finishedAt = -1
      }
      this.markDirty();
    }
  }

  // 更新事件
  updateEvent(id: string, updates: Partial<PointEvent>): void {
    const oriEvent = this.pointEvents.find(e => e.id === id);
    if (oriEvent) {
      if (updates.description !== undefined) {
        // console.log('AAAAAAA Replace description with ', updates.description)
        oriEvent.description = updates.description;
      }
      if (updates.deadline !== undefined) {
        oriEvent.deadline = updates.deadline;
      }
      if (updates.isDone !== undefined) {
        oriEvent.isDone = updates.isDone;
      }
      if (updates.title !== undefined) {
        console.log('AAAAAAA Replace title with ', updates.title)
        oriEvent.title = updates.title;
      }
      this.markDirty();
      console.log('####### [INFO] Event with id ', id, ' is updated.')
    }
    else {
      console.log('####### [WARNING] Update event not find, deprecate this update.')
    }

  }

  haveEvent(id: string): boolean {
    return this.pointEventSet.has(id);
  }

  // 删除事件
  deleteEvent(id: string): void {
    const index = this.pointEvents.findIndex(e => e.id === id);
    if (index !== -1) {
      this.pointEvents.splice(index, 1);
      this.pointEventSet.delete(id);
      this.markDirty();
    }
    console.log('####### [INFO] Event with id ', id, ' is deleted #######')
  }

  // 获取未完成事件（按deadline排序）
  getPendingEvents(): PointEvent[] {
    return this.pointEvents.slice()
      .filter(event => !event.isDone)
      .sort((a, b) => a.deadline - b.deadline);
  }

  // 获取已完成事件
  getOutDatedEvent(): PointEvent[] {
    return this.pointEvents.slice()
      .filter(event => event.isDone)
      .sort((a, b) => a.deadline - b.deadline);
  }

  // 获取所有事件
  getAllEvents(): PointEvent[] {
    return this.pointEvents.slice(); // 返回副本
  }

  // 获取快照
  getSnapshot(): PointEvent[] {
    return this.pointEvents.slice(); // 返回副本
  }

  // 发射变更事件
  private emitChangeEvent(): void {
    const eventData: emitter.InnerEvent = {
      eventId: 1,
      priority: emitter.EventPriority.HIGH
    };

    const emitterData: EmitterEventData = {
      message: "pointEventsChanged"
    };

    emitter.emit(eventData, { data: emitterData });
  }

  // 应用退出时保存数据
  onAppExit(): void {
    console.info('App exiting, saving events to file...');
    this.stopAutoSave();
    if (this.savePending) {
      this.saveToFile();
    }

    console.log('####### [INFO] schedule service terminated normally #######')
  }

  // 强制立即保存
  forceSave(): void {
    this.saveToFile();
  }

  // 检查是否已初始化
  isServiceInitialized(): boolean {
    return this.isInitialized;
  }
}

export const eventService = EventService.getInstance();