import { HistoryEntry } from '../model/Models';
import { colorForHost, hostOf, prettyUrl } from '../common/UrlUtils';
import { ZFont, ZSpace, getUiScale } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';
import { hilog } from '@kit.PerformanceAnalysisKit';

/** 快捷入口数据直接内联在本文件，避免跨模块初始化时序问题 */
interface DialItem {
  name: string;
  url: string;
  color: string;
}

const DIALS: DialItem[] = [
  { name: '百度', url: 'https://www.baidu.com', color: '#3F7BFF' },
  { name: '知乎', url: 'https://www.zhihu.com', color: '#1B7CF2' },
  { name: 'B站', url: 'https://m.bilibili.com', color: '#FB7299' },
  { name: '微博', url: 'https://m.weibo.cn', color: '#E6412E' },
  { name: '淘宝', url: 'https://www.taobao.com', color: '#FF6A00' },
  { name: '豆瓣', url: 'https://www.douban.com', color: '#2FA84F' },
  { name: 'GitHub', url: 'https://github.com', color: '#4285F4' },
  { name: '少数派', url: 'https://sspai.com', color: '#D5413F' }
];

/**
 * 新标签页（Aia 主页）
 * 只放：品牌标识 + 快捷方式网格 + 最近访问。不放搜索框，
 * 因为搜索框就在屏幕顶部，重复的搜索框只会增加噪音。
 */
@Component
export struct HomeView {
  @Prop recents: HistoryEntry[];
  onOpen: (url: string) => void = () => {
  };

  aboutToAppear(): void {
    // 真机排障：若快捷方式仍不显示，可用 hilog 查看数据是否就绪
    hilog.info(0xA0000, 'AiaHome', 'dials ready: %{public}d', DIALS.length);
  }

  /** 每 4 个一行，纯 Row/Column 渲染，不依赖任何高级容器 */
  private dialRows(): DialItem[][] {
    const rows: DialItem[][] = [];
    for (let i = 0; i < DIALS.length; i += 4) {
      rows.push(DIALS.slice(i, i + 4));
    }
    return rows;
  }

  @Builder
  dialItem(item: DialItem) {
    Column({ space: 8 }) {
      Stack() {
        Text(item.name.substring(0, 1))
          .fontSize(Math.round(19 * getUiScale()))
          .fontWeight(FontWeight.Medium)
          .fontFamily('serif')
          .fontColor(item.color)
      }
      .width(Math.round(52 * getUiScale()))
      .height(Math.round(52 * getUiScale()))
      .borderRadius(Math.round(26 * getUiScale()))
      .backgroundColor(C('surface_alt'))

      Text(item.name)
        .fontSize(ZFont.caption)
        .fontColor(C('text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .padding({ top: ZSpace.sm, bottom: ZSpace.sm })
    .onClick(() => this.onOpen(item.url))
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

        // 快捷方式：手工分行，每行 4 个
        ForEach(this.dialRows(), (row: DialItem[]) => {
          Row() {
            ForEach(row, (item: DialItem) => {
              this.dialItem(item)
            }, (item: DialItem) => item.url)
          }
          .width('100%')
        }, (row: DialItem[]) => row[0].url)

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
