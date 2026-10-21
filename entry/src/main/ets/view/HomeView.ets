import { HistoryEntry, DialItem } from '../model/Models';
import { colorForHost, hostOf, prettyUrl } from '../common/UrlUtils';
import { ZFont, ZSpace, getUiScale } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/** 主页快捷方式数量上限 */
const MAX_DIALS: number = 12;

/**
 * 新标签页（Aia 主页）
 * 品牌 + 可编辑快捷方式网格（点按打开 / 长按编辑 / 末尾 + 新增）+ 最近访问。
 */
@Component
export struct HomeView {
  @Prop recents: HistoryEntry[];
  @Prop dials: DialItem[];
  onOpen: (url: string) => void = () => {
  };
  /** 长按快捷方式：编辑（item）/ 新增（null） */
  onEditDial: (item: DialItem | null) => void = () => {
  };

  /** 每 4 个一行；「添加」格紧跟最后一个快捷方式（行满才另起一行），稳定键避免 diff 残留 */
  private dialRows(): DialItem[][] {
    const rows: DialItem[][] = [];
    const showAdd: boolean = this.dials.length < MAX_DIALS;
    const total: number = this.dials.length + (showAdd ? 1 : 0);
    let i = 0;
    while (i < total) {
      const row: DialItem[] = [];
      for (let j = 0; j < 4 && i < total; j++, i++) {
        if (i < this.dials.length) {
          row.push(this.dials[i]);
        } else {
          row.push({ name: '＋', url: '__add__', color: '#8A8270' });
        }
      }
      rows.push(row);
    }
    return rows;
  }

  private rowKey(row: DialItem[]): string {
    const keys: string[] = [];
    for (let i = 0; i < row.length; i++) {
      keys.push(row[i].url + '#' + row[i].name);
    }
    return keys.join('|');
  }

  @Builder
  dialItem(item: DialItem) {
    Column({ space: 8 }) {
      Stack() {
        Text(item.url === '__add__' ? '＋' : item.name.substring(0, 1))
          .fontSize(Math.round(19 * getUiScale()))
          .fontWeight(item.url === '__add__' ? FontWeight.Normal : FontWeight.Medium)
          .fontFamily(item.url === '__add__' ? 'HarmonyOS Sans' : 'serif')
          .fontColor(item.url === '__add__' ? C('text_tertiary') : item.color)
      }
      .width(Math.round(52 * getUiScale()))
      .height(Math.round(52 * getUiScale()))
      .borderRadius(Math.round(26 * getUiScale()))
      .backgroundColor(C('surface_alt'))

      Text(item.url === '__add__' ? '添加' : item.name)
        .fontSize(ZFont.caption)
        .fontColor(item.url === '__add__' ? C('text_tertiary') : C('text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ top: ZSpace.sm, bottom: ZSpace.sm })
    .onClick(() => {
      if (item.url === '__add__') {
        this.onEditDial(null);
      } else {
        this.onOpen(item.url);
      }
    })
    .gesture(LongPressGesture({ repeat: false })
      .onAction(() => {
        if (item.url !== '__add__') {
          this.onEditDial(item);
        }
      }))
  }

  @Builder
  recentItem(item: HistoryEntry) {
    Row({ space: 11 }) {
      Stack() {
        Text(hostOf(item.url).substring(0, 1).toUpperCase())
          .fontSize(Math.round(12 * getUiScale()))
          .fontWeight(FontWeight.Medium)
          .fontColor(colorForHost(hostOf(item.url)))
      }
      .width(28)
      .height(28)
      .borderRadius(9)
      .backgroundColor(C('surface_alt'))

      Column({ space: 2 }) {
        Text(item.title.length > 0 ? item.title : prettyUrl(item.url))
          .fontSize(ZFont.footnote)
          .fontColor(C('text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(hostOf(item.url))
          .fontSize(Math.round(10 * getUiScale()))
          .fontColor(C('text_tertiary'))
          .maxLines(1)
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
    .onClick(() => this.onOpen(item.url))
  }

  build() {
    Scroll() {
      Column() {
        // 品牌区：居中 logo + 印章 + 远山
        Stack({ alignContent: Alignment.Bottom }) {
          Image($r('app.media.ic_hills'))
            .width('100%')
            .height(86)
            .objectFit(ImageFit.Fill)

          Column() {
            Row({ space: 10 }) {
              Text('Aia')
                .fontSize(Math.round(32 * getUiScale()))
                .fontWeight(FontWeight.Medium)
                .fontFamily('serif')
                .fontColor(C('text_primary'))
                .letterSpacing(8)
              Text('雅')
                .fontSize(Math.round(11 * getUiScale()))
                .fontFamily('serif')
                .fontColor(C('page_bg'))
                .width(20)
                .height(20)
                .textAlign(TextAlign.Center)
                .borderRadius(3)
                .backgroundColor(C('seal'))
            }
            .alignItems(VerticalAlign.Center)

            Text('简单到只剩你需要的')
              .fontSize(Math.round(13 * getUiScale()))
              .fontFamily('serif')
              .fontColor(C('text_secondary'))
              .letterSpacing(4)
              .margin({ top: 10 })
          }
          .width('100%')
        }
        .width('100%')
        .margin({ top: 42, bottom: 26 })

        // 快捷方式：手工分行，每行 4 个，「添加」格内联在最后一个之后
        ForEach(this.dialRows(), (row: DialItem[]) => {
          Row() {
            ForEach(row, (item: DialItem) => {
              this.dialItem(item)
            }, (item: DialItem) => item.url + '#' + item.name)
          }
          .width('100%')
        }, (row: DialItem[]) => this.rowKey(row))

        // 最近访问
        if (this.recents.length > 0) {
          Column() {
            Text('最近访问')
              .fontSize(ZFont.caption)
              .fontColor(C('text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.Start)
              .margin({ top: 34, bottom: 4 })

            ForEach(this.recents.slice(0, 4), (item: HistoryEntry) => {
              this.recentItem(item)
            }, (item: HistoryEntry) => item.id)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: ZSpace.page, right: ZSpace.page, bottom: 40 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor(Color.Transparent)
  }
}
