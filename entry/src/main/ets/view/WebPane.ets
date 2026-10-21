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
  @Prop blockImages: boolean;
  @Prop jsEnabled: boolean;
  @Prop doNotTrack: boolean;
  /** 阅读模式（羊皮卷）：给网页内容注入暖色滤镜 */
  @Prop readingTheme: boolean;
  onPageStart: (tab: BrowserTab) => void = () => {
  };
  onPageFinished: (tab: BrowserTab) => void = () => {
  };

  private controller: webview.WebviewController = new webview.WebviewController();

  /** 阅读模式滤镜：页面加载完成后注入，近似羊皮纸效果 */
  private applyReadingFilter(): void {
    if (!this.readingTheme) {
      return;
    }
    try {
      this.controller.runJavaScript(
        "try{document.documentElement.style.filter='sepia(0.3) saturate(0.92) brightness(0.99)';}catch(e){}");
    } catch (err) {
      // 部分页面注入失败可忽略
    }
  }

  aboutToAppear(): void {
    this.tab.controller = this.controller;
  }

  aboutToDisappear(): void {
    if (this.tab.controller === this.controller) {
      this.tab.controller = null;
    }
  }

  /** 把活动标签的加载进度同步到 AppStorage，驱动地址栏进度条与内容区加载指示 */
  private syncLoading(): void {
    if (this.active) {
      AppStorage.setOrCreate<number>('loadingPct', this.tab.isLoading ? this.tab.progress : 100);
    }
  }

  build() {
    Stack() {
      // 背景必须透明：空白页/主页态透出宣纸底或自定义背景图，
      // 且不能对 Web 使用 visibility None 隐藏——隐藏态创建的 ArkWeb
      // 内核会初始化失败（browser is null），导致导航随机挂起
      Web({ src: 'about:blank', controller: this.controller })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
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
        // 占位页（about:blank）的 pageBegin 不改任何状态——
        // 否则启动时会把主页误切走；真实页面（含前进恢复的页面）正常处理
        let current: string = '';
        try {
          current = this.controller.getUrl();
        } catch (err) {
          // ignore
        }
        if (current === 'about:blank' || current.length === 0) {
          console.info('AiaWeb pageBegin (placeholder, ignored)');
          return;
        }
        this.tab.pageBeginSeen = true;
        this.tab.loadError = false;
        console.info('AiaWeb pageBegin ' + current);
        this.tab.url = current;
        this.tab.isLoading = true;
        this.tab.progress = 0;
        if (this.active) {
          AppStorage.setOrCreate<boolean>('loadFailed', false);
        }
        // 在加载开始时就刷新导航状态，不等 onPageEnd——
        // 否则慢页面加载期间返回键会一直处于滞后状态
        try {
          this.tab.canGoBack = this.controller.accessBackward();
          this.tab.canGoForward = this.controller.accessForward();
        } catch (err) {
          // ignore
        }
        this.syncLoading();
        this.onPageStart(this.tab);
      })
      .onProgressChange((event: OnProgressChangeEvent) => {
        this.tab.progress = event.newProgress;
        this.tab.isLoading = event.newProgress < 100;
        this.syncLoading();
      })
      .onTitleReceive((event: OnTitleReceiveEvent) => {
        if (event.title !== undefined && event.title.length > 0) {
          this.tab.title = event.title;
        }
      })
      .onPageEnd(() => {
        let current: string = '';
        try {
          current = this.controller.getUrl();
        } catch (err) {
          // 页面销毁瞬间可能取不到状态
        }

        if (current === 'about:blank' || current.length === 0) {
          // 占位页结束事件分两种，用「返回键预期标记」确定性区分：
          // 1) 用户按了返回退到占位页（expectBlankHome=true）→ 结束加载并回主页
          // 2) 导航后排队的占位页迟到事件 → 完全忽略
          // （旧方案用 5 秒时间窗，用户快速按返回会被误吞，停在空白页）
          if (!this.tab.expectBlankHome) {
            return;
          }
          this.tab.expectBlankHome = false;
          this.tab.isLoading = false;
          this.tab.progress = 100;
          this.tab.url = '';
          this.tab.canGoBack = false;
          this.tab.canGoForward = false;
          this.syncLoading();
          this.onPageFinished(this.tab);
          return;
        }

        this.tab.isLoading = false;
        this.tab.progress = 100;
        this.tab.url = current;
        this.tab.expectBlankHome = false; // 真实页面已落地，清除返回预期
        try {
          this.tab.canGoBack = this.controller.accessBackward();
          this.tab.canGoForward = this.controller.accessForward();
          console.info('AiaWeb pageEnd url=' + current + ' canBack=' + this.tab.canGoBack);
        } catch (err) {
          // ignore
        }
        this.syncLoading();
        this.applyReadingFilter();
        if (this.active) {
          AppStorage.setOrCreate<boolean>('loadFailed', false);
        }
        this.onPageFinished(this.tab);
      })
      // 报错页（登录墙、断网等）不会触发 onPageEnd，必须在这里结束加载状态，
      // 否则进度条会永远卡住
      .onErrorReceive(() => {
        this.tab.loadError = true;
        this.tab.isLoading = false;
        this.tab.progress = 100;
        this.syncLoading();
        if (this.active) {
          AppStorage.setOrCreate<boolean>('loadFailed', true);
        }
      })
      .visibility(this.active ? Visibility.Visible : Visibility.None);
    }
    .width('100%')
    .height('100%')
  }
}
