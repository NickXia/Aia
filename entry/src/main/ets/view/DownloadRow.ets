import { DownloadItem } from '../model/Models';
import { hostOf } from '../common/UrlUtils';
import { ZFont, getUiScale } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/** 字节数格式化 */
export function fmtBytes(n: number): string {
  if (n < 0) {
    return '';
  }
  if (n < 1024) {
    return n + ' B';
  }
  if (n < 1024 * 1024) {
    return (n / 1024).toFixed(1) + ' KB';
  }
  if (n < 1024 * 1024 * 1024) {
    return (n / 1024 / 1024).toFixed(1) + ' MB';
  }
  return (n / 1024 / 1024 / 1024).toFixed(2) + ' GB';
}

/**
 * 下载列表单行：进行中显示进度条与暂停/取消，
 * 暂停显示继续，完成/失败/取消显示删除。
 */
@Component
export struct DownloadRow {
  @ObjectLink item: DownloadItem;
  onPauseResume: (guid: string, toPause: boolean) => void = () => {
  };
  onCancel: (guid: string) => void = () => {
  };
  onDelete: (guid: string) => void = () => {
  };
  onOpen: (guid: string) => void = () => {
  };
  onExport: (guid: string) => void = () => {
  };

  build() {
    Row({ space: 12 }) {
      Stack() {
        Text(this.item.state === 'progressing' || this.item.state === 'paused'
          ? (this.item.total > 0 ? Math.round(this.item.received / this.item.total * 100) + '%' : '···')
          : (this.item.state === 'done' ? '✓' : this.item.state === 'failed' ? '!' : '–'))
          .fontSize(Math.round(12 * getUiScale()))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.item.state === 'done' ? C('accent')
            : this.item.state === 'failed' ? C('danger') : C('text_secondary'))
      }
      .width(40)
      .height(40)
      .borderRadius(12)
      .backgroundColor(C('surface_alt'))

      Column({ space: 3 }) {
        Text(this.item.fileName)
          .fontSize(ZFont.body)
          .fontColor(C('text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)

        if (this.item.state === 'progressing') {
          Progress({
            value: this.item.total > 0 ? this.item.received : 0,
            total: this.item.total > 0 ? this.item.total : 100,
            type: ProgressType.Linear
          })
            .width('100%')
            .height(3)
            .color(C('accent'))
          Text(fmtBytes(this.item.received) + ' / ' + fmtBytes(this.item.total)
            + ' · ' + fmtBytes(this.item.speed) + '/s')
            .fontSize(Math.round(10 * getUiScale()))
            .fontColor(C('text_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Start)
        } else if (this.item.state === 'paused') {
          Progress({
            value: this.item.total > 0 ? this.item.received : 0,
            total: this.item.total > 0 ? this.item.total : 100,
            type: ProgressType.Linear
          })
            .width('100%')
            .height(3)
            .color(C('text_tertiary'))
          Text('已暂停 · ' + fmtBytes(this.item.received) + ' / ' + fmtBytes(this.item.total))
            .fontSize(Math.round(10 * getUiScale()))
            .fontColor(C('text_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Start)
        } else if (this.item.state === 'done') {
          Text(fmtBytes(this.item.total) + ' · 已完成 · ' + hostOf(this.item.url))
            .fontSize(Math.round(10 * getUiScale()))
            .fontColor(C('text_tertiary'))
            .maxLines(1)
            .width('100%')
            .textAlign(TextAlign.Start)
        } else {
          Text((this.item.state === 'failed' ? '下载失败' : '已取消')
            + ' · ' + hostOf(this.item.url))
            .fontSize(Math.round(10 * getUiScale()))
            .fontColor(C('text_tertiary'))
            .maxLines(1)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.item.state === 'progressing') {
        Text('暂停')
          .fontSize(Math.round(12 * getUiScale()))
          .fontColor(C('accent'))
          .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          .onClick(() => this.onPauseResume(this.item.guid, true))
      } else if (this.item.state === 'paused') {
        Text('继续')
          .fontSize(Math.round(12 * getUiScale()))
          .fontColor(C('accent'))
          .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          .onClick(() => this.onPauseResume(this.item.guid, false))
      }
      if (this.item.state === 'progressing' || this.item.state === 'paused') {
        Text('取消')
          .fontSize(Math.round(12 * getUiScale()))
          .fontColor(C('danger'))
          .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          .onClick(() => this.onCancel(this.item.guid))
      } else {
        if (this.item.state === 'done') {
          Text('打开')
            .fontSize(Math.round(12 * getUiScale()))
            .fontColor(C('accent'))
            .padding({ left: 5, right: 5, top: 6, bottom: 6 })
            .onClick(() => this.onOpen(this.item.guid))
          Text('导出')
            .fontSize(Math.round(12 * getUiScale()))
            .fontColor(C('text_secondary'))
            .padding({ left: 5, right: 5, top: 6, bottom: 6 })
            .onClick(() => this.onExport(this.item.guid))
        }
        Image($r('app.media.ic_close_sm'))
          .width(12)
          .height(12)
          .opacity(0.4)
          .padding(6)
          .onClick(() => this.onDelete(this.item.guid))
      }
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
    .alignItems(VerticalAlign.Center)
  }
}
