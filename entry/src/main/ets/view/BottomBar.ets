import { BrowserTab } from '../model/Models';
import { ZSize } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/**
 * 底部工具栏：返回 / 前进 / 主页（居中）/ 标签数 / 菜单。
 * 直接 @ObjectLink 绑定活动标签，canGoBack/canGoForward 实时响应。
 *
 * 注意（踩过的坑）：
 * 1. 不要用带布尔参数的 @Builder 封装可点击图标——按值参数的事件闭包
 *    只在首次构建时求值，会导致点击永远失效；
 * 2. 灰显只做视觉提示，行为在 Index 侧实时查询内核决定。
 *
 * 可见性（保持原有尺寸，只调图标本身）：
 * 可用态图标加深着色（导航键用强调色、主页键用强调色点睛），
 * 不可用态保持淡灰弱化——不加底衬、不放大，布局与原来完全一致。
 */
@Component
export struct BottomBar {
  @ObjectLink tab: BrowserTab;
  @Prop home: boolean;
  @Prop tabCount: number;

  /** action: back | forward | home | tabs | menu */
  onAction: (action: string) => void = () => {
  };

  build() {
    Row() {
      // 左区：返回 / 前进
      Row({ space: 30 }) {
        Stack() {
          Image($r('app.media.ic_back'))
            .width(ZSize.icon)
            .height(ZSize.icon)
            .fillColor(this.tab.canGoBack && !this.home ? C('accent') : C('text_tertiary'))
            .opacity(this.tab.canGoBack && !this.home ? 1 : 0.4)
        }
        .width(ZSize.iconButton)
        .height(ZSize.iconButton)
        .onClick(() => this.onAction('back'))

        Stack() {
          Image($r('app.media.ic_forward'))
            .width(ZSize.icon)
            .height(ZSize.icon)
            .fillColor(this.tab.canGoForward && !this.home ? C('accent') : C('text_tertiary'))
            .opacity(this.tab.canGoForward && !this.home ? 1 : 0.4)
        }
        .width(ZSize.iconButton)
        .height(ZSize.iconButton)
        .onClick(() => this.onAction('forward'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 中区：主页
      Stack() {
        Image($r('app.media.ic_home'))
          .width(ZSize.icon)
          .height(ZSize.icon)
          .fillColor(this.home ? C('text_tertiary') : C('accent'))
          .opacity(this.home ? 0.4 : 1)
      }
      .width(ZSize.iconButton)
      .height(ZSize.iconButton)
      .onClick(() => this.onAction('home'))

      // 右区：标签 / 菜单
      Row({ space: 30 }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Image($r('app.media.ic_tabs'))
            .width(ZSize.icon)
            .height(ZSize.icon)
            .fillColor(C('text_primary'))
          // 多于一个标签才显示数量角标：单标签显示"1"反而突兀
          if (this.tabCount > 1) {
            Text(this.tabCount > 99 ? '99+' : String(this.tabCount))
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor(C('surface'))
              .backgroundColor(C('text_primary'))
              .borderRadius(7)
              .padding({ left: 4, right: 4, top: 1, bottom: 1 })
              .offset({ x: 8, y: -5 })
          }
        }
        .width(ZSize.iconButton)
        .height(ZSize.iconButton)
        .onClick(() => this.onAction('tabs'))

        Stack() {
          Image($r('app.media.ic_more'))
            .width(ZSize.icon)
            .height(ZSize.icon)
            .fillColor(C('text_primary'))
        }
        .width(ZSize.iconButton)
        .height(ZSize.iconButton)
        .onClick(() => this.onAction('menu'))
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(ZSize.toolbar)
    .padding({ left: 10, right: 10 })
    .backgroundColor(C('surface'))
    .border({ width: { top: 0.5 }, color: C('divider') });
  }
}
