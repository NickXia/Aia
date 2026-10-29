import { AbilityConstant, UIAbility, Want, ConfigurationConstant, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { audio } from '@kit.AudioKit';
import { AiaStore } from '../common/Storage';
import { webview } from '@kit.ArkWeb';

const TAG: string = 'Aia';
const DOMAIN: number = 0x0001;

export default class EntryAbility extends UIAbility {
  /**
   * 声明音频并发策略为 share（MIX_WITH_OTHERS）。
   * 上架自检「音频规范」要求：短音/瞬态音、静音播放场景不得打断后台音频。
   * 应用未自管音频焦点（音频来自 ArkWeb 网页内容），故在应用级激活 AudioSession，
   * 使应用内所有音频流（含 Web 内核流）与其他应用音频并发播放。
   */
  private activateAudioShare(): void {
    try {
      const sessionMgr: audio.AudioSessionManager =
        audio.getAudioManager().getSessionManager();
      if (sessionMgr.isAudioSessionActivated()) {
        return;
      }
      // 浏览器属于媒体场景；激活后系统按 share 策略申请焦点
      sessionMgr.setAudioSessionScene(audio.AudioSessionScene.AUDIO_SESSION_SCENE_MEDIA);
      const strategy: audio.AudioSessionStrategy = {
        concurrencyMode: audio.AudioConcurrencyMode.CONCURRENCY_MIX_WITH_OTHERS
      };
      sessionMgr.activateAudioSession(strategy).then(() => {
        hilog.info(DOMAIN, TAG, 'audio session activated (share)');
      }).catch((err: BusinessError) => {
        hilog.error(DOMAIN, TAG, 'activateAudioSession failed: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'audio session setup failed');
    }
  }

  private watchAudioSession(): void {
    try {
      const sessionMgr: audio.AudioSessionManager =
        audio.getAudioManager().getSessionManager();
      // 无音频流运行时会话会被系统超时停用，回到前台/超时后重新激活
      sessionMgr.on('audioSessionDeactivated',
        (e: audio.AudioSessionDeactivatedEvent) => {
          hilog.info(DOMAIN, TAG, 'audio session deactivated: %{public}d', e.reason);
          if (e.reason === audio.AudioSessionDeactivatedReason.DEACTIVATED_TIMEOUT) {
            this.activateAudioShare();
          }
        });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'audio session watch failed');
    }
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AiaStore.init(this.context);
    const incoming: string = want.uri === undefined ? '' : want.uri;
    AppStorage.setOrCreate<string>('launchUrl', incoming);
    // H5 远程调试：须在 Web 内核初始化前调用才生效。
    // 固定 9222 端口（API20+），失败回退无端口版本（随机端口，用 fport ls 查）
    try {
      if (AiaStore.debugH5) {
        try {
          webview.WebviewController.setWebDebuggingAccess(true, 9222);
        } catch (e1) {
          webview.WebviewController.setWebDebuggingAccess(true);
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'setWebDebuggingAccess failed');
    }
    // 深浅色初值（阅读/普通主题的 C() 取色依赖此状态）
    try {
      const cfg = this.context.config;
      AppStorage.setOrCreate<boolean>('isDark',
        cfg.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    } catch (err) {
      AppStorage.setOrCreate<boolean>('isDark', false);
    }
    AppStorage.setOrCreate<number>('themeEpoch', 0);
    hilog.info(DOMAIN, TAG, 'Aia started');
    this.watchAudioSession();
    this.activateAudioShare();
  }

  onForeground(): void {
    // 会话可能已被超时停用，回前台时补激活
    this.activateAudioShare();
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const dark: boolean = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    AppStorage.setOrCreate<boolean>('isDark', dark);
    AppStorage.setOrCreate<number>('themeEpoch', (AppStorage.get<number>('themeEpoch') ?? 0) + 1);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 从其它应用「用 Aia 打开链接」
    const incoming: string = want.uri === undefined ? '' : want.uri;
    if (incoming.length > 0) {
      AppStorage.setOrCreate<string>('launchUrl', incoming);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
      }
    });

    // 全屏铺开：让应用背景延伸到状态栏/手势条底下，消除顶部异色横条。
    // 避让高度（px）存入 AppStorage，由页面转成 vp 后自行留白。
    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowLayoutFullScreen(true);
      const sysAvoid: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navAvoid: window.AvoidArea =
        mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate<number>('topAvoidPx', sysAvoid.topRect.height);
      AppStorage.setOrCreate<number>('bottomAvoidPx', navAvoid.bottomRect.height);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'window layout failed: %{public}s', JSON.stringify(err));
    }
  }
}
