import { ZFont, ZRadius } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

class MenuEntry {
  key: string;
  label: string;
  icon: Resource;

  constructor(key: string, label: string, icon: Resource) {
    this.key = key;
    this.label = label;
    this.icon = icon;
  }
}

/**
 * 底部菜单：8 宫格。Via 式做法——所有次要功能收在这里，
 * 主界面上除了地址栏什么也不留。
 */
@Component
export struct MenuSheet {
  @Prop bookmarked: boolean;
  onPick: (key: string) => void = () => {
  };
  onClose: () => void = () => {
  };

  private entries(): MenuEntry[] {
    return [
      new MenuEntry('bookmarks', '书签', $r('app.media.ic_bookmark')),
      new MenuEntry('history', '历史', $r('app.media.ic_history')),
      new MenuEntry('add', this.bookmarked ? '已收藏' : '加书签', this.bookmarked
        ? $r('app.media.ic_star_fill') : $r('app.media.ic_star')),
      new MenuEntry('copy', '复制链接', $r('app.media.ic_copy')),
      new MenuEntry('reload', '刷新', $r('app.media.ic_refresh')),
      new MenuEntry('home', '主页', $r('app.media.ic_home')),
      new MenuEntry('settings', '设置', $r('app.media.ic_settings')),
      new MenuEntry('close', '关闭标签', $r('app.media.ic_close_sm'))
    ];
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(C('scrim'))
        .onClick(() => this.onClose())

      Column({ space: 4 }) {
        Row() {
          Row()
            .width(34)
            .height(4)
            .borderRadius(2)
            .backgroundColor(C('surface_alt_2'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 14 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.entries(), (item: MenuEntry) => {
            Column({ space: 8 }) {
              Stack() {
                Image(item.icon)
                  .width(20)
                  .height(20)
              }
              .width(46)
              .height(46)
              .borderRadius(14)
              .backgroundColor(C('surface_alt'))

              Text(item.label)
                .fontSize(ZFont.caption)
                .fontColor(C('text_secondary'))
            }
            .width('25%')
            .padding({ top: 6, bottom: 14 })
            .onClick(() => {
              this.onPick(item.key);
            })
          }, (item: MenuEntry) => item.key)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 10, right: 10, bottom: 22 })
      .borderRadius({ topLeft: ZRadius.sheet, topRight: ZRadius.sheet })
      .backgroundColor(C('surface'))
      .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        .animation({ duration: 240, curve: Curve.FastOutSlowIn }))
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 180 }))
  }
}
