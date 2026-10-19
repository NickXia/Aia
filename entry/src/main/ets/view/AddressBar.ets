import { prettyUrl } from '../common/UrlUtils';
import { ZFont, ZRadius, ZSize } from '../common/AiaTheme';

/**
 * 顶部搜索栏：只承载地址胶囊（编辑态变输入框）和加载进度条。
 * 返回/前进/主页/标签/菜单等操作全部在底部工具栏。
 */
@Component
export struct AddressBar {
  @Prop url: string;
  @Prop progress: number;
  @Prop loading: boolean;
  @Prop secure: boolean;
  @Prop home: boolean;

  onSubmit: (text: string) => void = () => {
  };

  @State editing: boolean = false;
  @State draft: string = '';

  @Builder
  pill() {
    Row({ space: 7 }) {
      Image(this.secure ? $r('app.media.ic_lock') : $r('app.media.ic_search'))
        .width(15)
        .height(15)
        .opacity(0.65)

      Text(this.home ? '搜索或输入网址' : prettyUrl(this.url))
        .fontSize(ZFont.callout)
        .fontColor(this.home ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Start)

      if (!this.home) {
        Image(this.loading ? $r('app.media.ic_close') : $r('app.media.ic_refresh'))
          .width(15)
          .height(15)
          .opacity(0.55)
      }
    }
    .width('100%')
    .height(ZSize.pill)
    .padding({ left: 13, right: 11 })
    .borderRadius(ZRadius.pill)
    .backgroundColor($r('app.color.surface_alt'))
    .onClick(() => {
      this.draft = this.url;
      this.editing = true;
    })
  }

  @Builder
  editor() {
    Row({ space: 4 }) {
      TextInput({ text: this.draft, placeholder: '搜索或输入网址' })
        .id('aia-address')
        .layoutWeight(1)
        .height(ZSize.pill)
        .padding({ left: 14, right: 12 })
        .borderRadius(ZRadius.pill)
        .backgroundColor($r('app.color.surface_alt'))
        .fontSize(ZFont.callout)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .caretColor($r('app.color.accent'))
        .enterKeyType(EnterKeyType.Go)
        .onChange((value: string) => {
          this.draft = value;
        })
        .onSubmit(() => {
          this.commit();
        })
        .onAppear(() => {
          this.getUIContext().getFocusController().requestFocus('aia-address');
        })

      Text('取消')
        .fontSize(ZFont.body)
        .fontColor($r('app.color.text_secondary'))
        .padding({ left: 6, right: 10 })
        .onClick(() => {
          this.editing = false;
        })
    }
    .width('100%')
  }

  private commit(): void {
    const text: string = this.draft.trim();
    this.editing = false;
    if (text.length === 0) {
      return;
    }
    this.onSubmit(text);
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Row() {
        if (this.editing) {
          this.editor();
        } else {
          this.pill();
        }
      }
      .width('100%')
      .height(ZSize.toolbar)
      .padding({ left: 10, right: 10 })

      // 加载进度：贴着底部分隔线，加载完自动消失
      if (this.loading && this.progress > 0 && this.progress < 100) {
        Row()
          .height(2)
          .width(this.progress + '%')
          .backgroundColor($r('app.color.accent'))
          .borderRadius(1)
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.surface'))
    .border({ width: { bottom: 0.5 }, color: $r('app.color.divider') });
  }
}
