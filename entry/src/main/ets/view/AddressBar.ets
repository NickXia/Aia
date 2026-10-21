import { prettyUrl, isSecure } from '../common/UrlUtils';
import { BrowserTab } from '../model/Models';
import { ZFont, ZRadius, ZSize } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/**
 * 顶部搜索栏：地址胶囊（编辑态变输入框）+ 加载进度条。
 * 直接 @ObjectLink 绑定活动标签，加载进度/网址/安全态全部实时响应，
 * 不经过父组件转发（@Prop 转发在父组件重渲染前会冻结）。
 */
@Component
export struct AddressBar {
  @ObjectLink tab: BrowserTab;
  @Prop home: boolean;

  onSubmit: (text: string) => void = () => {
  };

  @State editing: boolean = false;
  @State draft: string = '';

  @Builder
  pill() {
    Row({ space: 7 }) {
      Image(isSecure(this.tab.url) ? $r('app.media.ic_lock') : $r('app.media.ic_search'))
        .width(15)
        .height(15)
        .opacity(0.65)

      Text(this.home ? '搜索或输入网址' : prettyUrl(this.tab.url))
        .fontSize(ZFont.callout)
        .fontColor(this.home ? C('text_tertiary') : C('text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .textAlign(TextAlign.Start)

      if (!this.home) {
        Image(this.tab.isLoading ? $r('app.media.ic_close') : $r('app.media.ic_refresh'))
          .width(15)
          .height(15)
          .opacity(0.55)
      }
    }
    .width('100%')
    .height(ZSize.pill)
    .padding({ left: 13, right: 11 })
    .borderRadius(ZRadius.pill)
    .backgroundColor(C('surface_alt'))
    .onClick(() => {
      // 点击进入编辑态时清空草稿：用户点击地址栏的意图是「新搜索/新网址」，
      // 预填旧 URL 会导致打字追加到原网址后面（真实场景产生 404/400）
      this.draft = '';
      this.editing = true;
    })
  }

  @Builder
  editor() {
    Row({ space: 4 }) {
      TextInput({ text: this.draft, placeholder: this.home ? '搜索或输入网址' : prettyUrl(this.tab.url) })
        .id('aia-address')
        .layoutWeight(1)
        .height(ZSize.pill)
        .padding({ left: 14, right: 12 })
        .borderRadius(ZRadius.pill)
        .backgroundColor(C('surface_alt'))
        .fontSize(ZFont.callout)
        .fontColor(C('text_primary'))
        .placeholderColor(C('text_tertiary'))
        .caretColor(C('accent'))
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
        .fontColor(C('text_secondary'))
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

      // 加载进度：贴着底部分隔线。导航一开始就显示（最窄 4%），
      // 由 @ObjectLink 实时驱动，完成即消失
      if (!this.home && this.tab.isLoading) {
        Row()
          .height(2)
          .width(Math.max(this.tab.progress, 4) + '%')
          .backgroundColor(C('accent'))
          .borderRadius(1)
      }
    }
    .width('100%')
    .backgroundColor(C('surface'))
    .border({ width: { bottom: 0.5 }, color: C('divider') });
  }
}
