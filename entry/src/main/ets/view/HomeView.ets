import { colorForHost, hostOf, prettyUrl } from '../common/UrlUtils';
import { ZFont, getUiScale } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/**
 * 新标签页（Aia 主页）—— Via 式极简：
 * 空白背景 + 居中 logo + 居中搜索框，无任何其他元素。
 */
@Component
export struct HomeView {
  onOpen: (url: string) => void = () => {
  };
  @State searchText: string = '';

  /** 回车提交：非空才导航，提交后清空输入框 */
  private submit(): void {
    const text: string = this.searchText.trim();
    if (text.length === 0) {
      return;
    }
    this.searchText = '';
    this.onOpen(text);
  }

  build() {
    Column() {
      // 内容整体略高于屏幕中心（对齐 Via 的视觉位置）
      Column({ space: 34 }) {
        // 浏览器 logo
        Image($r('app.media.app_icon'))
          .width(Math.round(92 * getUiScale()))
          .height(Math.round(92 * getUiScale()))
          .borderRadius(Math.round(22 * getUiScale()))
          .shadow(ShadowStyle.OUTER_DEFAULT_MD)
          .draggable(false)

        // 居中搜索框：回车 / 完成即导航
        TextInput({ text: this.searchText, placeholder: '搜索或输入网址' })
          .type(InputType.Normal)
          .enterKeyType(EnterKeyType.Search)
          .fontSize(Math.round(15 * getUiScale()))
          .fontColor(C('text_primary'))
          .placeholderColor(C('text_tertiary'))
          .placeholderFont({ size: Math.round(15 * getUiScale()) })
          .caretColor(C('accent'))
          .textAlign(TextAlign.Start)
          .padding({ left: 20, right: 20 })
          .height(Math.round(48 * getUiScale()))
          .borderRadius(Math.round(24 * getUiScale()))
          .backgroundColor(C('surface'))
          .border({ width: 1, color: C('divider') })
          .width('100%')
          .onChange((value: string) => {
            this.searchText = value;
          })
          .onSubmit(() => this.submit())
      }
      .width('82%')
      .margin({ bottom: 96 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Color.Transparent)
  }
}
