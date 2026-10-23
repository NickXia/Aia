import { webview } from '@kit.ArkWeb';
import { common, bundleManager } from '@kit.AbilityKit';
import { BrowserTab } from '../model/Models';
import { hostOf } from '../common/UrlUtils';

/**
 * 单个标签页的 Web 内核容器。
 * 每个实例持有自己的 WebviewController，标签切换只改 visibility，不销毁组件，
 * 因此来回切换标签不会丢失页面状态。
 */
@Component
export struct WebPane {
  @ObjectLink tab: BrowserTab;
  /** 上次深链唤起时间：6 秒内不重复弹「打开App」确认框 */
  private lastOpenLinkAt: number = 0;
  @Prop active: boolean;
  @Prop blockImages: boolean;
  @Prop jsEnabled: boolean;
  @Prop doNotTrack: boolean;
  /** 阅读模式（羊皮卷）：给网页内容注入暖色滤镜 */
  @Prop readingTheme: boolean;
  /** 桌面版 UA：切换后对当前 Web 上下文生效 */
  @Prop @Watch('applyUa') desktopUA: boolean;

  private applyUa(): void {
    try {
      if (this.desktopUA) {
        this.controller.setCustomUserAgent(
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36');
        if (this.tab.url.length > 0) {
          this.controller.refresh();
        }
      } else if (this.defaultUa.length > 0) {
        // 关闭桌面模式：恢复伪装的标准手机 UA（不用内核默认——带 ArkWeb 会被风控 403）
        this.controller.setCustomUserAgent('Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36');
      }
    } catch (err) {
      // ignore
    }
  }
  onPageStart: (tab: BrowserTab) => void = () => {
  };
  onPageFinished: (tab: BrowserTab) => void = () => {
  };
  /** 网页请求的新窗口（target=_blank，如知乎推文/B站视频卡）：交给宿主开新标签 */
  onNewWindow: (url: string) => void = () => {
  };

  private controller: webview.WebviewController = new webview.WebviewController();
  /** 内核默认 UA（onControllerAttached 时记录），关闭桌面模式时恢复 */
  private defaultUa: string = '';

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
      .multiWindowAccess(true)
      .imageAccess(!this.blockImages)
      .onlineImageAccess(!this.blockImages)
      .fileAccess(false)
      .geolocationAccess(false)
      .zoomAccess(true)
      .horizontalScrollBarAccess(false)
      .verticalScrollBarAccess(false)
      .onControllerAttached(() => {
        this.tab.controller = this.controller;
        try {
          // 注册下载委托：网页触发的下载统一交给 Index 管理的 delegate
          const delegate = AppStorage.get<webview.WebDownloadDelegate>('downloadDelegate');
          if (delegate !== undefined) {
            this.controller.setDownloadDelegate(delegate);
          }
        } catch (err) {
          // ignore
        }
        try {
          // 内核默认 UA 带 ArkWeb 标识——知乎/B站/微博风控直接 403（白屏假象"网络差"）。
          // 伪装标准 Android Chrome 移动 UA（浏览器行业惯例），桌面模式用桌面 UA
          this.defaultUa = this.controller.getUserAgent();
          this.controller.setCustomUserAgent(this.desktopUA
            ? 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
            : 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36');
        } catch (err) {
          // ignore
        }
        if (this.tab.url.length > 0) {
          console.info('AiaWeb attach load ' + this.tab.url);
          try {
            this.controller.loadUrl(this.tab.url);
          } catch (err) {
            console.info('AiaWeb attach loadUrl FAIL ' + (err as Error).message);
          }
        }
      })
      .onLoadIntercept((event: OnLoadInterceptEvent) => {
        // 自定义 scheme（zhihu:// 等）＝「打开 App」按钮：主帧才处理，
        // 子帧/子资源里的内部 scheme 一律放行——误杀会让整页资源加载失败
        let isMain: boolean = true;
        try {
          isMain = event.data.isMainFrame();
        } catch (err) {
          // ignore
        }
        const url: string = event.data.getRequestUrl();
        const lower: string = url.toLowerCase();
        const isWeb: boolean = lower.startsWith('http://') || lower.startsWith('https://')
          || lower.startsWith('about:') || lower.startsWith('data:')
          || lower.startsWith('blob:') || lower.startsWith('javascript:');
        if (isWeb || !isMain) {
          return false;
        }
        // 主帧 + 自定义 scheme：一律先拦截（return true），「设备上有没有
        // App 能接手」的判断延迟到下一个事件循环——canOpenLink 是同步跨
        // 进程调用，在内核导航回调里直接执行，遇系统「想要打开」弹窗
        // 会话会与模态互等，把 UI 线程冻死（实测知乎深链致整机无响应）。
        // 另加 6 秒冷却：B站/知乎页面会自动循环触发深链，不冷却会反复
        // 弹系统确认框刷屏
        setTimeout(() => {
          let canOpen: boolean = false;
          try {
            canOpen = bundleManager.canOpenLink(url);
          } catch (err) {
            console.info('AiaWeb scheme queryFail ' + url);
          }
          console.info('AiaWeb scheme ' + url.substring(0, 80) + ' can=' + canOpen);
          if (canOpen && Date.now() - this.lastOpenLinkAt > 6000) {
            this.lastOpenLinkAt = Date.now();
            try {
              const ctx = getContext(this) as common.UIAbilityContext;
              ctx.openLink(url, { appLinkingOnly: false }).catch(() => {
                // 唤起失败：静默留在网页
              });
            } catch (err) {
              // ignore
            }
          }
        }, 0);
        return true;
      })
      .onWindowNew((event: OnWindowNewEvent) => {
        // target=_blank（知乎推文卡/B站视频卡等）：仅用户主动点击触发时
        // 开新标签；脚本弹窗/内核内部新窗口请求忽略——否则主文档重定向
        // 被拆去新标签会导致当前页白屏。
        // 关键：不开原生新窗口就必须显式 handler.setWebController(null)
        // 结束内核的新窗口会话——悬着不处理会卡死后续新建 Web 的初始化，
        // 新标签页永远停在「正在加载」无任何回调（实测知乎 target=_blank 挂死）
        try {
          event.handler.setWebController(null);
        } catch (err) {
          // ignore
        }
        if (event.isAlert || !event.isUserTrigger || event.targetUrl.length === 0) {
          return;
        }
        this.onNewWindow(event.targetUrl);
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
        // 自定义 scheme 的导航（bilibili:// 等）会被 onLoadIntercept 拦截，
        // 不会有对应 onPageEnd——绝不能把 tab.url / isLoading 标到它头上，
        // 否则加载圈永远转、看门狗状态错乱
        const lowerCur: string = current.toLowerCase();
        if (!lowerCur.startsWith('http://') && !lowerCur.startsWith('https://')) {
          console.info('AiaWeb pageBegin (scheme, ignored) ' + current);
          return;
        }
        this.tab.pageBeginSeen = true;
        this.tab.loadError = false;
        this.tab.userStopped = false; // 新导航（含页内点击）恢复进度监听
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
        // 用户已停止：忽略内核停止前排队迟到的 progress 事件，
        // 否则加载圈/✕图标会复活
        if (this.tab.userStopped) {
          return;
        }
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
        // 诊断：主文档真实内容量（排查"秒回空文档"白屏）
        try {
          this.controller.runJavaScriptExt(
            "document.body ? String(document.body.innerText.length) + '|' + document.contentType + '|' + document.readyState : 'noBody'")
            .then((r: webview.JsMessageExt) => {
              console.info('AiaWeb doc ' + current + ' => ' + r.getString());
            }).catch((e: Error) => {
            console.info('AiaWeb doc probe fail');
          });
        } catch (err) {
          // ignore
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
        // 被拦截 scheme 的迟到结束事件：忽略，不污染真实页面状态
        const lowerEnd: string = current.toLowerCase();
        if (!lowerEnd.startsWith('http://') && !lowerEnd.startsWith('https://')) {
          console.info('AiaWeb pageEnd (scheme, ignored) ' + current);
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
      // 诊断：主文档 HTTP 错误状态码（4xx/5xx 不触发 onErrorReceive）
      .onHttpErrorReceive((event: OnHttpErrorReceiveEvent) => {
        try {
          console.info('AiaWeb httpErr url=' + event.request.getRequestUrl()
            + ' code=' + event.response.getResponseCode()
            + ' main=' + event.request.isMainFrame());
        } catch (err) {
          // ignore
        }
      })
      // 报错页（登录墙、断网等）不会触发 onPageEnd，必须在这里结束加载状态，
      // 否则进度条会永远卡住
      .onErrorReceive((event?: OnErrorReceiveEvent) => {
        // 注意：onErrorReceive 也会对页面内资源（视频流/字体/CDN 媒体）触发——
        // 只有「当前主文档本身」加载失败才弹错误卡。B站视频页会自动预载
        // bilivideo.com 的 mp4 流，失败若误判会让渲染完好的页面被蒙上错误卡
        try {
          const errUrl: string = event !== undefined ? event.request.getRequestUrl() : '';
          const errLower: string = errUrl.toLowerCase();
          if (errUrl.length > 0 && !errLower.startsWith('http://') && !errLower.startsWith('https://')
            && !errLower.startsWith('about:') && !errLower.startsWith('data:')
            && !errLower.startsWith('blob:')) {
            console.info('AiaWeb errorReceive (scheme, ignored) ' + errUrl);
            return;
          }
          const docUrl: string = this.tab.url;
          const sameDoc: boolean = docUrl.length > 0
            && (errUrl === docUrl || hostOf(errUrl) === hostOf(docUrl));
          console.info('AiaWeb errorReceive ' + errUrl + ' sameDoc=' + sameDoc);
          if (!sameDoc) {
            // 资源级错误（CDN 媒体流等）：页面照常显示，只结束加载圈
            this.tab.isLoading = false;
            this.tab.progress = 100;
            this.syncLoading();
            return;
          }
        } catch (err) {
          // ignore
        }
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
