import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AiaStore } from '../common/Storage';
import { webview } from '@kit.ArkWeb';
import { ConfigurationConstant, Configuration } from '@kit.AbilityKit';

const TAG: string = 'Aia';
const DOMAIN: number = 0x0001;

export default class EntryAbility extends UIAbility {
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
