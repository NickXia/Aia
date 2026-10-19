import { ENGINES, SearchEngine } from '../common/SearchEngine';
import { prettyUrl } from '../common/UrlUtils';
import { ZFont, ZRadius, ZSpace } from '../common/AiaTheme';

/**
 * 设置面板。只放真正会改行为的开关，不堆砌选项。
 */
@Component
export struct SettingsPanel {
  @Prop engineName: string;
  @Prop homepage: string;
  @Prop blockImages: boolean;
  @Prop saveHistory: boolean;
  @Prop jsEnabled: boolean;
  @Prop dnt: boolean;
  @Prop bgPath: string;

  onToggle: (key: string, value: boolean) => void = () => {
  };
  onPickEngine: (index: number) => void = () => {
  };
  onClearHistory: () => void = () => {
  };
  onPickBackground: () => void = () => {
  };
  onClearBackground: () => void = () => {
  };
  onClose: () => void = () => {
  };

  @State expandEngines: boolean = false;

  @Builder
  sectionTitle(text: string) {
    Text(text)
      .fontSize(ZFont.caption)
      .fontColor($r('app.color.text_tertiary'))
      .width('100%')
      .textAlign(TextAlign.Start)
      .padding({ left: 4, top: 18, bottom: 7 })
  }

  @Builder
  switchRow(label: string, desc: string, value: boolean, key: string, last: boolean) {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 2 }) {
          Text(label)
            .fontSize(ZFont.body)
            .fontColor($r('app.color.text_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)
          if (desc.length > 0) {
            Text(desc)
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.Start)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: value })
          .selectedColor($r('app.color.accent'))
          .width(44)
          .height(26)
          .onChange((isOn: boolean) => this.onToggle(key, isOn))
      }
      .width('100%')
      .padding({ top: 11, bottom: 11 })

      if (!last) {
        Divider()
          .color($r('app.color.divider'))
          .strokeWidth(0.5)
      }
    }
    .width('100%')
  }

  @Builder
  engineRow() {
    Column() {
      Row() {
        Text('搜索引擎')
          .fontSize(ZFont.body)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)

        Text(this.engineName)
          .fontSize(ZFont.body)
          .fontColor($r('app.color.text_secondary'))

        Image($r('app.media.ic_chevron_right'))
          .width(14)
          .height(14)
          .opacity(0.4)
          .margin({ left: 4 })
          .rotate({ angle: this.expandEngines ? 90 : 0 })
      }
      .width('100%')
      .height(46)
      .onClick(() => {
        this.expandEngines = !this.expandEngines;
      })

      if (this.expandEngines) {
        ForEach(ENGINES, (engine: SearchEngine, index: number) => {
          Row() {
            Text(engine.name)
              .fontSize(ZFont.body)
              .fontColor(engine.name === this.engineName
                ? $r('app.color.accent') : $r('app.color.text_secondary'))
              .layoutWeight(1)
              .textAlign(TextAlign.Start)

            if (engine.name === this.engineName) {
              Image($r('app.media.ic_check'))
                .width(15)
                .height(15)
                .fillColor($r('app.color.accent'))
            }
          }
          .width('100%')
          .height(40)
          .onClick(() => {
            this.onPickEngine(index);
            this.expandEngines = false;
          })
        }, (engine: SearchEngine) => engine.name)
      }
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.scrim'))
        .onClick(() => this.onClose())

      Column() {
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
          Text('设置')
            .fontSize(ZFont.title)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))

          Blank()

          Text('完成')
            .fontSize(ZFont.body)
            .fontColor($r('app.color.accent'))
            .padding({ left: 10, right: 4, top: 6, bottom: 6 })
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: ZSpace.page, right: ZSpace.md })

        Scroll() {
          Column() {
            // 搜索
            this.sectionTitle('搜索');
            Column() {
              this.engineRow()
              Divider().color($r('app.color.divider')).strokeWidth(0.5)
              Row() {
                Text('主页')
                  .fontSize(ZFont.body)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                  .textAlign(TextAlign.Start)
                Text(prettyUrl(this.homepage))
                  .fontSize(ZFont.footnote)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .constraintSize({ maxWidth: '55%' })
              }
              .width('100%')
              .height(46)
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor($r('app.color.surface_alt'))

            // 隐私与显示
            this.sectionTitle('隐私与显示');
            Column() {
              this.switchRow('阻止图片加载', '省流量，弱网下更快', this.blockImages, 'blockImages', false)
              this.switchRow('保存浏览记录', '', this.saveHistory, 'saveHistory', false)
              this.switchRow('允许 JavaScript', '关闭后部分网页无法正常显示', this.jsEnabled, 'js', false)
              this.switchRow('发送「不追踪」请求', '', this.dnt, 'dnt', true)
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor($r('app.color.surface_alt'))

            // 外观
            this.sectionTitle('外观');
            Column() {
              Row({ space: 12 }) {
                if (this.bgPath.length > 0) {
                  Image('file://' + this.bgPath)
                    .width(40)
                    .height(40)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)
                } else {
                  Stack() {
                    Text('景')
                      .fontSize(14)
                      .fontFamily('serif')
                      .fontColor($r('app.color.text_tertiary'))
                  }
                  .width(40)
                  .height(40)
                  .borderRadius(8)
                  .backgroundColor($r('app.color.surface_alt_2'))
                }

                Column({ space: 2 }) {
                  Text('自定义主页背景')
                    .fontSize(ZFont.body)
                    .fontColor($r('app.color.text_primary'))
                    .textAlign(TextAlign.Start)
                  Text(this.bgPath.length > 0 ? '已使用自定义图片' : '支持 jpg / png / webp / gif 等常见格式')
                    .fontSize(10)
                    .fontColor($r('app.color.text_tertiary'))
                    .textAlign(TextAlign.Start)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(this.bgPath.length > 0 ? '更换' : '选择')
                  .fontSize(ZFont.body)
                  .fontColor($r('app.color.accent'))
                  .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .onClick(() => this.onPickBackground())

                if (this.bgPath.length > 0) {
                  Text('恢复')
                    .fontSize(ZFont.body)
                    .fontColor($r('app.color.text_secondary'))
                    .padding({ left: 4, right: 8, top: 6, bottom: 6 })
                    .onClick(() => this.onClearBackground())
                }
              }
              .width('100%')
              .height(56)
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor($r('app.color.surface_alt'))

            // 数据
            this.sectionTitle('数据');
            Column() {
              Row() {
                Text('清除浏览记录')
                  .fontSize(ZFont.body)
                  .fontColor($r('app.color.danger'))
                  .layoutWeight(1)
                  .textAlign(TextAlign.Start)
              }
              .width('100%')
              .height(46)
              .onClick(() => this.onClearHistory())
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor($r('app.color.surface_alt'))

            // 关于
            this.sectionTitle('关于');
            Row() {
              Text('Aia 浏览器')
                .fontSize(ZFont.body)
                .fontColor($r('app.color.text_primary'))
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
              Text('1.0.0')
                .fontSize(ZFont.footnote)
                .fontColor($r('app.color.text_tertiary'))
            }
            .width('100%')
            .height(46)
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor($r('app.color.surface_alt'))

            Text('基于 HarmonyOS ArkWeb 内核')
              .fontSize(10)
              .fontColor($r('app.color.text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 18, bottom: 10 })
          }
          .width('100%')
          .padding({ left: ZSpace.page, right: ZSpace.page })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .align(Alignment.Top)
      }
      .width('100%')
      .height('86%')
      .borderRadius({ topLeft: ZRadius.sheet, topRight: ZRadius.sheet })
      .backgroundColor($r('app.color.page_bg'))
      .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        .animation({ duration: 260, curve: Curve.FastOutSlowIn }))
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 180 }))
  }
}
