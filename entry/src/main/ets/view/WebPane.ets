import { webview } from '@kit.ArkWeb';
import { common, bundleManager } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { BrowserTab, DownloadNavGate } from '../model/Models';
import {
  classifyLoadError, decideDeepLink, isMainDocHttpError,
  shouldAllowFullscreen, shouldIgnoreDownloadNavError
} from '../common/NavigationPolicy';

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
  /** 最近一次用户真实触摸时间：深链唤起 App 的手势门槛 */
  private lastTouchAt: number = 0;
  /** 最近一次「深链被拦截」提示时间：独立冷却防 toast 刷屏 */
  private lastBlockToastAt: number = 0;
  @Prop active: boolean;
  @Prop blockImages: boolean;
  @Prop jsEnabled: boolean;
  @Prop doNotTrack: boolean;
  /** 开发者调试开关：控制诊断探针（每次页面加载的 JS 注入有常驻成本） */
  @Prop debugH5: boolean = false;
  /** 阅读模式（羊皮卷）：给网页内容注入暖色滤镜 */
  @Prop readingTheme: boolean;
  /** 关怀模式：应用 UI 放大的同时，网页文字按比例放大（textZoomRatio） */
  @Prop elderMode: boolean = false;
  /** 下载导航错误忽略状态：Index 构造时按引用传入（ADR-2，不走 AppStorage） */
  dlGate: DownloadNavGate = new DownloadNavGate();
  /** 下载委托：Index 构造时直接传入注册（ADR-2，不走 AppStorage） */
  downloadDelegate: webview.WebDownloadDelegate | null = null;

  onPageStart: (tab: BrowserTab) => void = () => {
  };
  onPageFinished: (tab: BrowserTab) => void = () => {
  };
  /** 网页请求的新窗口（target=_blank，如知乎推文/B站视频卡）：交给宿主开新标签；第二参继承无痕标志 */
  onNewWindow: (url: string, incognito: boolean) => void = () => {
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
      // incognitoMode：内核级无痕——Cookie/缓存/localStorage 走内存态，
      // 标签销毁即丢弃，与普通标签完全隔离（关闭无痕标签后无需登录态残留）
      // src 直接带目标 URL（新标签携带预置链接，如外部「用 Aia 打开」）：
      // 走内核正规初始化加载。绝不能在 onControllerAttached 里立即 loadUrl——
      // 实测 attach 同帧导航内核加载完成后首帧合成会丢失（DOM 完整但
      // surface 空白，任何一次 visibility 切换才恢复），src 参数无此问题
      Web({ src: this.tab.url.length > 0 ? this.tab.url : 'about:blank', controller: this.controller, incognitoMode: this.tab.incognito })
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
      // 关怀模式：网页文字放大 125%（与应用 UI 的 1.25 缩放因子一致），标准模式 100%
      .textZoomRatio(this.elderMode ? 125 : 100)
      .horizontalScrollBarAccess(false)
      .verticalScrollBarAccess(false)
      .onControllerAttached(() => {
        this.tab.controller = this.controller;
        this.tab.attachedAt = Date.now();
        try {
          // 注册下载委托：网页触发的下载统一交给 Index 管理的 delegate（构造时传入）
          if (this.downloadDelegate !== null) {
            this.controller.setDownloadDelegate(this.downloadDelegate);
          }
        } catch (err) {
          // ignore
        }
        try {
          // 内核默认 UA 带 ArkWeb 标识——知乎/B站/微博风控直接 403（白屏假象"网络差"）。
          // 固定伪装标准 Android Chrome 移动 UA（浏览器行业惯例）
          this.controller.setCustomUserAgent('Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36');
        } catch (err) {
          // ignore
        }
        // 注意：此处绝不 loadUrl——新标签的预置 URL 已由 src 构造参数加载
        // （attach 同帧 loadUrl 会导致首帧合成丢失，见 build 内注释）；
        // 已存在标签的导航由 Index.navigate() 的 controller.loadUrl 负责
      })
      .onLoadIntercept((event: OnLoadInterceptEvent) => {
        // 深链决策逻辑已抽为纯函数 decideDeepLink（ADR-1，白名单+手势门槛+冷却，
        // 单测覆盖见 src/test）——这里只负责执行判定结果
        let isMain: boolean = true;
        try {
          isMain = event.data.isMainFrame();
        } catch (err) {
          // ignore
        }
        const url: string = event.data.getRequestUrl();
        const d = decideDeepLink(url, isMain,
          Date.now() - this.lastTouchAt < 1000, Date.now(), this.lastOpenLinkAt);
        if (d.action === 'pass') {
          return false;
        }
        // 主帧自定义 scheme 一律先拦截（return true）：canOpenLink 是同步跨
        // 进程调用，在内核导航回调里直接执行会与系统模态互等冻死 UI 线程
        // （实测知乎深链致整机无响应），判定/唤起延迟到下一事件循环
        if (d.action === 'block') {
          console.info('AiaWeb scheme blocked ' + url.split('?')[0].substring(0, 60));
          if (d.notify && Date.now() - this.lastBlockToastAt > 6000) {
            this.lastBlockToastAt = Date.now();
            promptAction.showToast({ message: '已在网页内打开（未跳转外部应用）' });
          }
          return true;
        }
        if (!d.cooled) {
          console.info('AiaWeb scheme cooldown ' + url.split('?')[0].substring(0, 60));
          return true;
        }
        this.lastOpenLinkAt = Date.now();
        setTimeout(() => {
          let canOpen: boolean = false;
          try {
            canOpen = bundleManager.canOpenLink(url);
          } catch (err) {
            console.info('AiaWeb scheme queryFail ' + url);
          }
          console.info('AiaWeb scheme ' + url.split('?')[0].substring(0, 60) + ' can=' + canOpen);
          if (canOpen) {
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
        // 无痕标签里 target=_blank 开出的新标签必须继承无痕——否则无痕页
        // 登录态经新窗口落进普通标签的持久存储，隔离被击穿
        this.onNewWindow(event.targetUrl, this.tab.incognito);
      })
      // 记录用户真实触摸：深链唤起 App 的手势门槛（见 onLoadIntercept）
      .onTouch(() => {
        this.lastTouchAt = Date.now();
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
        this.tab.loadFailed = false;
        this.tab.userStopped = false; // 新导航（含页内点击）恢复进度监听
        console.info('AiaWeb pageBegin ' + current);
        this.tab.url = current;
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
        // 诊断：主文档真实内容量（排查"秒回空文档"白屏）——
        // 仅开发者模式启用：每次页面加载一次跨进程 JS 注入，线上常驻是开销
        if (this.debugH5) {
          try {
            this.controller.runJavaScriptExt(
              "document.body ? String(document.body.innerText.length) + '|' + document.contentType + '|' + document.readyState : 'noBody'")
              .then((r: webview.JsMessageExt) => {
                console.info('AiaWeb doc ' + current.split('?')[0] + ' => ' + r.getString());
              }).catch((e: Error) => {
              console.info('AiaWeb doc probe fail');
            });
          } catch (err) {
            // ignore
          }
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
        this.tab.loadFailed = false;
        this.onPageFinished(this.tab);
      })
      // ADR-3：主文档 HTTP 4xx/5xx 是确定性失败信号（这类错误不触发
      // onErrorReceive）。资源级 HTTP 错误照旧只记日志。
      .onHttpErrorReceive((event: OnHttpErrorReceiveEvent) => {
        try {
          const code: number = event.response.getResponseCode();
          const main: boolean = event.request.isMainFrame();
          console.info('AiaWeb httpErr url=' + event.request.getRequestUrl()
            + ' code=' + code + ' main=' + main);
          if (isMainDocHttpError(code, main)) {
            this.tab.loadError = true;
            this.tab.loadFailed = true;
            this.tab.isLoading = false;
            this.tab.progress = 100;
            this.syncLoading();
          }
        } catch (err) {
          // ignore
        }
      })
      // 报错页（登录墙、断网等）不会触发 onPageEnd，必须在这里结束加载状态，
      // 否则进度条会永远卡住
      .onErrorReceive((event?: OnErrorReceiveEvent) => {
        // 下载型导航（onBeforeDownload 已接管）主帧不渲染页面，内核可能
        // 对未渲染的主文档补发错误——选择器存活期间无条件忽略
        // （实测用户在选择器停留 25 秒后内核仍会补发，10 秒窗口不够）；
        // start 后 10 秒窗口内的补发同样忽略。
        // 状态来自 Index 按引用传入的 dlGate（ADR-2，不再走 AppStorage）
        if (shouldIgnoreDownloadNavError(this.dlGate.picking, this.dlGate.navAt, Date.now())) {
          console.info('AiaWeb errorReceive (downloadNav, ignored)');
          return;
        }
        // ADR-3 错误归一化：主帧信号优先（event.request.isMainFrame()），
        // hostOf 同域对比只在信号不可用时降级兜底——B站视频页会自动预载
        // bilivideo.com 的 mp4 流，资源级失败绝不能误判成主文档失败
        try {
          const errUrl: string = event !== undefined ? event.request.getRequestUrl() : '';
          let mainSignal: boolean | null = null;
          try {
            mainSignal = event !== undefined ? event.request.isMainFrame() : null;
          } catch (e) {
            mainSignal = null; // 信号不可用：降级 hostOf 对比
          }
          const docUrl: string = this.tab.url;
          const mainDoc: boolean = classifyLoadError(errUrl, docUrl, mainSignal);
          console.info('AiaWeb errorReceive ' + errUrl + ' main=' + mainSignal + ' mainDoc=' + mainDoc);
          if (!mainDoc) {
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
        this.tab.loadFailed = true;
        this.tab.isLoading = false;
        this.tab.progress = 100;
        this.syncLoading();
      })
      // 网页全屏请求手势门槛化：用户点视频全屏按钮必伴随触摸（1 秒内）
      // → 放行；页面自动请求的横幅全屏（无手势）会把 Web 撑满整窗盖住
      // Aia 工具栏且系统返回退不出（实测知乎视频横幅）→ 立即拒绝
      .onFullScreenEnter((event: FullScreenEnterEvent) => {
        if (!shouldAllowFullscreen(this.lastTouchAt, Date.now())) {
          console.info('AiaWeb fullscreenEnter -> reject (no user gesture)');
          try {
            event.handler.exitFullScreen();
          } catch (err) {
            // ignore
          }
          return;
        }
        console.info('AiaWeb fullscreenEnter -> allow (user gesture)');
      })
      .onFullScreenExit(() => {
        console.info('AiaWeb fullscreenExit');
      })
      .visibility(this.active ? Visibility.Visible : Visibility.None);
    }
    .width('100%')
    .height('100%')
  }
}
