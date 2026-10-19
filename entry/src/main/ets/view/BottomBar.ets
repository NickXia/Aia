import { ZSize } from '../common/AiaTheme';

/**
 * 底部工具栏：返回 / 前进 / 主页（居中）/ 标签数 / 菜单。
 * 注意：不要用带布尔参数的 @Builder 封装可点击图标——
 * 按值参数的事件闭包只在首次构建时求值，会导致点击永远失效。
 * 这里全部内联，闭包直接读 this 状态。
 */
@Component
export struct BottomBar {
  @Prop canBack: boolean;
  @Prop canForward: boolean;
  @Prop home: boolean;
  @Prop tabCount: number;

  /** action: back | forward | home | tabs | menu */
  onAction: (action: string) => void = () => {
  };

  build() {
    Row() {
      // 左区：前进 / 后退
      Row({ space: 30 }) {
        Stack() {
          Image($r('app.media.ic_back'))
            .width(ZSize.icon)
            .height(ZSize.icon)
            .opacity(this.canBack ? 1 : 0.26)
        }
        .width(ZSize.iconButton)
        .height(ZSize.iconButton)
        .onClick(() => {
          // 不做状态拦截，Index 侧会实时查询内核决定行为
          this.onAction('back');
        })

        Stack() {
          Image($r('app.media.ic_forward'))
            .width(ZSize.icon)
            .height(ZSize.icon)
            .opacity(this.canForward ? 1 : 0.26)
        }
        .width(ZSize.iconButton)
        .height(ZSize.iconButton)
        .onClick(() => {
          this.onAction('forward');
        })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      // 中区：主页
      Stack() {
        Image($r('app.media.ic_home'))
          .width(ZSize.icon)
          .height(ZSize.icon)
          .opacity(this.home ? 0.26 : 1)
      }
      .width(ZSize.iconButton)
      .height(ZSize.iconButton)
      .onClick(() => {
        this.onAction('home');
      })

      // 右区：标签 / 菜单
      Row({ space: 30 }) {
        Stack({ alignContent: Alignment.TopEnd }) {
          Image($r('app.media.ic_tabs'))
            .width(ZSize.icon)
            .height(ZSize.icon)
          Text(this.tabCount > 99 ? '99+' : String(this.tabCount))
            .fontSize(9)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.surface'))
            .backgroundColor($r('app.color.text_primary'))
            .borderRadius(7)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .offset({ x: 8, y: -5 })
        }
        .width(ZSize.iconButton)
        .height(ZSize.iconButton)
        .onClick(() => this.onAction('tabs'));

        Stack() {
          Image($r('app.media.ic_more'))
            .width(ZSize.icon)
            .height(ZSize.icon)
        }
        .width(ZSize.iconButton)
        .height(ZSize.iconButton)
        .onClick(() => this.onAction('menu'));
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(ZSize.toolbar)
    .padding({ left: 10, right: 10 })
    .backgroundColor($r('app.color.surface'))
    .border({ width: { top: 0.5 }, color: $r('app.color.divider') });
  }
}
