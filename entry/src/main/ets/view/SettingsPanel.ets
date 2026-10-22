import { ENGINES, SearchEngine } from '../common/SearchEngine';
import { prettyUrl } from '../common/UrlUtils';
import { fileUri } from '@kit.CoreFileKit';
import { ZFont, ZRadius, ZSpace, getUiScale } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

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
  @Prop elderMode: boolean;
  @Prop readingTheme: boolean;
  @Prop desktopUA: boolean;
  @Prop debugH5: boolean;
  @Prop downloadAskMode: boolean;

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
      .fontColor(C('text_tertiary'))
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
            .fontColor(C('text_primary'))
            .width('100%')
            .textAlign(TextAlign.Start)
          if (desc.length > 0) {
            Text(desc)
              .fontSize(Math.round(10 * getUiScale()))
              .fontColor(C('text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.Start)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Toggle({ type: ToggleType.Switch, isOn: value })
          .selectedColor(C('accent'))
          .width(44)
          .height(26)
          .onChange((isOn: boolean) => this.onToggle(key, isOn))
      }
      .width('100%')
      .padding({ top: 11, bottom: 11 })

      if (!last) {
        Divider()
          .color(C('divider'))
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
          .fontColor(C('text_primary'))
          .layoutWeight(1)
          .textAlign(TextAlign.Start)

        Text(this.engineName)
          .fontSize(ZFont.body)
          .fontColor(C('text_secondary'))

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
                ? C('accent') : C('text_secondary'))
              .layoutWeight(1)
              .textAlign(TextAlign.Start)

            if (engine.name === this.engineName) {
              Image($r('app.media.ic_check'))
                .width(15)
                .height(15)
                .fillColor(C('accent'))
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
          Text('设置')
            .fontSize(ZFont.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(C('text_primary'))

          Blank()

          Text('完成')
            .fontSize(ZFont.body)
            .fontColor(C('accent'))
            .padding({ left: 10, right: 4, top: 6, bottom: 6 })
            .onClick(() => this.onClose())
        }
        .width('100%')
        .padding({ left: ZSpace.page, right: ZSpace.md })

        Scroll() {
          Column() {
            // 关怀模式（老年人模式）：微信式开关，切换后全局字号与按钮放大
            this.sectionTitle('关怀模式');
            Column() {
              Row({ space: 12 }) {
                Column({ space: 2 }) {
                  Text('长辈模式')
                    .fontSize(ZFont.body)
                    .fontColor(C('text_primary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                  Text(this.elderMode ? '已开启：字体和按钮已放大' : '整个应用的字体和按钮变大，适合长辈使用')
                    .fontSize(Math.round(10 * getUiScale()))
                    .fontColor(this.elderMode ? C('accent') : C('text_tertiary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text('Aa')
                  .fontSize(this.elderMode ? 20 : 15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(C('text_primary'))

                Toggle({ type: ToggleType.Switch, isOn: this.elderMode })
                  .selectedColor(C('accent'))
                  .width(44)
                  .height(26)
                  .onChange((isOn: boolean) => this.onToggle('elderMode', isOn))
              }
              .width('100%')
              .padding({ top: 11, bottom: 11 })
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(14)
            .backgroundColor(C('surface_alt'))

            // 主题：普通（跟随系统）/ 阅读模式（羊皮卷）
            this.sectionTitle('主题');
            Column() {
              Row({ space: 12 }) {
                Column({ space: 2 }) {
                  Text('阅读模式')
                    .fontSize(ZFont.body)
                    .fontColor($r('app.color.text_primary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                  Text(this.readingTheme ? '已启用羊皮卷配色' : '羊皮纸暖色配色，适合长时间阅读')
                    .fontSize(10)
                    .fontColor(this.readingTheme ? $r('app.color.accent') : $r('app.color.text_tertiary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: this.readingTheme })
                  .selectedColor($r('app.color.accent'))
                  .width(44)
                  .height(26)
                  .onChange((isOn: boolean) => this.onToggle('readingTheme', isOn))
              }
              .width('100%')
              .padding({ top: 11, bottom: 11 })
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(14)
            .backgroundColor($r('app.color.surface_alt'))

            // 下载
            this.sectionTitle('下载');
            Column() {
              Row({ space: 12 }) {
                Column({ space: 2 }) {
                  Text('下载位置')
                    .fontSize(ZFont.body)
                    .fontColor(C('text_primary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                  Text(this.downloadAskMode ? '每次下载完成后选择保存位置' : '应用目录（自动导出到文件管理）')
                    .fontSize(Math.round(10 * getUiScale()))
                    .fontColor(C('text_tertiary'))
                    .width('100%')
                    .textAlign(TextAlign.Start)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: this.downloadAskMode })
                  .selectedColor(C('accent'))
                  .width(44)
                  .height(26)
                  .onChange((isOn: boolean) => this.onToggle('askMode', isOn))
              }
              .width('100%')
              .padding({ top: 11, bottom: 11 })
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor(C('surface_alt'))

            // 搜索
            this.sectionTitle('搜索');
            Column() {
              this.engineRow()
              Divider().color(C('divider')).strokeWidth(0.5)
              Row() {
                Text('主页')
                  .fontSize(ZFont.body)
                  .fontColor(C('text_primary'))
                  .layoutWeight(1)
                  .textAlign(TextAlign.Start)
                Text(prettyUrl(this.homepage))
                  .fontSize(ZFont.footnote)
                  .fontColor(C('text_secondary'))
                  .maxLines(1)
                  .constraintSize({ maxWidth: '55%' })
              }
              .width('100%')
              .height(46)
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor(C('surface_alt'))

            // 隐私与显示
            this.sectionTitle('隐私与显示');
            Column() {
              this.switchRow('阻止图片加载', '省流量，弱网下更快', this.blockImages, 'blockImages', false)
              this.switchRow('保存浏览记录', '', this.saveHistory, 'saveHistory', false)
              this.switchRow('允许 JavaScript', '关闭后部分网页无法正常显示', this.jsEnabled, 'js', false)
              this.switchRow('桌面版网页', '以电脑版方式浏览网页', this.desktopUA, 'desktopUA', false)
            this.switchRow('H5 远程调试', '开启后可用 PC Chrome 调试网页（见下方说明）', this.debugH5, 'debugH5', true)

            if (this.debugH5) {
              Column({ space: 4 }) {
                Text('调试方法：')
                  .fontSize(Math.round(10 * getUiScale()))
                  .fontColor(C('text_secondary'))
                  .width('100%')
                  .textAlign(TextAlign.Start)
                Text('1. 电脑连接手机后执行：hdc fport tcp:9222 tcp:9222\n2. 电脑 Chrome 打开 chrome://inspect\n3. 在列表中点击页面下的 inspect 即可调试')
                  .fontSize(Math.round(10 * getUiScale()))
                  .fontColor(C('text_tertiary'))
                  .width('100%')
                  .textAlign(TextAlign.Start)
              }
              .width('100%')
              .padding({ top: 8, bottom: 10 })
            }
            }
            .width('100%')
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor(C('surface_alt'))

            // 外观
            this.sectionTitle('外观');
            Column() {
              Row({ space: 12 }) {
                if (this.bgPath.length > 0) {
                  Image(fileUri.getUriFromPath(this.bgPath))
                    .width(40)
                    .height(40)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)
                } else {
                  Stack() {
                    Text('景')
                      .fontSize(Math.round(14 * getUiScale()))
                      .fontFamily('serif')
                      .fontColor(C('text_tertiary'))
                  }
                  .width(40)
                  .height(40)
                  .borderRadius(8)
                  .backgroundColor(C('surface_alt_2'))
                }

                Column({ space: 2 }) {
                  Text('自定义主页背景')
                    .fontSize(ZFont.body)
                    .fontColor(C('text_primary'))
                    .textAlign(TextAlign.Start)
                  Text(this.bgPath.length > 0 ? '已使用自定义图片' : '支持 jpg / png / webp / gif 等常见格式')
                    .fontSize(Math.round(10 * getUiScale()))
                    .fontColor(C('text_tertiary'))
                    .textAlign(TextAlign.Start)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Text(this.bgPath.length > 0 ? '更换' : '选择')
                  .fontSize(ZFont.body)
                  .fontColor(C('accent'))
                  .padding({ left: 8, right: 8, top: 6, bottom: 6 })
                  .onClick(() => this.onPickBackground())

                if (this.bgPath.length > 0) {
                  Text('恢复')
                    .fontSize(ZFont.body)
                    .fontColor(C('text_secondary'))
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
            .backgroundColor(C('surface_alt'))

            // 数据
            this.sectionTitle('数据');
            Column() {
              Row() {
                Text('清除浏览记录')
                  .fontSize(ZFont.body)
                  .fontColor(C('danger'))
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
            .backgroundColor(C('surface_alt'))

            // 关于
            this.sectionTitle('关于');
            Row() {
              Text('Aia 浏览器')
                .fontSize(ZFont.body)
                .fontColor(C('text_primary'))
                .layoutWeight(1)
                .textAlign(TextAlign.Start)
              Text('1.0.0')
                .fontSize(ZFont.footnote)
                .fontColor(C('text_tertiary'))
            }
            .width('100%')
            .height(46)
            .padding({ left: 14, right: 14 })
            .borderRadius(ZRadius.card)
            .backgroundColor(C('surface_alt'))

            Text('基于 HarmonyOS ArkWeb 内核')
              .fontSize(Math.round(10 * getUiScale()))
              .fontColor(C('text_tertiary'))
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
      .backgroundColor(C('page_bg'))
      .transition(TransitionEffect.move(TransitionEdge.BOTTOM)
        .animation({ duration: 260, curve: Curve.FastOutSlowIn }))
    }
    .width('100%')
    .height('100%')
    .transition(TransitionEffect.OPACITY.animation({ duration: 180 }))
  }
}
