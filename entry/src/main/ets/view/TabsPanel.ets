import { TabInfo } from '../model/Models';
import { colorForHost, hostOf, initialOf, prettyUrl } from '../common/UrlUtils';
import { ZFont, ZRadius, ZSpace, getUiScale } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/**
 * 标签管理：整页覆盖。卡片用域名色做视觉区分，
 * 不假装有网页缩略图（内核截图成本高、意义不大）。
 */
@Component
export struct TabsPanel {
  @Prop infos: TabInfo[];
  @Prop activeId: string;
  @Prop topAvoid: number;
  onSelect: (id: string) => void = () => {
  };
  onCloseTab: (id: string) => void = () => {
  };
  onCreate: () => void = () => {
  };
  onCloseAll: () => void = () => {
  };
  onClose: () => void = () => {
  };

  @Builder
  tabCard(tab: TabInfo) {
    Column() {
      Row({ space: 7 }) {
        Stack() {
          Text(tab.isHome ? 'Z' : initialOf(hostOf(tab.url)))
            .fontSize(Math.round(10 * getUiScale()))
            .fontWeight(FontWeight.Medium)
            .fontColor(tab.isHome ? C('text_secondary') : colorForHost(hostOf(tab.url)))
        }
        .width(20)
        .height(20)
        .borderRadius(6)
        .backgroundColor(tab.incognito ? '#2E3440' : C('surface_alt'))

        Text(tab.isHome ? '新标签页' : (tab.title.length > 0 ? tab.title : prettyUrl(tab.url)))
          .fontSize(ZFont.footnote)
          .fontColor(C('text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Start)

        if (tab.incognito) {
          Text('无痕')
            .fontSize(Math.round(9 * getUiScale()))
            .fontColor(C('surface'))
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .borderRadius(4)
            .backgroundColor('#2E3440')
        }

        // 单独关闭按钮：圆形芯片，26px 视觉 + 足够触控热区，
        // 比纯图标更醒目（此前 13px 图标 opacity 0.45 几乎不可见）
        Stack() {
          Image($r('app.media.ic_close_sm'))
            .width(13)
            .height(13)
            .opacity(0.62)
        }
        .width(26)
        .height(26)
        .borderRadius(13)
        .backgroundColor(C('surface_alt_2'))
        .onClick(() => this.onCloseTab(tab.id))
      }
      .width('100%')
      .height(40)
      .padding({ left: 9, right: 5 })

      Stack() {
        Text(tab.isHome ? 'Aia' : initialOf(hostOf(tab.url)))
          .fontSize(Math.round(40 * getUiScale()))
          .fontWeight(FontWeight.Bold)
          .fontColor(tab.isHome ? C('text_tertiary') : colorForHost(hostOf(tab.url)))
          .opacity(0.22)
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor(C('surface_alt'))
    }
    .width('100%')
    .height(158)
    .borderRadius(ZRadius.card)
    .clip(true)
    .backgroundColor(C('surface'))
    .border({
      width: tab.id === this.activeId ? 1.6 : 0.5,
      color: tab.id === this.activeId ? C('accent') : C('divider')
    })
    .onClick(() => this.onSelect(tab.id))
  }

  build() {
    Column() {
      Row() {
        Text('标签页')
          .fontSize(ZFont.title)
          .fontWeight(FontWeight.Medium)
          .fontColor(C('text_primary'))

        Blank()

        Text('完成')
          .fontSize(ZFont.body)
          .fontColor(C('accent'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .onClick(() => this.onClose())
      }
      .width('100%')
      .padding({ left: ZSpace.page, right: ZSpace.md, top: 14, bottom: 10 })

      Grid() {
        ForEach(this.infos, (tab: TabInfo) => {
          GridItem() {
            this.tabCard(tab)
          }
        }, (tab: TabInfo) => tab.id)
      }
      .columnsTemplate('1fr 1fr')
      .columnsGap(12)
      .rowsGap(12)
      .layoutWeight(1)
      .padding({ left: ZSpace.page, right: ZSpace.page })
      .scrollBar(BarState.Off)

      Row({ space: 10 }) {
        Text('关闭全部')
          .fontSize(ZFont.footnote)
          .fontColor(C('text_secondary'))
          .padding({ left: 16, right: 16, top: 11, bottom: 11 })
          .borderRadius(ZRadius.pill)
          .backgroundColor(C('surface_alt'))
          .onClick(() => this.onCloseAll())

        Text('新建标签页')
          .fontSize(ZFont.footnote)
          .fontColor(C('surface'))
          .layoutWeight(1)
          .height(40)
          .textAlign(TextAlign.Center)
          .borderRadius(ZRadius.pill)
          .backgroundColor(C('text_primary'))
          .onClick(() => this.onCreate())
      }
      .width('100%')
      .padding({ left: ZSpace.page, right: ZSpace.page, top: 14, bottom: 22 })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topAvoid })
    .backgroundColor(C('page_bg'))
    .transition(TransitionEffect.OPACITY.animation({ duration: 160 })
      .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }).animation({ duration: 200 })))
  }
}
