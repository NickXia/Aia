/**
 * Aia 设计变量
 * 颜色统一走 resources/base|dark/element/color.json，随系统深浅色自动切换。
 * 这里只放尺寸、圆角、字重等与主题无关的量。
 *
 * 关怀模式（老年人模式）：所有字号/图标/触控目标按 uiScale 整体放大，
 * 通过 setUiScale() 切换；调用方负责在切换后重建 UI 树（Index.uiEpoch）。
 */
let uiScale: number = 1;

export function setUiScale(s: number): void {
  uiScale = s <= 0 ? 1 : s;
}

export function getUiScale(): number {
  return uiScale;
}

/** 按当前缩放因子取整数值（字号/图标/触控目标通用） */
export function vs(base: number): number {
  return Math.round(base * uiScale);
}

export class ZSpace {
  static get xs(): number { return vs(4); }
  static get sm(): number { return vs(8); }
  static get md(): number { return vs(12); }
  static get lg(): number { return vs(16); }
  static get xl(): number { return vs(20); }
  static get xxl(): number { return vs(28); }
  static get page(): number { return vs(18); }
}

export class ZRadius {
  static get pill(): number { return 100; }
  static get card(): number { return vs(18); }
  static get sheet(): number { return vs(28); }
  static get small(): number { return vs(12); }
}

export class ZFont {
  static get caption(): number { return vs(11); }
  static get footnote(): number { return vs(12); }
  static get body(): number { return vs(15); }
  static get callout(): number { return vs(15); }
  static get heading(): number { return vs(17); }
  static get title(): number { return vs(19); }
  static get display(): number { return vs(30); }
}

/**
 * 字重规范（全体组件统一引用，禁止魔法数字）：
 * Regular 400 正文 / Medium 500 强调与按钮 / Semibold 600 标题 / Bold 700 数字与首字母
 */
export class ZWeight {
  static readonly regular: FontWeight = FontWeight.Regular;
  static readonly medium: FontWeight = FontWeight.Medium;
  static readonly semibold: FontWeight = FontWeight.Medium; // ArkUI 无 600，用 Medium+大一号表达
  static readonly bold: FontWeight = FontWeight.Bold;
}

export class ZSize {
  static get toolbar(): number { return vs(52); }
  static get pill(): number { return vs(38); }
  static get iconButton(): number { return vs(38); }
  static get icon(): number { return vs(21); }
}

/**
 * 主题引擎：
 * - 'system'    普通模式：跟随系统深浅色（色板与 color.json 一致）
 * - 'parchment' 阅读模式：羊皮卷暖色，不受系统深浅色影响
 * 视图统一用 C(role) 取色；主题切换后由调用方重建 UI 树（Index.uiEpoch）。
 */
export type ThemeMode = 'system' | 'parchment';

let themeMode: ThemeMode = 'system';

export function setThemeMode(m: ThemeMode): void {
  themeMode = m;
}

export function getThemeMode(): ThemeMode {
  return themeMode;
}

const SYS_LIGHT: Record<string, string> = {
  'page_bg': '#F7F8FC',
  'surface': '#FFFFFF',
  'surface_alt': '#EEF1F8',
  'surface_alt_2': '#E2E7F2',
  'divider': '#E6E9F2',
  'text_primary': '#16181D',
  'text_secondary': '#4D5464',
  'text_tertiary': '#98A0B0',
  'accent': '#4F6BFF',
  'accent_2': '#9B5CFF',
  'danger': '#E5484D',
  'seal': '#4F6BFF',
  'scrim': '#14161F99'
};

const SYS_DARK: Record<string, string> = {
  'page_bg': '#101319',
  'surface': '#181C26',
  'surface_alt': '#222734',
  'surface_alt_2': '#2C3240',
  'divider': '#272D3A',
  'text_primary': '#F2F4FA',
  'text_secondary': '#BAC0CE',
  'text_tertiary': '#7E8594',
  'accent': '#7C9AFF',
  'accent_2': '#B08CFF',
  'danger': '#FF6B6E',
  'seal': '#7C9AFF',
  'scrim': '#CC000510'
};

/** 羊皮卷阅读主题：暖纸底 + 深棕墨字 + 皮革棕强调，昼夜通用 */
const PARCHMENT: Record<string, string> = {
  'page_bg': '#F0E6CE',
  'surface': '#F6EDD8',
  'surface_alt': '#E9DCBB',
  'surface_alt_2': '#DFCFA6',
  'divider': '#D8C69C',
  'text_primary': '#3F2F1D',
  'text_secondary': '#66513A',
  'text_tertiary': '#8C7752',
  'accent': '#8C5A2B',
  'danger': '#A8432E',
  'seal': '#8C4A2F',
  'scrim': '#5C3A241C'
};

/** 语义色取值入口：所有视图经此取色，替代 $r('app.color.*') */
export function C(role: string): ResourceColor {
  if (themeMode === 'parchment') {
    return PARCHMENT[role] ?? '#F0E6CE';
  }
  const dark: boolean = AppStorage.get<boolean>('isDark') === true;
  return dark ? (SYS_DARK[role] ?? '#1C1C1A') : (SYS_LIGHT[role] ?? '#F8F5EC');
}
