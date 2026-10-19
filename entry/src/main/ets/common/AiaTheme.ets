/**
 * Aia 设计变量
 * 颜色统一走 resources/base|dark/element/color.json，随系统深浅色自动切换。
 * 这里只放尺寸、圆角、字重等与主题无关的量。
 */
export class ZSpace {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly md: number = 12;
  static readonly lg: number = 16;
  static readonly xl: number = 20;
  static readonly xxl: number = 28;
  static readonly page: number = 18;
}

export class ZRadius {
  static readonly pill: number = 100;
  static readonly card: number = 16;
  static readonly sheet: number = 24;
  static readonly small: number = 10;
}

export class ZFont {
  static readonly caption: number = 11;
  static readonly footnote: number = 12;
  static readonly body: number = 14;
  static readonly callout: number = 15;
  static readonly title: number = 17;
  static readonly display: number = 30;
}

export class ZSize {
  static readonly toolbar: number = 52;
  static readonly pill: number = 38;
  static readonly iconButton: number = 38;
  static readonly icon: number = 21;
}
