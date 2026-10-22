import { promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { DownloadsPanel } from '../view/DownloadsPanel';
import { DownloadItem } from '../model/Models';
import { pasteboard } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { BrowserTab, Bookmark, HistoryEntry, TabInfo, DialItem } from '../model/Models';
import { ENGINES, SearchEngine } from '../common/SearchEngine';
import { hostOf, resolveInput, isSecure, colorForHost } from '../common/UrlUtils';
import { AiaStore } from '../common/Storage';
import { setUiScale, getUiScale, setThemeMode, getThemeMode } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';
import { WebPane } from '../view/WebPane';
import { HomeView } from '../view/HomeView';
import { AddressBar } from '../view/AddressBar';
import { BottomBar } from '../view/BottomBar';
import { MenuSheet } from '../view/MenuSheet';
import { TabsPanel } from '../view/TabsPanel';
import { DialEditSheet } from '../view/DialEditSheet';
import { RecordsPanel } from '../view/RecordsPanel';
import { SettingsPanel } from '../view/SettingsPanel';

@Entry
@Component
struct Index {
  // ------------------------------------------------------------------ 状态
  @State tabs: BrowserTab[] = [];
  @State activeId: string = '';
  @State showHome: boolean = true;

  @State bookmarks: Bookmark[] = [];
  @State history: HistoryEntry[] = [];

  @State engineIndex: number = 0;
  @State homepage: string = 'https://www.baidu.com';
  @State blockImages: boolean = false;
  @State saveHistory: boolean = true;
  @State jsEnabled: boolean = true;
  @State dnt: boolean = true;
  @State bgImage: string = '';
  @State topAvoid: number = 0;
  @State bottomAvoid: number = 0;
  /** 活动标签的加载进度（0-100），由 WebPane 通过 AppStorage 实时同步 */
  @StorageLink('loadingPct') loadingPct: number = 100;

  @State menuVisible: boolean = false;
  @State tabsVisible: boolean = false;
  @State recordsVisible: boolean = false;
  @State settingsVisible: boolean = false;
  @State recordsMode: string = 'bookmark';
  @State elderMode: boolean = false;
  @State dials: DialItem[] = [];
  @State dialEditorVisible: boolean = false;
  @State dialEditing: DialItem | null = null;
  /** 递增以整树重建 UI（关怀模式切换字号后必须重建才能生效） */
  @State uiEpoch: number = 0;
  /** 阅读模式（羊皮卷主题） */
  @State readingTheme: boolean = false;
  /** 系统深浅色变化时递增（EntryAbility 写入），驱动整树重建取新色 */
  @StorageLink('themeEpoch') themeEpoch: number = 0;
  /** 活动标签网页加载失败（WebPane 写入），显示错误出路 */
  @StorageLink('loadFailed') loadFailed: boolean = false;
  @State downloads: DownloadItem[] = AiaStore.loadDownloads();
  @State downloadsVisible: boolean = false;
  @State desktopUA: boolean = AiaStore.desktopUA;
  private downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  // delegate 本体在 Index 管理（状态/持久化都在这），WebPane 创建内核时
  // 通过 AppStorage 取到并 controller.setDownloadDelegate 注册——
  // 此前漏了注册这一步，网页下载事件无人接收

  private seq: number = 0;

  // -------------------------------------------------------------- 生命周期
  aboutToAppear(): void {
    this.engineIndex = AiaStore.engineIndex;
    this.homepage = AiaStore.homepage;
    this.blockImages = AiaStore.blockImages;
    this.saveHistory = AiaStore.saveHistory;
    this.jsEnabled = AiaStore.javaScriptEnabled;
    this.dnt = AiaStore.doNotTrack;
    this.bgImage = AiaStore.bgImage;
    this.dials = AiaStore.loadDials();
    // 关怀模式：先设缩放因子再建 UI，首帧即是大字版
    this.elderMode = AiaStore.elderMode;
    if (this.elderMode) {
      setUiScale(1.25);
    }
    // 阅读模式（羊皮卷主题）
    this.desktopUA = AiaStore.desktopUA;
    this.readingTheme = AiaStore.readingTheme;
    if (this.readingTheme) {
      setThemeMode('parchment');
    }
    // 下载委托：全局注册一次，网页触发的下载统一走这里
    // delegate 通过 AppStorage 共享给各 WebPane（内核创建时 setDownloadDelegate 注册）
    AppStorage.setOrCreate<webview.WebDownloadDelegate>('downloadDelegate', this.downloadDelegate);
    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      const url: string = item.getUrl();
      let name: string = url.substring(url.lastIndexOf('/') + 1).split('?')[0];
      if (name.length === 0) {
        name = 'download_' + Date.now();
      }
      const dir: string = getContext(this).filesDir + '/downloads';
      try {
        fileIo.mkdirSync(dir, true);
      } catch (err) {
        // 目录已存在
      }
      const path: string = dir + '/' + name;
      const d: DownloadItem = new DownloadItem(item.getGuid(), url, name, path);
      const list: DownloadItem[] = this.downloads.slice();
      list.unshift(d);
      this.downloads = AiaStore.trimDownloads(list);
      AiaStore.saveDownloads(this.downloads);
      item.start(path);
      promptAction.showToast({ message: '开始下载：' + name });
    });
    this.downloadDelegate.onDownloadUpdated((item: webview.WebDownloadItem) => {
      for (let i = 0; i < this.downloads.length; i++) {
        if (this.downloads[i].guid === item.getGuid()) {
          this.downloads[i].received = item.getReceivedBytes();
          this.downloads[i].total = item.getTotalBytes();
          this.downloads[i].speed = item.getCurrentSpeed();
          const st: webview.WebDownloadState = item.getState();
          if (st === webview.WebDownloadState.PAUSED) {
            this.downloads[i].state = 'paused';
          }
          const action: string = WebPendingAction.consume(item.getGuid());
          if (action === 'pause') {
            item.pause();
          } else if (action === 'resume') {
            item.resume();
          } else if (action === 'cancel') {
            item.cancel();
          }
          break;
        }
      }
    });
    this.downloadDelegate.onDownloadFinish((item: webview.WebDownloadItem) => {
      for (let i = 0; i < this.downloads.length; i++) {
        if (this.downloads[i].guid === item.getGuid()) {
          this.downloads[i].state = 'done';
          this.downloads[i].received = item.getTotalBytes();
          this.downloads[i].total = item.getTotalBytes();
          this.downloads[i].path = item.getFullPath();
          break;
        }
      }
      AiaStore.saveDownloads(this.downloads);
      promptAction.showToast({ message: '下载完成' });
    });
    this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      for (let i = 0; i < this.downloads.length; i++) {
        if (this.downloads[i].guid === item.getGuid()) {
          this.downloads[i].state = 'failed';
          break;
        }
      }
      AiaStore.saveDownloads(this.downloads);
    });
    // 空白页看门狗：任何未知路径把应用留在占位页超过 1.6 秒，自动回主页。
    // 覆盖系统边缘返回手势等无法穷举的时序，保证用户永远不会面对白屏。
    setInterval(() => this.blankWatchdog(), 700);
    // 全屏布局下按系统避让高度留白（px -> vp）
    const topPx: number = AppStorage.get<number>('topAvoidPx') ?? 0;
    const bottomPx: number = AppStorage.get<number>('bottomAvoidPx') ?? 0;
    this.topAvoid = px2vp(topPx);
    this.bottomAvoid = px2vp(bottomPx);
    this.bookmarks = AiaStore.loadBookmarks();
    this.history = AiaStore.loadHistory();
    // 清理历史版本的 bug 混进来的 about:blank 占位记录
    const kept: HistoryEntry[] = [];
    for (let i = 0; i < this.history.length; i++) {
      if (!this.history[i].url.startsWith('about:') && this.history[i].title !== 'about:blank') {
        kept.push(this.history[i]);
      }
    }
    if (kept.length !== this.history.length) {
      this.history = kept;
      AiaStore.saveHistoryList(kept);
    }

    const pending: string = AppStorage.get<string>('launchUrl') ?? '';
    const first: BrowserTab = this.newTab();
    this.activeId = first.id;
    this.showHome = true;
    if (pending.length > 0) {
      AppStorage.set<string>('launchUrl', '');
      // 等第一帧渲染完再加载，确保 Web 组件已挂载
      setTimeout(() => {
        this.navigate(pending);
      }, 60);
    }
  }

  /** 空白页看门狗：非主页状态下停留在占位页且无加载活动 → 自愈回主页 */
  private blankWatchdog(): void {
    if (this.showHome || this.loadFailed || this.dialEditorVisible || this.menuVisible
      || this.settingsVisible || this.recordsVisible || this.tabsVisible) {
      return;
    }
    const tab: BrowserTab = this.activeTab();
    if (tab.controller === null) {
      return;
    }
    try {
      const u: string = tab.controller.getUrl();
      const idle: boolean = !tab.isLoading && !tab.expectBlankHome;
      const fresh: boolean = Date.now() - tab.lastNavTime < 1600;
      if ((u === 'about:blank' || u.length === 0) && idle && !fresh) {
        this.goHome();
        return;
      }
      // ArkWeb 对 DNS 解析失败等场景静默无回调：导航 15 秒后仍无任何
      // pageBegin 且无加载活动 → 判定加载失败，弹错误卡给出出路
      if (!tab.isLoading && !tab.pageBeginSeen && !this.loadFailed
        && Date.now() - tab.lastNavTime > 15000) {
        AppStorage.setOrCreate<boolean>('loadFailed', true);
      }
    } catch (err) {
      // 内核状态不可读时跳过本轮
    }
  }

  onBackPress(): boolean {    if (this.dialEditorVisible) {      this.dialEditorVisible = false;
      return true;
    }
    if (this.menuVisible) {
      this.menuVisible = false;
      return true;
    }
    if (this.tabsVisible) {
      this.tabsVisible = false;
      return true;
    }
    if (this.downloadsVisible) {
      this.downloadsVisible = false;
      return true;
    }
    if (this.recordsVisible) {
      this.recordsVisible = false;
      return true;
    }
    if (this.settingsVisible) {
      this.settingsVisible = false;
      return true;
    }
    const tab: BrowserTab = this.activeTab();
    if (!this.showHome && tab.controller !== null) {
      try {
        // 实时查询，避免状态滞后导致系统返回失效
        if (tab.controller.accessBackward()) {
          tab.expectBlankHome = true; // 与底栏返回键行为一致
          tab.controller.backward();
          return true;
        }
      } catch (err) {
        // ignore
      }
    }
    if (!this.showHome) {
      this.goHome();
      return true;
    }
    return false;
  }

  // ------------------------------------------------------------ 标签页管理
  private nextId(): string {
    this.seq = this.seq + 1;
    return 't' + Date.now().toString() + '_' + this.seq.toString();
  }

  private newTab(): BrowserTab {
    const tab: BrowserTab = new BrowserTab(this.nextId());
    const list: BrowserTab[] = this.tabs.slice();
    list.push(tab);
    this.tabs = list;
    return tab;
  }

  private activeTab(): BrowserTab {
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].id === this.activeId) {
        return this.tabs[i];
      }
    }
    return this.tabs.length > 0 ? this.tabs[0] : new BrowserTab('placeholder');
  }

  private tabInfos(): TabInfo[] {
    const infos: TabInfo[] = [];
    for (let i = 0; i < this.tabs.length; i++) {
      const t: BrowserTab = this.tabs[i];
      infos.push(new TabInfo(t.id, t.title, t.url, t.url.length === 0));
    }
    return infos;
  }

  private createTab(): void {
    const tab: BrowserTab = this.newTab();
    this.activeId = tab.id;
    this.showHome = true;
    this.tabsVisible = false;
  }

  private activate(id: string): void {
    this.activeId = id;
    this.showHome = this.tabById(id).url.length === 0;
    this.tabsVisible = false;
  }

  private tabById(id: string): BrowserTab {
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].id === id) {
        return this.tabs[i];
      }
    }
    return this.activeTab();
  }

  private closeTab(id: string): void {
    if (this.tabs.length === 1) {
      // 最后一个标签不真的关掉，重置成新标签页更符合直觉
      const only: BrowserTab = this.tabs[0];
      only.url = '';
      only.title = '';
      this.showHome = true;
      if (only.controller !== null) {
        only.controller.loadUrl('about:blank');
        try {
          only.controller.clearHistory();
        } catch (err) {
          // ignore
        }
      }
      this.tabsVisible = false;
      return;
    }
    const rest: BrowserTab[] = [];
    for (let i = 0; i < this.tabs.length; i++) {
      if (this.tabs[i].id !== id) {
        rest.push(this.tabs[i]);
      }
    }
    const wasActive: boolean = this.activeId === id;
    this.tabs = rest;
    if (wasActive) {
      const next: BrowserTab = rest[rest.length - 1];
      this.activeId = next.id;
      this.showHome = next.url.length === 0;
    }
    this.tabsVisible = false;
  }

  private closeAllTabs(): void {
    // 直接换成一个全新的标签，旧的 Web 组件由 ForEach 回收
    const fresh: BrowserTab = new BrowserTab(this.nextId());
    this.tabs = [fresh];
    this.activeId = fresh.id;
    this.showHome = true;
    this.tabsVisible = false;
  }

  // -------------------------------------------------------------- 页面导航
  private navigate(input: string): void {
    const target: string = resolveInput(input, ENGINES[this.engineIndex]);
    console.info('AiaNav navigate input=' + input + ' target=' + target);
    if (target.length === 0) {
      return;
    }
    this.showHome = false;
    const tab: BrowserTab = this.activeTab();
    tab.url = target;
    tab.title = hostOf(target);
    tab.canGoBack = false;
    tab.canGoForward = false;
    tab.lastNavTime = Date.now();
    tab.pageBeginSeen = false;
    tab.loadError = false;
    tab.expectBlankHome = false;
    AppStorage.setOrCreate<boolean>('loadFailed', false);
    tab.progress = 0;
    tab.isLoading = true;
    AppStorage.setOrCreate<number>('loadingPct', 0);
    if (tab.controller !== null) {
      try {
        tab.controller.loadUrl(target);
        console.info('AiaNav loadUrl ok');
      } catch (err) {
        console.error('AiaNav loadUrl FAILED: ' + JSON.stringify(err));
      }
    } else {
      console.error('AiaNav controller is null');
    }
  }

  private goHome(): void {
    const tab: BrowserTab = this.activeTab();
    tab.url = '';
    tab.title = '';
    tab.canGoBack = false;
    tab.canGoForward = false;
    this.showHome = true;
    if (tab.controller !== null) {
      tab.controller.loadUrl('about:blank');
      // 清空网页历史：避免占位页/重定向垃圾滞留栈内，
      // 让「进入网页 → 返回」始终一步回主页，且下次返回语义干净
      try {
        tab.controller.clearHistory();
      } catch (err) {
        // ignore
      }
    }
  }

  private reload(): void {
    const tab: BrowserTab = this.activeTab();
    if (tab.controller === null) {
      return;
    }
    try {
      if (tab.isLoading) {
        tab.controller.stop();
      } else {
        tab.controller.refresh();
      }
    } catch (err) {
      // ignore
    }
  }

  private goBack(): void {
    // 主页态按返回无意义，还会白白清掉前进栈
    if (this.showHome) {
      return;
    }
    const tab: BrowserTab = this.activeTab();
    if (tab.controller === null) {
      return;
    }
    try {
      // 点击时实时查询内核，不依赖可能滞后的状态标记
      if (tab.controller.accessBackward()) {
        const target: string = tab.controller.getUrl();
        tab.expectBlankHome = true; // 下一个占位页结束事件 = 主动返回，回主页
        tab.controller.backward();
        // 竞态兜底：极速返回时页面可能停在占位页且不再派发结束事件，
        // 900ms 后仍在空白则直接回主页
        setTimeout(() => {
          try {
            if (!this.showHome && tab.id === this.activeId && tab.controller !== null) {
              const u: string = tab.controller.getUrl();
              if (u === 'about:blank' || u.length === 0) {
                this.goHome();
              }
            }
          } catch (err) {
            // ignore
          }
        }, 900);
      } else {
        this.goHome();
      }
    } catch (err) {
      // ignore
    }
  }

  private goForward(): void {
    const tab: BrowserTab = this.activeTab();
    if (tab.controller === null) {
      return;
    }
    try {
      if (tab.controller.accessForward()) {
        tab.controller.forward();
      }
    } catch (err) {
      // ignore
    }
  }

  // ------------------------------------------------------------ 书签与历史
  private isBookmarked(): boolean {
    const url: string = this.activeTab().url;
    if (url.length === 0) {
      return false;
    }
    for (let i = 0; i < this.bookmarks.length; i++) {
      if (this.bookmarks[i].url === url) {
        return true;
      }
    }
    return false;
  }

  private toggleBookmark(): void {
    const tab: BrowserTab = this.activeTab();
    if (tab.url.length === 0) {
      promptAction.showToast({ message: '新标签页无需收藏' });
      return;
    }
    const url: string = tab.url;
    const rest: Bookmark[] = [];
    let removed: boolean = false;
    for (let i = 0; i < this.bookmarks.length; i++) {
      if (this.bookmarks[i].url === url) {
        removed = true;
      } else {
        rest.push(this.bookmarks[i]);
      }
    }
    if (removed) {
      this.bookmarks = rest;
      promptAction.showToast({ message: '已取消收藏' });
    } else {
      const title: string = tab.title.length > 0 ? tab.title : hostOf(url);
      const item: Bookmark = new Bookmark(this.nextId(), title, url, Date.now());
      const list: Bookmark[] = this.bookmarks.slice();
      list.unshift(item);
      this.bookmarks = list;
      promptAction.showToast({ message: '已加入书签' });
    }
    AiaStore.saveBookmarks(this.bookmarks);
  }

  private recordHistory(tab: BrowserTab): void {
    if (!this.saveHistory || tab.url.length === 0) {
      return;
    }
    if (tab.loadError) {
      return; // 加载失败的页面不进历史（HTTP 错误页/超时页）
    }
    if (tab.url.startsWith('about:') || tab.title === 'about:blank') {
      return;
    }
    if (tab.id !== this.activeId) {
      return;
    }
    const list: HistoryEntry[] = [];
    for (let i = 0; i < this.history.length; i++) {
      if (this.history[i].url !== tab.url) {
        list.push(this.history[i]);
      }
    }
    const title: string = tab.title.length > 0 ? tab.title : hostOf(tab.url);
    list.unshift(new HistoryEntry(this.nextId(), title, tab.url, Date.now()));
    this.history = list.length > 200 ? list.slice(0, 200) : list;
    AiaStore.saveHistoryList(this.history);
  }

  private records(): HistoryEntry[] {
    const list: HistoryEntry[] = [];
    if (this.recordsMode === 'history') {
      return this.history;
    }
    for (let i = 0; i < this.bookmarks.length; i++) {
      const b: Bookmark = this.bookmarks[i];
      list.push(new HistoryEntry(b.id, b.title, b.url, b.time));
    }
    return list;
  }

  private deleteRecord(id: string): void {
    if (this.recordsMode === 'history') {
      const rest: HistoryEntry[] = [];
      for (let i = 0; i < this.history.length; i++) {
        if (this.history[i].id !== id) {
          rest.push(this.history[i]);
        }
      }
      this.history = rest;
      AiaStore.saveHistoryList(rest);
    } else {
      const rest: Bookmark[] = [];
      for (let i = 0; i < this.bookmarks.length; i++) {
        if (this.bookmarks[i].id !== id) {
          rest.push(this.bookmarks[i]);
        }
      }
      this.bookmarks = rest;
      AiaStore.saveBookmarks(rest);
    }
  }

  // ------------------------------------------------------------ 下载管理
  private pauseResumeDownload(guid: string, toPause: boolean): void {
    const delegate = this.downloadDelegate;
    // 通过 WebDownloadManager 查找活动任务进行暂停/继续：
    // ArkWeb 的暂停/继续需要在 delegate 回调持有的 item 上调用，
    // 因此这里记录 pending 动作，由下一次 onDownloadUpdated 驱动。
    for (let i = 0; i < this.downloads.length; i++) {
      if (this.downloads[i].guid === guid) {
        this.downloads[i].state = toPause ? 'paused' : 'progressing';
        break;
      }
    }
    AiaStore.saveDownloads(this.downloads);
    WebPendingAction.set(guid, toPause ? 'pause' : 'resume');
  }

  private cancelDownload(guid: string): void {
    WebPendingAction.set(guid, 'cancel');
    for (let i = 0; i < this.downloads.length; i++) {
      if (this.downloads[i].guid === guid) {
        this.downloads[i].state = 'canceled';
        break;
      }
    }
    AiaStore.saveDownloads(this.downloads);
  }

  private deleteDownload(guid: string): void {
    const rest: DownloadItem[] = [];
    for (let i = 0; i < this.downloads.length; i++) {
      if (this.downloads[i].guid !== guid) {
        rest.push(this.downloads[i]);
      }
    }
    this.downloads = rest;
    AiaStore.saveDownloads(this.downloads);
  }

  /** 危险操作二次确认：确认后执行 confirm()，取消不动作 */
  private confirmThen(title: string, message: string, confirm: () => void): void {
    const dialog = promptAction.showDialog({
      title: title,
      message: message,
      buttons: [
        { text: '取消', color: '#8A8270' },
        { text: '确定', color: '#B4552E' }
      ]
    });
    dialog.then((result) => {
      if (result.index === 1) {
        confirm();
      }
    }).catch(() => {
    });
  }

  private clearRecords(): void {
    const isHistory: boolean = this.recordsMode === 'history';
    this.confirmThen('确认清空', isHistory ? '将清空全部浏览记录，此操作不可恢复。' : '将清空全部书签，此操作不可恢复。', () => {
      if (isHistory) {
        this.history = [];
        AiaStore.clearHistory();
      } else {
        this.bookmarks = [];
        AiaStore.saveBookmarks([]);
      }
    });
  }

  private async copyUrl(): Promise<void> {
    const url: string = this.activeTab().url;
    if (url.length === 0) {
      promptAction.showToast({ message: '没有可复制的链接' });
      return;
    }
    try {
      const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, url);
      await pasteboard.getSystemPasteboard().setData(data);
      promptAction.showToast({ message: '链接已复制' });
    } catch (err) {
      promptAction.showToast({ message: '复制失败' });
    }
  }

  // ------------------------------------------------------------ 自定义背景
  private extOf(uri: string): string {
    const dot: number = uri.lastIndexOf('.');
    if (dot < 0 || dot === uri.length - 1) {
      return 'img';
    }
    const ext: string = uri.substring(dot + 1).toLowerCase();
    if (ext.length > 0 && ext.length <= 5) {
      return ext;
    }
    return 'img';
  }

  /** 沙箱路径 -> 应用内 file:// URI（Image 组件显示沙箱图片的标准方式） */
  private bgUri(): string {
    if (this.bgImage.length === 0) {
      return '';
    }
    try {
      return fileUri.getUriFromPath(this.bgImage);
    } catch (err) {
      return 'file://' + this.bgImage;
    }
  }

  private async pickBackground(): Promise<void> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length === 0) {
        return;
      }
      const src: string = result.photoUris[0];
      // 兼容性处理：无论原图在何处、什么格式，一律拷贝进应用沙箱再使用，
      // 避免媒体库临时授权过期后图片无法再次加载。
      const srcFile: fileIo.File = fileIo.openSync(src, fileIo.OpenMode.READ_ONLY);
      try {
        const stat: fileIo.Stat = fileIo.statSync(srcFile.fd);
        if (stat.size <= 0 || stat.size > 25 * 1024 * 1024) {
          promptAction.showToast({ message: '图片大小需在 25MB 以内' });
          return;
        }
        const dst: string = getContext(this).filesDir + '/home_bg.' + this.extOf(src);
        // 必须用同步拷贝：异步版本未 await 会拷出 0 字节文件
        fileIo.copyFileSync(srcFile.fd, dst);
        const st: fileIo.Stat = fileIo.statSync(dst);
        console.info('AiaBg copied to ' + dst + ' size=' + st.size);
        if (st.size <= 0) {
          promptAction.showToast({ message: '图片拷贝失败，请重试' });
          return;
        }
        this.bgImage = dst;
        AiaStore.bgImage = dst;
        promptAction.showToast({ message: '背景已更新' });
      } finally {
        fileIo.closeSync(srcFile);
      }
    } catch (err) {
      promptAction.showToast({ message: '选择图片失败' });
    }
  }

  private clearBackground(): void {
    this.bgImage = '';
    AiaStore.bgImage = '';
  }

  // ------------------------------------------------------ 快捷方式编辑
  private saveDial(name: string, url: string): void {
    if (name.length === 0 || url.length === 0) {
      promptAction.showToast({ message: '名称和网址都不能为空' });
      return;
    }
    let target: string = url;
    if (!/^https?:\/\//.test(target)) {
      target = 'https://' + target;
    }
    const color: string = colorForHost(hostOf(target));
    const d: DialItem = { name: name, url: target, color: color };
    const list: DialItem[] = this.dials;
    if (this.dialEditing !== null) {
      for (let i = 0; i < list.length; i++) {
        if (list[i].url === this.dialEditing.url) {
          list[i] = d;
          break;
        }
      }
    } else {
      list.push(d);
    }
    this.dials = list;
    AiaStore.saveDials(list);
    this.dialEditorVisible = false;
    promptAction.showToast({ message: '已保存' });
  }

  private deleteDial(): void {
    if (this.dialEditing === null) {
      return;
    }
    const list: DialItem[] = [];
    for (let i = 0; i < this.dials.length; i++) {
      if (this.dials[i].url !== this.dialEditing.url) {
        list.push(this.dials[i]);
      }
    }
    this.dials = list;
    AiaStore.saveDials(list);
    this.dialEditorVisible = false;
    promptAction.showToast({ message: '已删除' });
  }

  /** 网页加载失败后的重试 */
  private retryActive(): void {
    AppStorage.setOrCreate<boolean>('loadFailed', false);
    const tab: BrowserTab = this.activeTab();
    if (tab.controller === null) {
      return;
    }
    try {
      if (tab.pageBeginSeen) {
        // 内核已开始加载（HTTP 错误等）：刷新当前页即可
        tab.loadError = false;
        tab.controller.refresh();
      } else {
        // 静默失败（DNS 解析失败等）：refresh 无效，必须重新导航
        this.navigate(tab.url);
      }
    } catch (err) {
      // ignore
    }
  }

  // ------------------------------------------------------------------ 菜单
  private handleMenu(key: string): void {
    this.menuVisible = false;
    if (key === 'bookmarks') {
      this.recordsMode = 'bookmark';
      this.recordsVisible = true;
    } else if (key === 'history') {
      this.recordsMode = 'history';
      this.recordsVisible = true;
    } else if (key === 'add') {
      this.toggleBookmark();
    } else if (key === 'copy') {
      this.copyUrl();
    } else if (key === 'downloads') {
      this.downloadsVisible = true;
    } else if (key === 'reload') {
      this.reload();
    } else if (key === 'home') {
      this.goHome();
    } else if (key === 'settings') {
      this.settingsVisible = true;
    } else if (key === 'close') {
      const t: BrowserTab = this.activeTab();
      if (t.url.length === 0) {
        this.closeTab(t.id); // 空标签直接关
      } else {
        this.confirmThen('关闭标签', '将关闭「' + (t.title.length > 0 ? t.title : t.url) + '」，确认关闭？', () => {
          this.closeTab(t.id);
        });
      }
    }
  }

  private handleAction(action: string): void {
    if (action === 'back') {
      this.goBack();
    } else if (action === 'forward') {
      this.goForward();
    } else if (action === 'home') {
      this.goHome();
    } else if (action === 'tabs') {
      this.tabsVisible = true;
    } else if (action === 'menu') {
      this.menuVisible = true;
    }
  }

  private handlePageStart(tab: BrowserTab): void {
    // WebPane 已过滤 about:blank 占位页，能走到这里的一定是真实页面：
    // 前进键恢复的页面也要把主页切走，否则网页和主页会叠在一起
    if (tab.id === this.activeId) {
      this.showHome = false;
    }
  }

  private handlePageFinished(tab: BrowserTab): void {
    console.info('AiaNav pageFinished url=' + tab.url + ' active=' + (tab.id === this.activeId));
    // 网页历史的第一条是 about:blank 占位页，返回键退到这里时
    // 直接回主页，而不是停在一页空白
    if (tab.id === this.activeId && tab.url.length === 0) {
      this.showHome = true;
    }
    this.recordHistory(tab);
  }

  // ------------------------------------------------------------------ UI
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // uiEpoch 变化 → 键变化 → 整树按新缩放因子重建（关怀模式切换）
      ForEach([this.uiEpoch], (_: number) => {
      // 自定义背景铺满全屏（延伸到状态栏/手势条底下）
      if (this.bgImage.length > 0) {
        Image(this.bgUri())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .autoResize(true)

        // 可读性遮罩：保证墨色文字在任意图片上都清晰
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(C('page_bg'))
          .opacity(0.72)
      }

      Column() {
        AddressBar({
          tab: this.activeTab(),
          home: this.showHome,
          onSubmit: (text: string) => this.navigate(text)
        })

        Stack() {
          ForEach(this.tabs, (tab: BrowserTab) => {
            WebPane({
              tab: tab,
              active: tab.id === this.activeId,
              blockImages: this.blockImages,
              jsEnabled: this.jsEnabled,
              doNotTrack: this.dnt,
              desktopUA: this.desktopUA,
              readingTheme: this.readingTheme,
              onPageStart: (t: BrowserTab) => this.handlePageStart(t),
              onPageFinished: (t: BrowserTab) => this.handlePageFinished(t)
            })
          }, (tab: BrowserTab) => tab.id)

          if (this.showHome) {
            HomeView({
              recents: this.history.slice(0, 4),
              dials: this.dials,
              onOpen: (url: string) => this.navigate(url),
              onEditDial: (item: DialItem | null) => {
                this.dialEditing = item;
                this.dialEditorVisible = true;
              }
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .clip(true)
        .backgroundColor(Color.Transparent)

        BottomBar({
          tab: this.activeTab(),
          home: this.showHome,
          tabCount: this.tabs.length,
          onAction: (action: string) => this.handleAction(action)
        })
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topAvoid, bottom: this.bottomAvoid })

      if (this.menuVisible) {
        MenuSheet({
          bookmarked: this.isBookmarked(),
          onPick: (key: string) => this.handleMenu(key),
          onClose: () => {
            this.menuVisible = false;
          }
        })
      }

      if (this.tabsVisible) {
        TabsPanel({
          infos: this.tabInfos(),
          activeId: this.activeId,
          topAvoid: this.topAvoid,
          onSelect: (id: string) => this.activate(id),
          onCloseTab: (id: string) => this.closeTab(id),
          onCreate: () => this.createTab(),
          onCloseAll: () => this.closeAllTabs(),
          onClose: () => {
            this.tabsVisible = false;
          }
        })
      }

      if (this.recordsVisible) {
        RecordsPanel({
          title: this.recordsMode === 'history' ? '浏览记录' : '书签',
          items: this.records(),
          mode: this.recordsMode,
          onOpen: (url: string) => {
            this.recordsVisible = false;
            this.navigate(url);
          },
          onDelete: (id: string) => this.deleteRecord(id),
          onClearAll: () => this.clearRecords(),
          onClose: () => {
            this.recordsVisible = false;
          }
        })
      }

      if (this.downloadsVisible) {
        DownloadsPanel({
          downloads: this.downloads,
          onPauseResume: (guid: string, toPause: boolean) => this.pauseResumeDownload(guid, toPause),
          onCancel: (guid: string) => this.cancelDownload(guid),
          onDelete: (guid: string) => this.deleteDownload(guid),
          onClose: () => {
            this.downloadsVisible = false;
          }
        })
      }

      // 加载指示放根 Stack（与菜单同层），确保盖在网页原生表面之上
      if (!this.showHome && this.loadingPct < 90) {
        Column({ space: 10 }) {
          LoadingProgress()
            .width(38)
            .height(38)
            .color(C('accent'))
          Text('正在加载 ' + this.loadingPct + '%')
            .fontSize(Math.round(12 * getUiScale()))
            .fontColor(C('text_secondary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      // 加载失败：给出明确出路（重试 / 返回主页），不留白屏。
      // 注意：卡片会拦截全屏点击（含底栏），必须自带「返回主页」出口
      if (!this.showHome && this.loadFailed) {
        Column({ space: 14 }) {
          Text('网页打开失败')
            .fontSize(Math.round(17 * getUiScale()))
            .fontWeight(FontWeight.Medium)
            .fontColor(C('text_primary'))
          Text('请检查网络后重试')
            .fontSize(Math.round(12 * getUiScale()))
            .fontColor(C('text_tertiary'))
          Row({ space: 12 }) {
            Text('返回主页')
              .fontSize(Math.round(14 * getUiScale()))
              .fontColor(C('text_secondary'))
              .padding({ left: 20, right: 20, top: 9, bottom: 9 })
              .borderRadius(20)
              .backgroundColor(C('surface_alt'))
              .onClick(() => this.goHome())
            Text('重试')
              .fontSize(Math.round(14 * getUiScale()))
              .fontWeight(FontWeight.Medium)
              .fontColor(C('page_bg'))
              .padding({ left: 22, right: 22, top: 9, bottom: 9 })
              .borderRadius(20)
              .backgroundColor(C('accent'))
              .onClick(() => this.retryActive())
          }
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }

      if (this.dialEditorVisible) {
        DialEditSheet({
          isEditing: this.dialEditing !== null,
          editName: this.dialEditing !== null ? this.dialEditing.name : '',
          editUrl: this.dialEditing !== null ? this.dialEditing.url : '',
          onSave: (name: string, url: string) => this.saveDial(name, url),
          onDelete: () => this.deleteDial(),
          onClose: () => {
            this.dialEditorVisible = false;
          }
        })
      }

      if (this.settingsVisible) {
        SettingsPanel({
          engineName: ENGINES[this.engineIndex].name,
          homepage: this.homepage,
          blockImages: this.blockImages,
          saveHistory: this.saveHistory,
          jsEnabled: this.jsEnabled,
          dnt: this.dnt,
          desktopUA: this.desktopUA,
          bgPath: this.bgImage,
          elderMode: this.elderMode,
          readingTheme: this.readingTheme,
          onToggle: (key: string, value: boolean) => {
            if (key === 'blockImages') {
              this.blockImages = value;
              AiaStore.blockImages = value;
            } else if (key === 'saveHistory') {
              this.saveHistory = value;
              AiaStore.saveHistory = value;
            } else if (key === 'js') {
              this.jsEnabled = value;
              AiaStore.javaScriptEnabled = value;
            } else if (key === 'dnt') {
              this.dnt = value;
              AiaStore.doNotTrack = value;
            } else if (key === 'desktopUA') {
              this.desktopUA = value;
              AiaStore.desktopUA = value;
              promptAction.showToast({ message: value ? '已切换桌面版网页' : '已恢复手机版网页' });
            } else if (key === 'elderMode') {
              // 关怀模式：切换缩放因子并整树重建 UI
              this.elderMode = value;
              AiaStore.elderMode = value;
              setUiScale(value ? 1.25 : 1.0);
              this.uiEpoch = this.uiEpoch + 1;
              promptAction.showToast({ message: value ? '已开启关怀模式' : '已返回标准模式' });
            } else if (key === 'readingTheme') {
              // 阅读模式（羊皮卷主题）：切主题并整树重建
              this.readingTheme = value;
              AiaStore.readingTheme = value;
              setThemeMode(value ? 'parchment' : 'system');
              this.uiEpoch = this.uiEpoch + 1;
              promptAction.showToast({ message: value ? '已进入阅读模式' : '已跟随系统配色' });
            }
          },
          onPickEngine: (index: number) => {
            this.engineIndex = index;
            AiaStore.engineIndex = index;
          },
          onClearHistory: () => {
            this.history = [];
            AiaStore.clearHistory();
            promptAction.showToast({ message: '浏览记录已清除' });
          },
          onPickBackground: (): void => {
            this.pickBackground();
          },
          onClearBackground: (): void => {
            this.clearBackground();
          },
          onClose: () => {
            this.settingsVisible = false;
          }
        })
      }
    }, (e: number) => 'epoch' + e.toString() + 't' + this.themeEpoch.toString() + (this.readingTheme ? 'r' : 's'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C('page_bg'))
  }
}

/** 挂起的下载动作队列：UI 面板发起，delegate 的下一次 onDownloadUpdated 消费 */
export class WebPendingAction {
  static map: Map<string, string> = new Map();

  static set(guid: string, action: string): void {
    WebPendingAction.map.set(guid, action);
  }

  static consume(guid: string): string {
    const a: string | undefined = WebPendingAction.map.get(guid);
    if (a !== undefined) {
      WebPendingAction.map.delete(guid);
    }
    return a === undefined ? '' : a;
  }
}
