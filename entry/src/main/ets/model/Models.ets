import { webview } from '@kit.ArkWeb';

/**
 * 一个标签页。字段变化需要驱动 UI，所以用 @Observed，
 * 子组件通过 @ObjectLink 订阅。
 */
@Observed
export class BrowserTab {
  id: string;
  /** 空字符串表示新标签页（显示 Aia 主页） */
  url: string = '';
  title: string = '';
  isLoading: boolean = false;
  progress: number = 0;
  canGoBack: boolean = false;
  canGoForward: boolean = false;
  /** 最近一次导航发起的时间戳 */
  lastNavTime: number = 0;
  /** 返回键按下后置位：下一个 about:blank pageEnd 代表「退到占位页」，应回主页 */
  expectBlankHome: boolean = false;
  /** 本次导航是否收到过 onPageBegin（ArkWeb 对 DNS 失败等场景静默无回调，用于超时判定） */
  pageBeginSeen: boolean = false;
  /** 本次导航是否发生过资源加载错误（HTTP 404/超时等），用于过滤失败页入历史 */
  loadError: boolean = false;
  /** 弱网自动重试：本次导航是否已自动重试过一次 */
  retriedOnce: boolean = false;
  /** 看门狗内容探测进行中：防止每次 tick 叠发探针 */
  probeBusy: boolean = false;
  /** 用户手动停止了加载：看门狗不再自动重试，下次导航时清除 */
  userStopped: boolean = false;
  /** 活动主文档加载失败（WebPane 写入）：所有权在标签上，不再走 AppStorage 幽灵键（ADR-2） */
  loadFailed: boolean = false;
  /** 无痕标签：不写历史记录；地址栏/标签卡有标识 */
  incognito: boolean = false;
  /** Web 内核 attach 完成时刻：navigate 首次 loadUrl 需距此 600ms 以上，
   *  否则首帧合成丢失（DOM 完整但 surface 空白，实测 attach 同帧导航必现） */
  attachedAt: number = 0;
  controller: webview.WebviewController | null = null;

  constructor(id: string) {
    this.id = id;
  }

  get isHome(): boolean {
    return this.url.length === 0;
  }
}

export class Bookmark {
  id: string = '';
  title: string = '';
  url: string = '';
  time: number = 0;

  constructor(id: string, title: string, url: string, time: number) {
    this.id = id;
    this.title = title;
    this.url = url;
    this.time = time;
  }
}

export class HistoryEntry {
  id: string = '';
  title: string = '';
  url: string = '';
  time: number = 0;

  constructor(id: string, title: string, url: string, time: number) {
    this.id = id;
    this.title = title;
    this.url = url;
    this.time = time;
  }
}

/**
 * 标签页的只读快照。标签面板只用于展示，
 * 传快照可以避免把 WebviewController 一起深拷贝。
 */
export class TabInfo {
  id: string = '';
  title: string = '';
  url: string = '';
  isHome: boolean = true;
  incognito: boolean = false;

  constructor(id: string, title: string, url: string, isHome: boolean, incognito: boolean = false) {
    this.id = id;
    this.title = title;
    this.url = url;
    this.isHome = isHome;
    this.incognito = incognito;
  }
}

/** 与磁盘序列化一致的结构（JSON.parse 结果按此读取） */
export interface RecordJson {
  id: string;
  title: string;
  url: string;
  time: number;
}

/**
 * 下载型导航的错误忽略状态（ADR-2：取代 dlNavAt/dlPicking 两个 AppStorage 幽灵键）。
 * 所有权归 Index（下载生命周期管理者），构造 WebPane 时按引用传入；
 * onErrorReceive 是事件驱动读取，不需要响应式——普通可变对象即可。
 */
export class DownloadNavGate {
  /** 下载前选择器存活期间：无条件忽略主文档补发错误 */
  picking: boolean = false;
  /** 下载导航 start 时刻：之后 DL_ERROR_WINDOW_MS 内的补发错误忽略 */
  navAt: number = 0;
}

/** 主页快捷方式 */
/** 下载任务状态：progressing / paused / done / failed / canceled */
@Observed
export class DownloadItem {
  guid: string;
  url: string;
  fileName: string;
  path: string;
  total: number;
  received: number;
  speed: number;
  state: string;
  time: number;
  /** 下载完成后导出到公共 Download 的 uri（文件管理可见） */
  publicUri: string = '';

  constructor(guid: string, url: string, fileName: string, path: string) {
    this.guid = guid;
    this.url = url;
    this.fileName = fileName;
    this.path = path;
    this.total = 0;
    this.received = 0;
    this.speed = 0;
    this.state = 'progressing';
    this.time = Date.now();
  }
}
