import { HistoryEntry } from '../model/Models';
import { prettyUrl } from '../common/UrlUtils';
import { ZFont, getUiScale } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/**
 * 历史/网址联想下拉：按关键字过滤浏览历史（标题或 URL 命中，不区分大小写），
 * 保持历史的时序（最新优先），最多 6 条。点按整行直达。
 * entries 用普通属性接收（历史在输入期间不会变化，避免 @Prop 深拷贝开销）。
 */
@Component
export struct SuggestList {
  entries: HistoryEntry[] = [];
  @Prop keyword: string = '';
  onPick: (url: string) => void = () => {
  };

  private matches(): HistoryEntry[] {
    const kw: string = this.keyword.trim().toLowerCase();
    if (kw.length === 0) {
      return [];
    }
    const out: HistoryEntry[] = [];
    for (let i = 0; i < this.entries.length && out.length < 6; i++) {
      const e: HistoryEntry = this.entries[i];
      if (e.title.toLowerCase().includes(kw) || e.url.toLowerCase().includes(kw)) {
        out.push(e);
      }
    }
    return out;
  }

  build() {
    // 无命中时整体不渲染，避免留下一个空的白色圆角框
    if (this.matches().length > 0) {
      Column() {
        ForEach(this.matches(), (e: HistoryEntry) => {
          Row({ space: 10 }) {
            Image($r('app.media.ic_history'))
              .width(15)
              .height(15)
              .opacity(0.5)

            Column({ space: 1 }) {
              Text(e.title.length > 0 ? e.title : prettyUrl(e.url))
                .fontSize(Math.round(14 * getUiScale()))
                .fontColor(C('text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .textAlign(TextAlign.Start)
              Text(prettyUrl(e.url))
                .fontSize(Math.round(11 * getUiScale()))
                .fontColor(C('text_tertiary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .onClick(() => {
            this.onPick(e.url);
          })
        }, (e: HistoryEntry) => e.id)
      }
      .width('100%')
      .borderRadius({ bottomLeft: 14, bottomRight: 14 })
      .backgroundColor(C('surface'))
      .border({ width: 0.5, color: C('divider') })
      .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    }
  }
}
