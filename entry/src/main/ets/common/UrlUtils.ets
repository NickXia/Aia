import { SearchEngine } from './SearchEngine';

const SCHEME: RegExp = new RegExp('^[a-zA-Z][a-zA-Z0-9+.\\-]*:\\/\\/', 'i');
const IP_LIKE: RegExp = new RegExp('^(localhost|((\\d{1,3}\\.){3}\\d{1,3}))(:\\d+)?(\\/.*)?$', 'i');
const DOMAIN_LIKE: RegExp = new RegExp('^([\\w\\-]+\\.)+[a-zA-Z]{2,}(:\\d+)?(\\/.*)?$');
const HOST: RegExp = new RegExp('^[a-zA-Z][a-zA-Z0-9+.\\-]*:\\/\\/([^\\/:?#]+)', 'i');

/** 判断输入是否像一个网址而不是搜索词 */
export function looksLikeUrl(text: string): boolean {
  const t: string = text.trim();
  if (t.length === 0 || t.indexOf(' ') >= 0) {
    return false;
  }
  if (SCHEME.test(t)) {
    return true;
  }
  if (IP_LIKE.test(t)) {
    return true;
  }
  return DOMAIN_LIKE.test(t);
}

/** 把地址栏输入转换成最终要加载的 URL */
export function resolveInput(text: string, engine: SearchEngine): string {
  const t: string = text.trim();
  if (t.length === 0) {
    return '';
  }
  if (SCHEME.test(t)) {
    return t;
  }
  if (looksLikeUrl(t)) {
    // 本机地址默认走 http，其余走 https
    if (t.indexOf('localhost') === 0 || IP_LIKE.test(t)) {
      return 'http://' + t;
    }
    return 'https://' + t;
  }
  return engine.template.replace('%s', encodeURIComponent(t));
}

/** 地址栏中展示用：去掉协议与末尾斜杠 */
export function prettyUrl(url: string): string {
  if (url.length === 0) {
    return '';
  }
  let u: string = url.replace(new RegExp('^[a-zA-Z][a-zA-Z0-9+.\\-]*:\\/\\/', 'i'), '');
  if (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/** 取域名，用于标签卡片与书签列表 */
export function hostOf(url: string): string {
  const m: RegExpMatchArray | null = url.match(HOST);
  if (m !== null && m.length > 1) {
    return m[1];
  }
  return prettyUrl(url);
}

export function isSecure(url: string): boolean {
  return url.toLowerCase().indexOf('https://') === 0;
}

/** 用域名生成稳定的占位色，标签卡片 / 站点图标用 */
const PALETTE: string[] = [
  '#4F6BFF', '#8B5CF6', '#FF5C5C', '#00C48C',
  '#FF9F43', '#00A8E8', '#E84393', '#5B6B7F'
];

export function colorForHost(host: string): string {
  let h: number = 0;
  for (let i = 0; i < host.length; i++) {
    h = (h * 31 + host.charCodeAt(i)) % 100000;
  }
  return PALETTE[h % PALETTE.length];
}

/** 站点首字母，用于占位图标 */
export function initialOf(host: string): string {
  const clean: string = host.replace(new RegExp('^www\\.', 'i'), '');
  if (clean.length === 0) {
    return 'Z';
  }
  return clean.substring(0, 1).toUpperCase();
}
