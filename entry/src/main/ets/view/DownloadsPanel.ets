import { DownloadItem } from '../model/Models';
import { fmtBytes } from './DownloadRow';
import { DownloadRow } from './DownloadRow';
import { ZFont, ZRadius, ZSpace, getUiScale } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/**
 * 下载管理面板：从底部升起的半屏列表（与书签/历史面板同风格）。
 * 进行中的任务由 @Observed DownloadItem 驱动实时刷新。
 */
@Component
export struct DownloadsPanel {
  /** 双向绑定 Index 的下载数组：清空/进度更新实时同步 */
  @Link downloads: DownloadItem[];
  onPauseResume: (guid: string, toPause: boolean) => void = () => {
  };
  onCancel: (guid: string) => void = () => {
  };
  onDelete: (guid: string) => void = () => {
  };
  onOpen: (guid: string) => void = () => {
  };
  onClearAll: () => void = () => {
  };
  onClose: () => void = () => {
  };

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(C('scrim'))
        .onClick(() => this.onClose())

      Column() {
        Row() {
          Row()
            .width(34)
            .height(4)
            .borderRadius(2)
            .backgroundColor(C('surface_alt_2'))
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ top: 8, bottom: 10 })

        Row() {
          Text('下载管理')
            .fontSize(ZFont.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(C('text_primary'))

          Blank()

          if (this.downloads.length > 0) {
            Text('清空')
              .fontSize(ZFont.footnote)
              .fontColor(C('danger'))
              .padding({ left: 8, right: 8, top: 6, bottom: 6 })
              .onClick(() => this.onClearAll())
          }

          Text('完成')
            .fontSize(ZFont.body)
            .fontColor(C('accent'))
            .padding({ left: 10, right: 4, top: 6, bottom: 6 })
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: ZSpace.page, right: ZSpace.md, bottom: 4 })

        if (this.downloads.length === 0) {
          Column({ space: 10 }) {
            Image($r('app.media.ic_download'))
              .width(30)
              .height(30)
              .opacity(0.28)
            Text('暂无下载任务')
              .fontSize(ZFont.footnote)
              .fontColor(C('text_tertiary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
            ForEach(this.downloads, (item: DownloadItem) => {
              ListItem() {
                DownloadRow({
                  item: item,
                  onPauseResume: (guid: string, toPause: boolean) => this.onPauseResume(guid, toPause),
                  onCancel: (guid: string) => this.onCancel(guid),
                  onDelete: (guid: string) => this.onDelete(guid),
                  onOpen: (guid: string) => this.onOpen(guid)
                })
              }
            }, (item: DownloadItem) => item.guid)
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: ZSpace.page, right: ZSpace.page })
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }

        Text('应用目录模式：文件在应用 downloads 文件夹内；文件夹模式：自动保存到所选文件夹，删除记录可连文件一起删除')
          .fontSize(Math.round(10 * getUiScale()))
          .fontColor(C('text_tertiary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 16 })
      }
      .width('100%')
      .height('74%')
      .padding({ bottom: 4 })
      .borderRadius({ topLeft: ZRadius.sheet, topRight: ZRadius.sheet })
      .backgroundColor(C('surface'))
      .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        .animation({ duration: 260, curve: Curve.FastOutSlowIn }))
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 180 }))
  }
}
