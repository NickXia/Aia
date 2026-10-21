import { ZFont, ZRadius, ZSpace } from '../common/AiaTheme';
import { C } from '../common/AiaTheme';

/**
 * 快捷方式编辑面板：编辑名称/网址，可删除。
 * isEditing=false 表示新增。
 */
@Component
export struct DialEditSheet {
  @Prop isEditing: boolean;
  @Prop editName: string;
  @Prop editUrl: string;
  onDelete: () => void = () => {
  };
  onSave: (name: string, url: string) => void = () => {
  };
  onClose: () => void = () => {
  };

  @State draftName: string = '';
  @State draftUrl: string = '';

  aboutToAppear(): void {
    this.draftName = this.editName;
    this.draftUrl = this.editUrl;
  }

  /** 回车即保存（键盘收起状态下也可直接点保存按钮） */
  private submit(): void {
    this.onSave(this.draftName.trim(), this.draftUrl.trim());
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
          if (this.isEditing) {
            Text('删除')
              .fontSize(ZFont.body)
              .fontColor(C('danger'))
              .padding({ left: 4, right: 10, top: 6, bottom: 6 })
              .onClick(() => this.onDelete())
          } else {
            Text('取消')
              .fontSize(ZFont.body)
              .fontColor(C('text_secondary'))
              .padding({ left: 4, right: 10, top: 6, bottom: 6 })
              .onClick(() => this.onClose())
          }

          Blank()

          Text(this.isEditing ? '编辑快捷方式' : '添加快捷方式')
            .fontSize(ZFont.title)
            .fontWeight(FontWeight.Medium)
            .fontColor(C('text_primary'))

          Blank()

          Text('保存')
            .fontSize(ZFont.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(C('accent'))
            .padding({ left: 10, right: 4, top: 6, bottom: 6 })
            .onClick(() => this.submit())
        }
        .width('100%')
        .padding({ left: ZSpace.md, right: ZSpace.md, top: 6, bottom: 10 })

        Column({ space: 10 }) {
          Column({ space: 5 }) {
            Text('名称')
              .fontSize(10)
              .fontColor(C('text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.Start)
            TextInput({ text: this.draftName, placeholder: '如：哔哩哔哩' })
              .height(42)
              .borderRadius(12)
              .backgroundColor(C('surface_alt'))
              .fontSize(ZFont.body)
              .fontColor(C('text_primary'))
              .placeholderColor(C('text_tertiary'))
              .enterKeyType(EnterKeyType.Done)
              .onChange((v: string) => {
                this.draftName = v;
              })
              .onSubmit(() => this.submit())
          }
          .width('100%')

          Column({ space: 5 }) {
            Text('网址')
              .fontSize(10)
              .fontColor(C('text_tertiary'))
              .width('100%')
              .textAlign(TextAlign.Start)
            TextInput({ text: this.draftUrl, placeholder: '如：m.bilibili.com' })
              .height(42)
              .borderRadius(12)
              .backgroundColor(C('surface_alt'))
              .fontSize(ZFont.body)
              .fontColor(C('text_primary'))
              .placeholderColor(C('text_tertiary'))
              .enterKeyType(EnterKeyType.Done)
              .onChange((v: string) => {
                this.draftUrl = v;
              })
              .onSubmit(() => this.submit())
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: ZSpace.page, right: ZSpace.page })

      }
      .width('100%')
      .padding({ top: 10, bottom: 40 })
      .borderRadius({ topLeft: ZRadius.sheet, topRight: ZRadius.sheet })
      .backgroundColor(C('surface'))
    }
    .width('100%')
    .height('100%')
  }
}
