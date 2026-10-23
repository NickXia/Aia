import { hostOf } from './UrlUtils';

/**
 * 导航决策纯函数模块（ADR-1）。
 *
 * 所有「内核回调能不能信」的判定集中在这里：深链手势门槛、scheme 白名单、
 * 错误信号归一化（ADR-3）、下载导航忽略窗口、全屏手势门槛。
 * 本模块不 import 任何 @kit / ArkUI / 装饰器能力（UrlUtils 也同为纯函数），
 * 可被 entry/src/test 的 hypium 本地单测直接覆盖——这是把它抽出来的全部目的：
 * 判定逻辑从 WebPane 的回调闭包里搬出来，变成可枚举测试用例的确定性函数。
 */

export type NavAction = 'pass' | 'block' | 'openApp';

export interface DeepLinkDecision {
  action: NavAction;
  /** 被拦截时是否给用户提示（一次性，冷却由调用方管理） */
  notify: boolean;
  /** openApp 时是否已过唤起冷却（false = 调用方应静默丢弃） */
  cooled: boolean;
}

/** Web 内核可直接加载的 scheme：一律放行，不做任何判定 */
export function isWebUrl(url: string): boolean {
  const lower: string = url.toLowerCase();
  return lower.startsWith('http://') || lower.startsWith('https://')
    || lower.startsWith('about:') || lower.startsWith('data:')
    || lower.startsWith('blob:') || lower.startsWith('javascript:');
}

/** 提取 url 的 scheme（小写；无 scheme 返回空串）。支持 openapp.jdmobile 这类带点 scheme */
export function schemeOf(url: string): string {
  const m: RegExpMatchArray | null = url.match(/^[a-zA-Z][a-zA-Z0-9+.\-]*:/);
  if (m === null || m.length === 0) {
    return '';
  }
  return m[0].substring(0, m[0].length - 1).toLowerCase();
}

/**
 * 深链 scheme 白名单：只有这些已知 App 的 scheme 才可能被唤起。
 * 未收录的自定义 scheme 一律留在网页内打开——白名单是深链防误跳的
 * 最后一道闸：即使页面自动触发 + 手势判定都有小概率放行，
 * 不在名单里的 scheme 也永远到不了 openLink。
 */
const DEEP_LINK_SCHEMES: Set<string> = new Set<string>([
  'zhihu', 'weibo', 'sinaweibo',
  'bilibili', 'biliapp',
  'taobao', 'tbopen', 'tmall',
  'alipay', 'alipays',
  'jd', 'openapp.jdmobile',
  'weixin', 'mqq', 'mqqapi',
  'snssdk1128', 'snssdk1233', 'douyinopensdk'
]);

export function isWhitelistedDeepLink(url: string): boolean {
  return DEEP_LINK_SCHEMES.has(schemeOf(url));
}

/** 手势门槛：用户 lastTouchAt 距 now 多少毫秒内算「真实触摸伴随」 */
export const GESTURE_WINDOW_MS: number = 1000;
/** 深链唤起冷却：防止 B站/知乎页面循环触发深链反复弹系统确认框 */
export const OPEN_LINK_COOLDOWN_MS: number = 6000;
/** 下载导航 start 后的错误忽略窗口：内核对未渲染主文档补发错误的时间上界 */
export const DL_ERROR_WINDOW_MS: number = 10000;

export function gestureFresh(lastTouchAt: number, now: number): boolean {
  return now - lastTouchAt < GESTURE_WINDOW_MS;
}

/**
 * 深链拦截决策（onLoadIntercept 的全部判定，WebPane 只做执行）。
 * 判定顺序即防线顺序：
 *   1. Web scheme        → 放行（浏览器本职）
 *   2. 非主帧自定义 scheme → 放行（子帧资源误杀会整页挂）
 *   3. 非白名单 scheme    → 拦截且不提示（静默留在网页）
 *   4. 白名单但无手势     → 拦截 + 提示（页面自动拉起 App 防御）
 *   5. 白名单 + 手势      → openApp（受唤起冷却约束）
 */
export function decideDeepLink(url: string, isMainFrame: boolean,
  touched: boolean, now: number, lastOpenLinkAt: number): DeepLinkDecision {
  if (isWebUrl(url)) {
    return { action: 'pass', notify: false, cooled: false };
  }
  if (!isMainFrame) {
    return { action: 'pass', notify: false, cooled: false };
  }
  if (!isWhitelistedDeepLink(url)) {
    return { action: 'block', notify: false, cooled: false };
  }
  if (!touched) {
    return { action: 'block', notify: true, cooled: false };
  }
  return {
    action: 'openApp',
    notify: false,
    cooled: now - lastOpenLinkAt > OPEN_LINK_COOLDOWN_MS
  };
}

/** 全屏请求手势门槛（onFullScreenEnter）：无触摸伴随的自动横幅全屏必须拒绝 */
export function shouldAllowFullscreen(lastTouchAt: number, now: number): boolean {
  return gestureFresh(lastTouchAt, now);
}

/**
 * 下载型导航的错误忽略窗口（onErrorReceive 最前置的判定）。
 * 内核接管下载后主文档不渲染，可能延迟补发错误——实测选择器开 25 秒仍会补发，
 * 所以选择器存活期（picking）无条件忽略，start 后给 10 秒窗口。
 */
export function shouldIgnoreDownloadNavError(picking: boolean, navAt: number, now: number): boolean {
  if (picking) {
    return true;
  }
  return navAt > 0 && now - navAt < DL_ERROR_WINDOW_MS;
}

/**
 * ADR-3 错误信号归一化：主文档失败 = 主帧错误。
 * isMainFrame 由内核直接给出，是确定性信号；hostOf 同域对比只是
 * isMainFrame 不可用（事件对象异常）时的降级回退，不再是主判据。
 *
 * @param isMainFrame true/false = 内核信号；null = 信号不可用，回退 hostOf 对比
 * @returns mainDoc=true 表示「当前主文档本身加载失败」→ 弹错误卡；
 *          false 表示资源级失败（CDN 媒体流等）→ 只结束加载圈
 */
export function classifyLoadError(errUrl: string, docUrl: string,
  isMainFrame: boolean | null): boolean {
  if (errUrl.length === 0) {
    return false;
  }
  // 自定义 scheme 的资源错误（bilibili:// 被拦截后的残余）不算主文档失败
  if (!isWebUrl(errUrl)) {
    return false;
  }
  if (isMainFrame !== null) {
    return isMainFrame;
  }
  // 降级回退：错误 url 与当前文档同 host 才认为主文档失败
  return docUrl.length > 0 && hostOf(errUrl) === hostOf(docUrl);
}

/** ADR-3 补充信号：主文档 HTTP 4xx/5xx（onHttpErrorReceive）是确定性失败 */
export function isMainDocHttpError(statusCode: number, isMainFrame: boolean): boolean {
  return isMainFrame && statusCode >= 400;
}
