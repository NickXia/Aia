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

  constructor(id: string, title: string, url: string, isHome: boolean) {
    this.id = id;
    this.title = title;
    this.url = url;
    this.isHome = isHome;
  }
}

/** 与磁盘序列化一致的结构（JSON.parse 结果按此读取） */
export interface RecordJson {
  id: string;
  title: string;
  url: string;
  time: number;
}

/** 主页快捷方式 */
export interface DialItem {
  name: string;
  url: string;
  color: string;
}

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
