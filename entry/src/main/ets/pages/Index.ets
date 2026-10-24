import { promptAction } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { picker, fileUri, fileIo, fileShare } from '@kit.CoreFileKit';
import { common, Want, wantConstant } from '@kit.AbilityKit';
import { DownloadsPanel } from '../view/DownloadsPanel';
import { DownloadItem } from '../model/Models';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BrowserTab, Bookmark, HistoryEntry, TabInfo, DialItem, DownloadNavGate } from '../model/Models';
import { ENGINES, SearchEngine } from '../common/SearchEngine';
import { hostOf, resolveInput, isSecure, colorForHost, sanitizeFileName } from '../common/UrlUtils';
import { AiaStore } from '../common/Storage';
import { setUiScale, getUiScale, setThemeMode, C } from '../common/AiaTheme';
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
  /** 外部应用「用 Aia 打开」的链接：EntryAbility 冷启/温启都写入此键，
   *  Index 用 @Watch 双路消费——只靠 aboutToAppear 读一次的话，应用已
   *  在后台运行时（默认浏览器场景常态）温启动的链接会被静默吞掉 */
  @StorageLink('launchUrl') @Watch('onLaunchUrl') launchUrl: string = '';
  @State downloads: DownloadItem[] = AiaStore.loadDownloads();
  @State downloadsVisible: boolean = false;
  @State debugH5: boolean = AiaStore.debugH5;
  @State downloadAskMode: boolean = AiaStore.downloadAskMode;
  private downloadDelegate: webview.WebDownloadDelegate = new webview.WebDownloadDelegate();
  // 下载导航错误忽略状态：构造 WebPane 时按引用传入（ADR-2，取代 dlNavAt/dlPicking 幽灵键）
  private dlGate: DownloadNavGate = new DownloadNavGate();
  /** 用户授权的下载文件夹 uri（空串=未选定）：文件夹级授权内可创建/删除自己的文件 */
  private downloadDirUri: string = AiaStore.downloadDirUri;
  // 进行中下载的活引用表：pause/resume 必须在 item 对象上直接调用。
  // 不能走「队列 + 等 onDownloadUpdated 消费」——暂停后内核不再派发
  // updated 回调，队列里的 resume 永远没人消费，任务就永远卡在暂停态
  private liveItems: Map<string, webview.WebDownloadItem> = new Map();
  // 「下载前询问」模式：开始下载前用户选定的目标 uri（guid -> uri）
  private preTargets: Map<string, string> = new Map();
  // delegate 本体在 Index 管理（状态/持久化都在这），WebPane 创建内核时
  // 通过 AppStorage 取到并 controller.setDownloadDelegate 注册——
  // 此前漏了注册这一步，网页下载事件无人接收

  private seq: number = 0;

  // -------------------------------------------------------------- 生命周期
  aboutToAppear(): void {
    this.engineIndex = AiaStore.engineIndex;
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
    this.debugH5 = AiaStore.debugH5;
    this.downloadAskMode = AiaStore.downloadAskMode;
    this.readingTheme = AiaStore.readingTheme;
    if (this.readingTheme) {
      setThemeMode('parchment');
    }
    // 下载委托：Index 是唯一所有者，构造 WebPane 时按引用传入注册
    // （ADR-2：不再经 AppStorage 共享，所有权清晰、无幽灵键）
    this.downloadDelegate.onBeforeDownload((item: webview.WebDownloadItem) => {
      const guid: string = item.getGuid();
      // 第一时间标记「这是下载型导航」：内核检测到附件后会立刻/延迟补发
      // 主文档错误（实测选择器开着 25 秒后仍会补发）、不派发 pageBegin。
      // dlGate.picking=选择器存活期间无条件忽略；dlGate.navAt=start 后 10 秒窗口
      this.dlGate.navAt = Date.now();
      this.dlGate.picking = true;
      const url: string = item.getUrl();
      let name: string = sanitizeFileName(url.substring(url.lastIndexOf('/') + 1).split('?')[0]);
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
      const d: DownloadItem = new DownloadItem(guid, url, name, path);
      const list: DownloadItem[] = this.downloads.slice();
      list.unshift(d);
      this.downloads = AiaStore.trimDownloads(list);
      AiaStore.saveDownloads(this.downloads);
      const askMode: boolean = AiaStore.downloadAskMode;
      const self = this;
      const startNow = (): void => {
        item.start(path);
        self.liveItems.set(guid, item);
        // 下载真正开始：结束选择器态，改用 start 后 10 秒错误忽略窗口
        self.dlGate.picking = false;
        self.dlGate.navAt = Date.now();
        for (let t = 0; t < self.tabs.length; t++) {
          if (self.tabs[t].id === self.activeId) {
            self.tabs[t].pageBeginSeen = true;
            self.tabs[t].isLoading = false;
            self.tabs[t].progress = 100;
            break;
          }
        }
        promptAction.showToast({ message: '开始下载：' + name });
      };
      if (askMode) {
        // 「自定义文件夹」模式：文件夹授权一次性选定（含删除权），
        // 下载完成后自动保存进去——不再每次下载弹选择器，
        // 也从根本上消除了旧 save() 方案预创建 0B 占位文件的残留问题。
        if (this.downloadDirPath().length > 0) {
          startNow();
          return;
        }
        setTimeout(() => {
          // API 26 起手机支持 DocumentSelectMode.FOLDER（canIUse 判定，
          // 不能按设备类型硬判断）；不支持则降级为旧的逐下载 save() 流程
          const canFolder: boolean =
            canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection');
          if (canFolder) {
            this.pickDownloadFolder((ok: boolean) => {
              if (ok) {
                // 文件夹选择期间 dlGate.picking 一直为 true（忽略内核补发
                // 错误），选定后结束选择器态开始下载
                this.dlGate.picking = false;
                startNow();
              } else {
                // 用户取消选择文件夹：取消下载，不偷偷下到应用目录
                this.dlGate.picking = false;
                try {
                  item.cancel();
                } catch (err) {
                  // ignore
                }
                this.liveItems.delete(guid);
                const kept: DownloadItem[] = [];
                for (let i = 0; i < this.downloads.length; i++) {
                  if (this.downloads[i].guid === guid) {
                    this.downloads[i].state = 'canceled';
                  }
                  kept.push(this.downloads[i]);
                }
                this.downloads = kept;
                AiaStore.saveDownloads(this.downloads);
                promptAction.showToast({ message: '已取消下载' });
              }
            });
            return;
          }
          // ---------- 降级流程（API < 26 设备）：每次下载前选保存文件名 ----------
          try {
            const pickerInst = new picker.DocumentViewPicker();
            const opt: picker.DocumentSaveOptions = {
              newFileNames: [name]
            };
            pickerInst.save(opt).then((uris: Array<string>) => {
              if (uris.length > 0) {
                self.preTargets.set(guid, uris[0]);
                self.downloads.forEach((it: DownloadItem, idx: number) => {
                  if (it.guid === guid) {
                    self.downloads[idx].fileName = uris[0].substring(uris[0].lastIndexOf('/') + 1);
                  }
                });
                AiaStore.saveDownloads(self.downloads);
                startNow();
              } else {
                // 用户主动取消选择：取消下载任务，不偷偷下到应用目录
                self.dlGate.picking = false;
                try {
                  item.cancel();
                } catch (err) {
                  // ignore
                }
                self.liveItems.delete(guid);
                self.downloads.forEach((it: DownloadItem, idx: number) => {
                  if (it.guid === guid) {
                    self.downloads[idx].state = 'canceled';
                  }
                });
                AiaStore.saveDownloads(self.downloads);
                promptAction.showToast({ message: '已取消下载' });
              }
            }).catch((e: BusinessError) => {
              console.info('AiaDL prePick fail code=' + e.code);
              startNow(); // 选择器异常不阻塞下载，落到应用目录
            });
          } catch (err) {
            startNow();
          }
        }, 30);
        // 首次下载：说明文件夹模式（仅一次）
        if (!AiaStore.downloadAsked) {
          AiaStore.downloadAsked = true;
          setTimeout(() => {
            self.getUIContext().showAlertDialog({
              title: '下载位置',
              message: '将弹出文件夹选择器，选定后所有下载自动保存到该文件夹（可在设置中更改或改回应用目录模式）。',
              autoCancel: true,
              alignment: DialogAlignment.Center,
              primaryButton: {
                value: '知道了',
                fontColor: C('accent'),
                action: () => {
                }
              }
            });
          }, 800);
        }
        return;
      }
      startNow();
    });
    this.downloadDelegate.onDownloadUpdated((item: webview.WebDownloadItem) => {
      // 记录最新 item 活引用：暂停后内核不再发 updated 回调，
      // 恢复必须直接在此引用上调用（见 pauseResumeDownload）
      this.liveItems.set(item.getGuid(), item);
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
      const finGuid: string = item.getGuid();
      let doneIdx: number = -1;
      for (let i = 0; i < this.downloads.length; i++) {
        if (this.downloads[i].guid === finGuid) {
          this.downloads[i].state = 'done';
          this.downloads[i].received = item.getTotalBytes();
          this.downloads[i].total = item.getTotalBytes();
          this.downloads[i].path = item.getFullPath();
          doneIdx = i;
          break;
        }
      }
      this.liveItems.delete(finGuid);
      // 「下载前询问」模式：用户在下载开始前已选定位置——
      // 直接搬移过去，不再弹任何对话框
      const target: string | undefined = this.preTargets.get(finGuid);
      if (target !== undefined && doneIdx >= 0) {
        this.preTargets.delete(finGuid);
        if (this.moveToUri(this.downloads[doneIdx].path, target)) {
          this.downloads[doneIdx].path = target;
          this.downloads[doneIdx].publicUri = target;
          promptAction.showToast({ message: '已保存到所选位置' });
        } else {
          // 搬移失败：清掉选择器预创建的空占位文件，保留应用目录原件
          try {
            fileIo.unlinkSync(target);
          } catch (err) {
            // ignore
          }
          promptAction.showToast({ message: '搬移到所选位置失败，文件在应用目录' });
        }
        AiaStore.saveDownloads(this.downloads);
        return;
      }
      AiaStore.saveDownloads(this.downloads);
      // 自动导出到公共 Download（Chrome 式）：DOWNLOAD 模式系统直接落盘文件管理
      if (doneIdx < 0) {
        return;
      }
      if (AiaStore.downloadAskMode) {
        // 自定义文件夹模式：自动搬移到授权文件夹。
        // 文件夹级授权下文件由应用创建（openSync CREATE），后续删除也由
        // 应用执行（unlinkSync 可用）——不会再残留 0B 壳。
        // 重名自动加序号，不覆盖用户已有文件。
        const dirPath: string = this.downloadDirPath();
        if (dirPath.length > 0) {
          const target: string = this.uniqueTargetPath(dirPath, this.downloads[doneIdx].fileName);
          if (this.moveToUri(this.downloads[doneIdx].path, target)) {
            this.downloads[doneIdx].path = target;
            this.downloads[doneIdx].publicUri = target;
            promptAction.showToast({ message: '已保存到下载文件夹' });
          } else {
            promptAction.showToast({ message: '保存到文件夹失败，文件在应用目录' });
          }
          AiaStore.saveDownloads(this.downloads);
          return;
        }
        // 文件夹授权失效（重启后临时授权过期）：降级为逐下载保存对话框
        // 用户自定义模式：弹出系统保存对话框，可浏览/新建目录选择保存位置
        // 注意：delegate 回调可能不在 UI 线程，picker 必须 setTimeout 调度回主线程
        // 竞态防护：picker 是异步的，回调执行时用户可能已删除/清空记录——
        // 绝不能按捕获时的数组下标访问（越界或错条目），必须按 guid 重新查找
        const finGuid2: string = finGuid;
        setTimeout(() => {
          try {
            const pickerInst = new picker.DocumentViewPicker();
            const cur: DownloadItem | undefined =
              this.downloads.find((d: DownloadItem) => d.guid === finGuid2);
            if (cur === undefined) {
              return; // 记录已被用户删除，无需导出
            }
            const opt: picker.DocumentSaveOptions = {
              newFileNames: [cur.fileName]
            };
                pickerInst.save(opt).then((newUris: Array<string>) => {
                // 按 guid 再次查找：用户可能在 picker 弹窗期间又动了记录
                const i: number = this.downloads.findIndex((d: DownloadItem) => d.guid === finGuid2);
                if (i < 0) {
                  return;
                }
                if (newUris.length > 0) {
                  this.downloads[i].publicUri = newUris[0];
                  try {
                    fileIo.copyFileSync(this.downloads[i].path, newUris[0]);
                    try {
                      fileIo.unlinkSync(this.downloads[i].path); // 已移到用户选的位置
                    } catch (err) {
                      // ignore
                    }
                    this.downloads[i].path = newUris[0];
                    promptAction.showToast({ message: '已保存到你选择的位置' });
                  } catch (err) {
                    promptAction.showToast({ message: '保存失败，文件保留在应用目录' });
                  }
                  AiaStore.saveDownloads(this.downloads);
                } else {
                  promptAction.showToast({ message: '已取消保存，文件在应用目录' });
                }
              }).catch((e: BusinessError) => {
                console.info('AiaDL askSave fail code=' + e.code);
                promptAction.showToast({ message: '保存失败(' + e.code + ')，文件在应用目录' });
              });
          } catch (err) {
            console.info('AiaDL askSave setup fail');
          }
        }, 50);
        return;
      }
      // 应用目录模式：自动导出公共 Download（Chrome 式）
      try {
        const curAuto: DownloadItem | undefined =
          this.downloads.find((d: DownloadItem) => d.guid === finGuid);
        if (curAuto === undefined) {
          return;
        }
        const pickerInst = new picker.DocumentViewPicker();
        const opt: picker.DocumentSaveOptions = {
          newFileNames: [curAuto.fileName],
          pickerMode: picker.DocumentPickerMode.DOWNLOAD
        };
        pickerInst.save(opt).then((newUris: Array<string>) => {
          if (newUris.length > 0) {
            // 按 guid 重新查找，防回调执行期间记录被删/被清空
            const i2: number = this.downloads.findIndex((d: DownloadItem) => d.guid === finGuid);
            if (i2 < 0) {
              return;
            }
            this.downloads[i2].publicUri = newUris[0];
            try {
              fileIo.copyFileSync(this.downloads[i2].path, newUris[0]);
              try {
                fileIo.unlinkSync(this.downloads[i2].path); // 已移到 Download，不留双份
              } catch (err) {
                // ignore
              }
              this.downloads[i2].path = newUris[0];
            } catch (err) {
              // 移动失败保留沙箱原件，文件至少在 Download 有一份
            }
            AiaStore.saveDownloads(this.downloads);
          }
        }).catch(() => {
        });
      } catch (err) {
        // ignore
      }
      promptAction.showToast({ message: '下载完成，已保存到文件管理' });
    });
    this.downloadDelegate.onDownloadFailed((item: webview.WebDownloadItem) => {
      this.liveItems.delete(item.getGuid());
      // 清掉选择器预创建的空占位文件，别让用户目录里留 0 字节垃圾
      const ph: string | undefined = this.preTargets.get(item.getGuid());
      if (ph !== undefined) {
        try {
          fileIo.unlinkSync(ph);
        } catch (err) {
          // ignore
        }
        this.preTargets.delete(item.getGuid());
      }
      // 清掉沙箱里部分写入的半截文件（审查发现 #3：磁盘只增不减）
      try {
        const p: string = item.getFullPath();
        if (p.length > 0) {
          fileIo.unlinkSync(p);
        }
      } catch (err) {
        // 文件可能已被取消路径清理过
      }
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
    // 1.2s 间隔：轮询里含同步 getUrl（IPC），700ms 在低端机有掉帧风险（审查 #6）
    setInterval(() => this.blankWatchdog(), 1200);
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

    const first: BrowserTab = this.newTab();
    this.activeId = first.id;
    this.showHome = true;
    // 冷启携带的外部链接（温启由 @Watch('onLaunchUrl') 消费）
    this.consumeLaunchUrl();
  }

  /** 温启动入口：EntryAbility.onNewWant 写 launchUrl 后触发 */
  private onLaunchUrl(): void {
    this.consumeLaunchUrl();
  }

  /** 消费外部打开的链接（冷启 aboutToAppear + 温启 @Watch 双路入口） */
  private consumeLaunchUrl(): void {
    let pending: string = this.launchUrl;
    if (pending.length === 0) {
      return;
    }
    // Want.uri 可能整体 URL 编码（%3A 冒号 / %2F 斜杠），先还原
    if (pending.indexOf('%3A') >= 0 || pending.indexOf('%3a') >= 0
      || pending.indexOf('%2F') >= 0 || pending.indexOf('%2f') >= 0) {
      try {
        pending = decodeURIComponent(pending);
      } catch (err) {
        // 编码不完整（用户输入含孤立 %）：保留原文
      }
    }
    this.launchUrl = ''; // 清 key 防重复消费（赋空会再触发一次 watch，早退无害）
    // 等第一帧渲染完再加载，确保 Web 组件已挂载（冷启场景）
    setTimeout(() => {
      const tab: BrowserTab = this.activeTab();
      if (tab.url.length === 0 && !tab.isLoading) {
        this.navigate(pending);
      } else {
        // 用户正在浏览：外部链接开新标签，不打断当前页
        this.openInNewTab(pending, tab.incognito);
      }
    }, 60);
  }

  /** 空白页看门狗：非主页状态下停留在占位页且无加载活动 → 自愈回主页 */
  private blankWatchdog(): void {
    if (this.showHome || this.activeTab().loadFailed || this.dialEditorVisible || this.menuVisible
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
      // 只有「本来就是空标签」（tab.url 为空、用户开新标签停在主页态）才自愈；
      // 带目标 URL 的标签内核启动慢（首次 attach 后几秒才 commit），
      // 此间 getUrl 仍是 about:blank——绝不能抢跳主页，否则用户看到导航被吞
      if (tab.url.length === 0 && (u === 'about:blank' || u.length === 0) && idle && !fresh) {
        this.goHome();
        return;
      }
      // ArkWeb 对 DNS 解析失败等场景静默无回调：导航 15 秒后仍无任何
      // pageBegin 且无加载活动 → 疑似加载失败。但内核回调漏报时页面
      // 可能实际已渲染（SPA 跳转/深链拦截等都可能吞回调）——先探测
      // 文档真实内容，确有内容就当加载成功，绝不误弹错误卡。
      if (!tab.isLoading && !tab.pageBeginSeen && !tab.loadFailed && !tab.userStopped
        && Date.now() - tab.lastNavTime > 15000) {
        if (!tab.retriedOnce) {
          tab.retriedOnce = true;
          tab.lastNavTime = Date.now();
          tab.pageBeginSeen = false;
          try {
            if (tab.controller !== null) {
              tab.controller.loadUrl(tab.url);
            }
          } catch (err) {
            // ignore
          }
          return;
        }
        if (!tab.probeBusy) {
          tab.probeBusy = true;
          tab.controller.runJavaScriptExt(
            'String(document.body ? document.body.innerText.length : 0)')
            .then((r: webview.JsMessageExt) => {
              const len: number = parseInt(r.getString(), 10);
              if (!isNaN(len) && len > 50) {
                // 页面实际有内容：修正状态，视为加载成功
                tab.pageBeginSeen = true;
                tab.isLoading = false;
                tab.progress = 100;
                tab.lastNavTime = Date.now();
              } else {
                console.info('AiaWatch probe empty len=' + r.getString() + ' url=' + tab.url);
                tab.loadFailed = true;
              }
            })
            .catch(() => {
              console.info('AiaWatch probe fail -> loadFailed');
              tab.loadFailed = true;
            })
            .finally(() => {
              tab.probeBusy = false;
            });
        }
      }
    } catch (err) {
      // 内核状态不可读时跳过本轮
    }
  }

  onBackPress(): boolean {
    if (this.dialEditorVisible) {
      this.dialEditorVisible = false;
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
      infos.push(new TabInfo(t.id, t.title, t.url, t.url.length === 0, t.incognito));
    }
    return infos;
  }

  private createTab(): void {
    const tab: BrowserTab = this.newTab();
    this.activeId = tab.id;
    this.showHome = true;
    this.tabsVisible = false;
  }

  /** 网页 target=_blank 的新窗口：在新标签打开并立即激活；无痕标签里弹出的新窗口继承无痕 */
  private openInNewTab(url: string, incognito: boolean): void {
    console.info('AiaNav openInNewTab ' + url);
    const tab: BrowserTab = this.newTab();
    tab.incognito = incognito;
    tab.url = url;
    // 导航状态与 navigate() 对齐：lastNavTime 不补会恒触发看门狗重试
    tab.lastNavTime = Date.now();
    tab.pageBeginSeen = false;
    tab.retriedOnce = false;
    tab.loadError = false;
    tab.userStopped = false;
    this.activeId = tab.id;
    this.showHome = false;
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
    tab.loadFailed = false;
    tab.retriedOnce = false;
    tab.userStopped = false;
    tab.expectBlankHome = false;
    tab.progress = 0;
    tab.isLoading = true;
    AppStorage.setOrCreate<number>('loadingPct', 0);
    const ctrl: webview.WebviewController | null = tab.controller;
    if (ctrl === null) {
      console.error('AiaNav controller is null');
      return;
    }
    // attach 后 600ms 内的首次 loadUrl 会丢首帧合成（DOM 加载完成但
    // surface 空白，直到下一次 visibility 切换才恢复）——冷启 launchUrl
    // 60ms 即导航，必现。延迟到 attach+600ms 再发
    const doLoad = (): void => {
      try {
        ctrl.loadUrl(target);
        console.info('AiaNav loadUrl ok');
      } catch (err) {
        console.error('AiaNav loadUrl FAILED: ' + JSON.stringify(err));
      }
    };
    const sinceAttach: number = tab.attachedAt > 0 ? Date.now() - tab.attachedAt : 60000;
    if (sinceAttach < 600) {
      setTimeout(doLoad, 600 - sinceAttach);
      console.info('AiaNav loadUrl deferred ' + (600 - sinceAttach) + 'ms (attach fresh)');
    } else {
      doLoad();
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
        tab.userStopped = true; // 用户主动停止：看门狗不得自动重试/判失败
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
    // 无痕标签不落历史（核心承诺），设置关闭历史同样跳过
    if (!this.saveHistory || tab.incognito || tab.url.length === 0) {
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
    for (let i = 0; i < this.downloads.length; i++) {
      if (this.downloads[i].guid === guid) {
        this.downloads[i].state = toPause ? 'paused' : 'progressing';
        break;
      }
    }
    AiaStore.saveDownloads(this.downloads);
    // 直接在活引用上暂停/继续。绝不能只排队等 onDownloadUpdated 消费：
    // 暂停后内核不再派发该回调，队列里的 resume 会永远悬空——
    // 表现就是「暂停后怎么点都恢复不了网络下载」
    const live: webview.WebDownloadItem | undefined = this.liveItems.get(guid);
    if (live !== undefined) {
      try {
        if (toPause) {
          live.pause();
        } else {
          live.resume();
        }
        return;
      } catch (err) {
        // 引用失效则退回队列兜底
      }
    }
    WebPendingAction.set(guid, toPause ? 'pause' : 'resume');
  }

  private cancelDownload(guid: string): void {
    const live: webview.WebDownloadItem | undefined = this.liveItems.get(guid);
    if (live !== undefined) {
      try {
        live.cancel();
      } catch (err) {
        // 引用失效退回队列兜底
      }
    }
    this.liveItems.delete(guid);
    // 用户取消下载时同样清掉预创建的空占位文件
    const ph2: string | undefined = this.preTargets.get(guid);
    if (ph2 !== undefined) {
      try {
        fileIo.unlinkSync(ph2);
      } catch (err) {
        // ignore
      }
      this.preTargets.delete(guid);
    }
    WebPendingAction.set(guid, 'cancel');
    for (let i = 0; i < this.downloads.length; i++) {
      if (this.downloads[i].guid === guid) {
        this.downloads[i].state = 'canceled';
        // 清掉沙箱里部分写入的半截文件：取消后的文件无用，
        // 不删则磁盘只增不减（审查发现 #3）
        try {
          if (this.downloads[i].path.length > 0) {
            fileIo.unlinkSync(this.downloads[i].path);
          }
        } catch (err) {
          // 内核可能还在写，删除失败则保留（下载失败回调会再清理）
        }
        break;
      }
    }
    AiaStore.saveDownloads(this.downloads);
  }

  /** 扩展名 -> MIME（打开文件用），未识别类型走通用二进制 */
  private mimeOfExt(fileName: string): string {
    const e: string = fileName.substring(fileName.lastIndexOf('.') + 1).toLowerCase();
    if (e === 'pdf') { return 'application/pdf'; }
    if (e === 'apk') { return 'application/vnd.android.package-archive'; }
    if (e === 'zip' || e === 'rar' || e === '7z') { return 'application/zip'; }
    if (e === 'png') { return 'image/png'; }
    if (e === 'jpg' || e === 'jpeg') { return 'image/jpeg'; }
    if (e === 'mp3') { return 'audio/mpeg'; }
    if (e === 'mp4') { return 'video/mp4'; }
    if (e === 'txt' || e === 'csv') { return 'text/plain'; }
    if (e === 'doc' || e === 'docx') { return 'application/msword'; }
    if (e === 'xls' || e === 'xlsx') { return 'application/vnd.ms-excel'; }
    return 'application/octet-stream';
  }

  /** 用系统「打开方式」打开已下载文件（带临时读授权） */
  private openDownload(guid: string): void {
    for (let i = 0; i < this.downloads.length; i++) {
      if (this.downloads[i].guid === guid) {
        const d = this.downloads[i];
        if (d.path.length === 0) {
          return;
        }
        try {
          // path 可能是沙箱路径或 picker 返回的 file:// uri，分别处理
          const openUri: string = d.path.startsWith('file://') ? d.path
            : fileUri.getUriFromPath(d.path);
          const ctx = getContext(this) as common.UIAbilityContext;
          const want: Want = {
            uri: openUri,
            type: this.mimeOfExt(d.fileName),
            action: 'ohos.want.action.viewData',
            flags: wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
          };
          ctx.startAbility(want).catch(() => {
            promptAction.showToast({ message: '没有可打开此文件的应用' });
          });
        } catch (err) {
          promptAction.showToast({ message: '打开失败' });
        }
        return;
      }
    }
  }

  /** 清空下载记录，可选是否删除真实文件（含公共副本）；进行中的任务先取消 */
  private clearDownloads(): void {
    if (this.downloads.length === 0) {
      return;
    }
    const doneCount: number = this.downloads.filter((d: DownloadItem) => d.state === 'done').length;
    const snapshot: DownloadItem[] = this.downloads.slice();
    this.getUIContext().showAlertDialog({
      title: '清空下载记录',
      message: doneCount > 0
        ? '是否同时删除已下载的 ' + doneCount + ' 个文件？删除后无法恢复。'
        : '将清空全部下载记录。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '仅清除记录',
        action: () => {
          this.finishClearDownloads(snapshot, false);
        }
      },
      secondaryButton: {
        value: '清除并删除文件',
        fontColor: '#B4552E',
        action: () => {
          this.finishClearDownloads(snapshot, true);
        }
      }
    });
  }

  /** 执行清空：delFiles=true 时删除沙箱原件与公共副本 */
  private finishClearDownloads(snapshot: DownloadItem[], delFiles: boolean): void {
    for (let i = 0; i < snapshot.length; i++) {
      const d = snapshot[i];
      if (d.state === 'progressing' || d.state === 'paused') {
        WebPendingAction.set(d.guid, 'cancel');
      }
      if (delFiles && d.path.length > 0) {
        this.deleteFileAny(d.path); // 沙箱路径与选择器 uri 统一走降级删除
      }
      if (delFiles && d.publicUri.length > 0) {
        this.deleteFileAny(d.publicUri); // 公共副本删除失败不影响记录
      }
    }
    this.downloads = [];
    AiaStore.saveDownloads(this.downloads);
    promptAction.showToast({ message: delFiles ? '已清空记录并删除文件' : '已清空下载记录' });
  }

  /**
   * 搬移沙箱文件到选择器返回的 uri。
   * 关键坑：对 picker uri 直接 copyFileSync(src, uri) 会失败或写不进内容
   * （选择器 save() 只预创建了 0 字节占位文件），必须 open 出 fd 再按
   * fd 写入，写完关闭并删除沙箱原件。
   */
  private moveToUri(srcPath: string, uri: string): boolean {
    let fd: number = -1;
    try {
      const f = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fd = f.fd;
      fileIo.copyFileSync(srcPath, fd);
      fileIo.closeSync(fd);
      fd = -1;
      try {
        fileIo.unlinkSync(srcPath);
      } catch (err) {
        // 原件删除失败不影响结果（目标已有完整内容）
      }
      return true;
    } catch (err) {
      if (fd >= 0) {
        try {
          fileIo.closeSync(fd);
        } catch (e) {
          // ignore
        }
      }
      return false;
    }
  }

  private deleteDownload(guid: string): void {
    let name: string = '';
    let hasFile: boolean = false;
    for (let i = 0; i < this.downloads.length; i++) {
      if (this.downloads[i].guid === guid) {
        name = this.downloads[i].fileName;
        // done 必有文件；取消/失败也可能留了半截文件（access 检测真实存在）
        hasFile = this.downloads[i].state === 'done';
        if (!hasFile && this.downloads[i].path.length > 0) {
          try {
            hasFile = fileIo.accessSync(this.downloads[i].path);
          } catch (err) {
            hasFile = false;
          }
        }
        break;
      }
    }
    // 双选项确认：仅删记录（文件保留可再导出）/ 连文件一起删。
    // 下载完成后用户经常既想清列表又想清磁盘，单删记录会留垃圾文件
    this.getUIContext().showAlertDialog({
      title: '删除「' + (name.length > 12 ? name.substring(0, 12) + '…' : name) + '」',
      message: hasFile ? '要同时删除已下载的文件吗？删除后无法恢复。' : '仅删除该条下载记录。',
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: hasFile ? '仅删除记录' : '删除',
        fontColor: C('text_secondary'),
        action: () => {
          this.removeDownloadRecord(guid);
        }
      },
      secondaryButton: {
        value: hasFile ? '删除记录和文件' : '取消',
        fontColor: '#B4552E',
        action: () => {
          if (hasFile) {
            this.removeDownloadRecord(guid, true);
          }
        }
      }
    });
  }

  /**
   * 尽力删除任意路径/uri 的文件，返回是否真正删除。
   * 坑：选择器 uri（用户选的目录里的文件）直接 unlinkSync 常因权限
   * 失败且异常被上层吞掉——表现为「删了记录但文件还在」。降级方案：
   * 打开 fd 后 TRUNC 截断为 0（内容清掉，占位符留空壳）。
   */
  private deleteFileAny(path: string): boolean {
    if (path.length === 0) {
      return false;
    }
    try {
      fileIo.unlinkSync(path);
      return true;
    } catch (err) {
      // 继续降级
    }
    let fd: number = -1;
    try {
      const f = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fd = f.fd;
      fileIo.closeSync(fd);
      fd = -1;
      return false; // 截断成功但未真正删除
    } catch (err) {
      if (fd >= 0) {
        try {
          fileIo.closeSync(fd);
        } catch (e) {
          // ignore
        }
      }
      return false; // 连打开都失败：权限不够或已不存在
    }
  }

  /** 已授权下载文件夹的真实可用路径（未授权/已失效返回空串） */
  private downloadDirPath(): string {
    if (this.downloadDirUri.length === 0) {
      return '';
    }
    try {
      const p: string = new fileUri.FileUri(this.downloadDirUri).path;
      return fileIo.accessSync(p) ? p : '';
    } catch (err) {
      return '';
    }
  }

  /**
   * 拉起文件夹选择器（API 26 起手机支持 FOLDER 模式）并持久化授权。
   * 文件夹级授权后，应用可在其中创建/删除自己创建的文件——
   * 从根本上解决「应用内删除后用户文件夹残留 0B 壳」问题。
   */
  private pickDownloadFolder(onDone: (ok: boolean) => void): void {
    try {
      const opt = new picker.DocumentSelectOptions();
      opt.selectMode = picker.DocumentSelectMode.FOLDER;
      const pickerInst = new picker.DocumentViewPicker();
      pickerInst.select(opt).then((uris: Array<string>) => {
        if (uris.length === 0) {
          onDone(false);
          return;
        }
        this.downloadDirUri = uris[0];
        AiaStore.downloadDirUri = uris[0];
        // 尝试持久化授权（重启后仍有效）；失败只影响重启后需要重选一次。
        // 需要写/建/删三权：下载搬移(CREATE)、删除记录时 unlink(DELETE)
        try {
          const pi: fileShare.PolicyInfo = {
            uri: uris[0],
            operationMode: fileShare.OperationMode.WRITE_MODE
              | fileShare.OperationMode.CREATE_MODE
              | fileShare.OperationMode.DELETE_MODE
          };
          fileShare.persistPermission([pi]).catch(() => {
            // 持久化失败不阻塞：本会话内临时授权仍有效
          });
        } catch (err) {
          // ignore
        }
        onDone(true);
      }).catch((e: BusinessError) => {
        console.info('AiaDL folderPick fail code=' + e.code);
        onDone(false);
      });
    } catch (err) {
      onDone(false);
    }
  }

  /** 目标文件夹内的唯一文件名：重名自动追加序号 */
  private uniqueTargetPath(dirPath: string, fileName: string): string {
    const dot: number = fileName.lastIndexOf('.');
    const base: string = dot > 0 ? fileName.substring(0, dot) : fileName;
    const ext: string = dot > 0 ? fileName.substring(dot) : '';
    let candidate: string = dirPath + '/' + fileName;
    let n: number = 1;
    while (n <= 99) {
      try {
        if (!fileIo.accessSync(candidate)) {
          return candidate;
        }
      } catch (err) {
        return candidate; // access 异常视为不存在，交给后续写失败兜底
      }
      candidate = dirPath + '/' + base + '_' + n + ext;
      n++;
    }
    return dirPath + '/' + base + '_' + Date.now() + ext;
  }

  /** 设置面板展示用文件夹名（uri 最后一段） */
  private downloadDirName(): string {
    if (this.downloadDirUri.length === 0) {
      return '';
    }
    return this.downloadDirUri.substring(this.downloadDirUri.lastIndexOf('/') + 1);
  }

  /** 设置面板「更改/去选择」：重新拉起文件夹选择器 */
  private changeDownloadFolder(): void {
    this.pickDownloadFolder((ok: boolean) => {
      if (ok) {
        promptAction.showToast({ message: '已更新下载文件夹' });
        this.uiEpoch = this.uiEpoch + 1; // 刷新设置面板文案
      } else {
        promptAction.showToast({ message: '未更改下载文件夹' });
      }
    });
  }

  /** 执行单条删除：delFile=true 时连沙箱原件与公共副本一起删 */
  private removeDownloadRecord(guid: string, delFile: boolean = false): void {
    let target: DownloadItem | null = null;
    const rest: DownloadItem[] = [];
    for (let i = 0; i < this.downloads.length; i++) {
      if (this.downloads[i].guid === guid) {
        target = this.downloads[i];
      } else {
        rest.push(this.downloads[i]);
      }
    }
    this.liveItems.delete(guid);
    this.preTargets.delete(guid);
    let fileGone: boolean = true;
    if (delFile && target !== null) {
      fileGone = this.deleteFileAny(target.path); // 沙箱路径与 file:// uri 均尝试
      if (target.publicUri.length > 0 && target.publicUri !== target.path) {
        const pubGone: boolean = this.deleteFileAny(target.publicUri);
        fileGone = fileGone || pubGone;
      }
    }
    this.downloads = rest;
    AiaStore.saveDownloads(this.downloads);
    if (!delFile) {
      promptAction.showToast({ message: '已删除记录' });
    } else {
      promptAction.showToast({ message: fileGone ? '已删除记录和文件' : '已删除记录，文件内容已清空' });
      if (!fileGone) {
        // 系统限制：应用对用户所选文件夹里的文件只有读写权、无删除权，
        // 只能截断为 0B；彻底删除需用户在系统「文件管理」中操作
        setTimeout(() => {
          promptAction.showToast({ message: '因系统权限限制无法直接删除，请在文件管理中手动删除该 0B 文件' });
        }, 2300);
      }
    }
  }

  /** 危险操作二次确认：确认后执行 confirm()，取消不动作 */
  private confirmThen(title: string, message: string, confirm: () => void): void {
    this.getUIContext().showAlertDialog({
      title: title,
      message: message,
      autoCancel: true,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '取消',
        fontColor: C('text_secondary'),
        action: () => {
        }
      },
      secondaryButton: {
        value: '确定',
        fontColor: '#B4552E',
        action: () => {
          confirm();
        }
      }
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

  /**
   * 清理全部标签页的 WebView 缓存（内存 + 磁盘离线缓存）。
   * 浏览器是应用数据膨胀的主因：HTTP 缓存/离线资源随浏览无限增长。
   * 只清缓存，不动 Cookie 与 localStorage——登录态不受影响。
   * removeAllCache 是应用级静态方法，一次清除所有 Web 组件的缓存（API 26）。
   */
  private clearWebCache(): void {
    try {
      webview.WebviewController.removeAllCache(true);
      promptAction.showToast({ message: '网页缓存已清理' });
    } catch (err) {
      promptAction.showToast({ message: '缓存清理失败，请稍后重试' });
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
    const tab: BrowserTab = this.activeTab();
    tab.loadFailed = false;
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
    } else if (key === 'incognito') {
      // 无痕模式：新开一个不记录历史的标签并立即激活
      const tab: BrowserTab = this.newTab();
      tab.incognito = true;
      this.activeId = tab.id;
      this.showHome = true;
      promptAction.showToast({ message: '已进入无痕模式（不记录历史）' });
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
        // 首页隐藏顶部地址栏（Via 式）：首页有自己的居中搜索框，
        // 顶部栏只在网页态出现
        if (!this.showHome) {
          AddressBar({
            tab: this.activeTab(),
            home: this.showHome,
            onSubmit: (text: string) => this.navigate(text)
          })
        }

        Stack() {
          ForEach(this.tabs, (tab: BrowserTab) => {
            WebPane({
              tab: tab,
              active: tab.id === this.activeId,
              blockImages: this.blockImages,
              jsEnabled: this.jsEnabled,
              doNotTrack: this.dnt,
              elderMode: this.elderMode,
              readingTheme: this.readingTheme,
              debugH5: this.debugH5,
              dlGate: this.dlGate,
              downloadDelegate: this.downloadDelegate,
              onPageStart: (t: BrowserTab) => this.handlePageStart(t),
              onPageFinished: (t: BrowserTab) => this.handlePageFinished(t),
              onNewWindow: (url: string, incognito: boolean) => this.openInNewTab(url, incognito)
            })
          }, (tab: BrowserTab) => tab.id)

          if (this.showHome) {
            HomeView({
              onOpen: (url: string) => this.navigate(url)
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
          downloads: $downloads,
          onPauseResume: (guid: string, toPause: boolean) => this.pauseResumeDownload(guid, toPause),
          onCancel: (guid: string) => this.cancelDownload(guid),
          onDelete: (guid: string) => this.deleteDownload(guid),
          onOpen: (guid: string) => this.openDownload(guid),
          onClearAll: () => this.clearDownloads(),
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
      if (!this.showHome && this.activeTab().loadFailed) {
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
          blockImages: this.blockImages,
          saveHistory: this.saveHistory,
          jsEnabled: this.jsEnabled,
          dnt: this.dnt,
          debugH5: this.debugH5,
          downloadAskMode: this.downloadAskMode,
          downloadDirName: this.downloadDirName(),
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
            } else if (key === 'askMode') {
              this.downloadAskMode = value;
              AiaStore.downloadAskMode = value;
              promptAction.showToast({ message: value ? '下载将自动保存到所选文件夹' : '下载保存到应用目录' });
            } else if (key === 'debugH5') {
              this.debugH5 = value;
              AiaStore.debugH5 = value;
              try {
                if (value) {
                  try {
                    webview.WebviewController.setWebDebuggingAccess(true, 9222);
                  } catch (e1) {
                    webview.WebviewController.setWebDebuggingAccess(true);
                  }
                  promptAction.showToast({ message: '调试已开启，按设置页说明连接 Chrome' });
                } else {
                  webview.WebviewController.setWebDebuggingAccess(false);
                }
              } catch (err) {
                promptAction.showToast({ message: '开关失败，重启应用后生效' });
              }
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
          onClearCache: (): void => {
            this.clearWebCache();
          },
          onPickBackground: (): void => {
            this.pickBackground();
          },
          onChangeFolder: (): void => {
            this.changeDownloadFolder();
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
  static ts: Map<string, number> = new Map();

  static set(guid: string, action: string): void {
    // 顺带清理 60 秒前的残留：item 已死时动作永无人消费，条目会永久残留（审查 #9）
    const now: number = Date.now();
    WebPendingAction.map.forEach((v: string, k: string) => {
      const t: number | undefined = WebPendingAction.ts.get(k);
      if (t !== undefined && now - t > 60000) {
        WebPendingAction.map.delete(k);
        WebPendingAction.ts.delete(k);
      }
    });
    WebPendingAction.map.set(guid, action);
    WebPendingAction.ts.set(guid, now);
  }

  static consume(guid: string): string {
    const a: string | undefined = WebPendingAction.map.get(guid);
    if (a !== undefined) {
      WebPendingAction.map.delete(guid);
      WebPendingAction.ts.delete(guid);
    }
    return a === undefined ? '' : a;
  }
}
