import { HistoryEntry } from '../model/Models';
import { colorForHost, hostOf, initialOf, prettyUrl } from '../common/UrlUtils';
import { ZFont, ZRadius, ZSpace } from '../common/AiaTheme';

/**
 * 书签 / 历史 共用的列表面板（从底部升起的半屏）。
 */
@Component
export struct RecordsPanel {
  @Prop title: string;
  @Prop items: HistoryEntry[];
  /** bookmark | history */
  @Prop mode: string;
  onOpen: (url: string) => void = () => {
  };
  onDelete: (id: string) => void = () => {
  };
  onClearAll: () => void = () => {
  };
  onClose: () => void = () => {
  };

  @Builder
  row(item: HistoryEntry) {
    Row({ space: 11 }) {
      Stack() {
        Text(initialOf(hostOf(item.url)))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(colorForHost(hostOf(item.url)))
      }
      .width(32)
      .height(32)
      .borderRadius(10)
      .backgroundColor($r('app.color.surface_alt'))

      Column({ space: 2 }) {
        Text(item.title.length > 0 ? item.title : prettyUrl(item.url))
          .fontSize(ZFont.body)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(hostOf(item.url))
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($r('app.media.ic_close_sm'))
        .width(12)
        .height(12)
        .opacity(0.4)
        .padding(6)
        .onClick(() => this.onDelete(item.id))
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => this.onOpen(item.url))
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.scrim'))
        .onClick(() => this.onClose())

      Column() {
        // 抓手
        Row() {
          Row()
            .width(34)
            .height(4)
            .borderRadius(2)
            .backgroundColor($r('app.color.surface_alt_2'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 10 })

        Row() {
          Text(this.title)
            .fontSize(ZFont.title)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))

          Blank()

          if (this.items.length > 0) {
            Text(this.mode === 'history' ? '清空' : '删全部')
              .fontSize(ZFont.footnote)
              .fontColor($r('app.color.danger'))
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .onClick(() => this.onClearAll())
          }

          Text('完成')
            .fontSize(ZFont.body)
            .fontColor($r('app.color.accent'))
            .padding({ left: 10, right: 4, top: 6, bottom: 6 })
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: ZSpace.page, right: ZSpace.md, bottom: 4 })

        if (this.items.length === 0) {
          Column({ space: 10 }) {
            Image(this.mode === 'history' ? $r('app.media.ic_history') : $r('app.media.ic_bookmark'))
              .width(30)
              .height(30)
              .opacity(0.28)
            Text(this.mode === 'history' ? '还没有浏览记录' : '还没有书签')
              .fontSize(ZFont.footnote)
              .fontColor($r('app.color.text_tertiary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.items, (item: HistoryEntry) => {
              ListItem() {
                this.row(item)
              }
            }, (item: HistoryEntry) => item.id)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: ZSpace.page, right: ZSpace.page })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .width('100%')
      .height('74%')
      .padding({ bottom: 16 })
      .borderRadius({ topLeft: ZRadius.sheet, topRight: ZRadius.sheet })
      .backgroundColor($r('app.color.surface'))
      .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        .animation({ duration: 260, curve: Curve.FastOutSlowIn }))
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 180 }))
  }
}
