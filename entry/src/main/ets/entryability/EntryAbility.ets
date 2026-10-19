import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AiaStore } from '../common/Storage';

const TAG: string = 'Aia';
const DOMAIN: number = 0x0001;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AiaStore.init(this.context);
    const incoming: string = want.uri === undefined ? '' : want.uri;
    AppStorage.setOrCreate<string>('launchUrl', incoming);
    hilog.info(DOMAIN, TAG, 'Aia started');
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
