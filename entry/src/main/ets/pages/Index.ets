import { promptAction } from '@kit.ArkUI';
import { pasteboard } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { BrowserTab, Bookmark, HistoryEntry, TabInfo } from '../model/Models';
import { ENGINES, SearchEngine } from '../common/SearchEngine';
import { hostOf, resolveInput, isSecure } from '../common/UrlUtils';
import { AiaStore } from '../common/Storage';
import { WebPane } from '../view/WebPane';
import { HomeView } from '../view/HomeView';
import { AddressBar } from '../view/AddressBar';
import { BottomBar } from '../view/BottomBar';
import { MenuSheet } from '../view/MenuSheet';
import { TabsPanel } from '../view/TabsPanel';
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

  @State menuVisible: boolean = false;
  @State tabsVisible: boolean = false;
  @State recordsVisible: boolean = false;
  @State settingsVisible: boolean = false;
  @State recordsMode: string = 'bookmark';

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

  onBackPress(): boolean {
    if (this.menuVisible) {
      this.menuVisible = false;
      return true;
    }
    if (this.tabsVisible) {
      this.tabsVisible = false;
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
    if (target.length === 0) {
      return;
    }
    this.showHome = false;
    const tab: BrowserTab = this.activeTab();
    tab.url = target;
    tab.title = hostOf(target);
    tab.canGoBack = false;
    tab.canGoForward = false;
    if (tab.controller !== null) {
      tab.controller.loadUrl(target);
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
    const tab: BrowserTab = this.activeTab();
    if (tab.controller === null) {
      return;
    }
    try {
      // 点击时实时查询内核，不依赖可能滞后的状态标记
      if (tab.controller.accessBackward()) {
        tab.controller.backward();
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

  private clearRecords(): void {
    if (this.recordsMode === 'history') {
      this.history = [];
      AiaStore.clearHistory();
    } else {
      this.bookmarks = [];
      AiaStore.saveBookmarks([]);
    }
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
        fileIo.copyFile(srcFile.fd, dst);
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
    } else if (key === 'reload') {
      this.reload();
    } else if (key === 'home') {
      this.goHome();
    } else if (key === 'settings') {
      this.settingsVisible = true;
    } else if (key === 'close') {
      this.closeTab(this.activeId);
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
    // about:blank 占位页的加载事件不代表真实导航，忽略它，
    // 否则主页会在启动瞬间被误切到空白网页层（闪一下就消失）
    if (tab.url.length === 0) {
      return;
    }
    if (tab.id === this.activeId) {
      this.showHome = false;
    }
  }

  private handlePageFinished(tab: BrowserTab): void {
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
      // 自定义背景铺满全屏（延伸到状态栏/手势条底下）
      if (this.bgImage.length > 0) {
        Image('file://' + this.bgImage)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .autoResize(true)

        // 可读性遮罩：保证墨色文字在任意图片上都清晰
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.page_bg'))
          .opacity(0.72)
      }

      Column() {
        AddressBar({
          url: this.activeTab().url,
          progress: this.activeTab().progress,
          loading: this.activeTab().isLoading,
          secure: isSecure(this.activeTab().url),
          home: this.showHome,
          onSubmit: (text: string) => this.navigate(text)
        })

        Stack() {
          ForEach(this.tabs, (tab: BrowserTab) => {
            WebPane({
              tab: tab,
              active: tab.id === this.activeId,
              hidden: this.showHome,
              blockImages: this.blockImages,
              jsEnabled: this.jsEnabled,
              doNotTrack: this.dnt,
              onPageStart: (t: BrowserTab) => this.handlePageStart(t),
              onPageFinished: (t: BrowserTab) => this.handlePageFinished(t)
            })
          }, (tab: BrowserTab) => tab.id)

          if (this.showHome) {
            HomeView({
              recents: this.history.slice(0, 4),
              onOpen: (url: string) => this.navigate(url)
            })
          }
        }
        .width('100%')
        .layoutWeight(1)
        .clip(true)
        .backgroundColor(this.bgImage.length > 0 ? Color.Transparent : $r('app.color.page_bg'))

        BottomBar({
          canBack: !this.showHome && this.activeTab().canGoBack,
          canForward: !this.showHome && this.activeTab().canGoForward,
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

      if (this.settingsVisible) {
        SettingsPanel({
          engineName: ENGINES[this.engineIndex].name,
          homepage: this.homepage,
          blockImages: this.blockImages,
          saveHistory: this.saveHistory,
          jsEnabled: this.jsEnabled,
          dnt: this.dnt,
          bgPath: this.bgImage,
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }
}
