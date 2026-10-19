import { webview } from '@kit.ArkWeb';
import { BrowserTab } from '../model/Models';

/**
 * 单个标签页的 Web 内核容器。
 * 每个实例持有自己的 WebviewController，标签切换只改 visibility，不销毁组件，
 * 因此来回切换标签不会丢失页面状态。
 */
@Component
export struct WebPane {
  @ObjectLink tab: BrowserTab;
  @Prop active: boolean;
  /** 主页态为 true：隐藏 Web 层，让自定义背景和主页内容透出 */
  @Prop hidden: boolean;
  @Prop blockImages: boolean;
  @Prop jsEnabled: boolean;
  @Prop doNotTrack: boolean;
  onPageStart: (tab: BrowserTab) => void = () => {
  };
  onPageFinished: (tab: BrowserTab) => void = () => {
  };

  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    this.tab.controller = this.controller;
  }

  aboutToDisappear(): void {
    if (this.tab.controller === this.controller) {
      this.tab.controller = null;
    }
  }

  build() {
    Web({ src: 'about:blank', controller: this.controller })
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
      .javaScriptAccess(this.jsEnabled)
      .domStorageAccess(true)
      .imageAccess(!this.blockImages)
      .onlineImageAccess(!this.blockImages)
      .fileAccess(false)
      .geolocationAccess(false)
      .zoomAccess(true)
      .horizontalScrollBarAccess(false)
      .verticalScrollBarAccess(false)
      .onControllerAttached(() => {
        this.tab.controller = this.controller;
        if (this.tab.url.length > 0) {
          this.controller.loadUrl(this.tab.url);
        }
      })
      .onPageBegin(() => {
        console.info('AiaWeb pageBegin ' + this.tab.url);
        this.tab.isLoading = true;
        this.tab.progress = 0;
        // 在加载开始时就刷新导航状态，不等 onPageEnd——
        // 否则慢页面加载期间返回键会一直处于滞后状态
        try {
          this.tab.canGoBack = this.controller.accessBackward();
          this.tab.canGoForward = this.controller.accessForward();
        } catch (err) {
          // ignore
        }
        this.onPageStart(this.tab);
      })
      .onProgressChange((event: OnProgressChangeEvent) => {
        this.tab.progress = event.newProgress;
        this.tab.isLoading = event.newProgress < 100;
      })
      .onTitleReceive((event: OnTitleReceiveEvent) => {
        if (event.title !== undefined && event.title.length > 0) {
          this.tab.title = event.title;
        }
      })
      .onPageEnd(() => {
        this.tab.isLoading = false;
        this.tab.progress = 100;
        try {
          const current: string = this.controller.getUrl();
          // about:blank 是内部占位页，对用户来说等同于「新标签页」
          this.tab.url = (current === 'about:blank' || current.length === 0) ? '' : current;
          this.tab.canGoBack = this.controller.accessBackward();
          this.tab.canGoForward = this.controller.accessForward();
          console.info('AiaWeb pageEnd url=' + this.tab.url + ' canBack=' + this.tab.canGoBack);
        } catch (err) {
          // 页面销毁瞬间可能取不到状态，忽略
        }
        this.onPageFinished(this.tab);
      })
      // 报错页（登录墙、断网等）不会触发 onPageEnd，必须在这里结束加载状态，
      // 否则进度条会永远卡住
      .onErrorReceive(() => {
        this.tab.isLoading = false;
        this.tab.progress = 100;
      })
      .visibility((this.active && !this.hidden) ? Visibility.Visible : Visibility.None);
  }
}
