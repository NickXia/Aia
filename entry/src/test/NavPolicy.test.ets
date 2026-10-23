import { describe, it, expect } from '@ohos/hypium';
import {
  isWebUrl, schemeOf, isWhitelistedDeepLink, decideDeepLink,
  classifyLoadError, shouldIgnoreDownloadNavError,
  shouldAllowFullscreen, isMainDocHttpError
} from '../main/ets/common/NavigationPolicy';

/**
 * NavigationPolicy 纯函数单测（ADR-1 产物）。
 * 本文件与被测模块都不 import @kit —— 这是 src/test 本地单测能跑的前提。
 */
export default describe('navPolicyTest', () => {
  const NOW: number = 1_000_000;

  it('schemeOf_basic', 0, () => {
    expect(schemeOf('zhihu://question/123?x=1')).assertEqual('zhihu');
    expect(schemeOf('openapp.jdmobile://virtual?params=1')).assertEqual('openapp.jdmobile');
    expect(schemeOf('HTTPS://example.com')).assertEqual('https');
    expect(schemeOf('www.baidu.com/s?wd=x')).assertEqual('');
    expect(schemeOf('')).assertEqual('');
  });

  it('isWebUrl_cases', 0, () => {
    expect(isWebUrl('http://a.com')).assertTrue();
    expect(isWebUrl('https://a.com/x?y=1')).assertTrue();
    expect(isWebUrl('about:blank')).assertTrue();
    expect(isWebUrl('data:text/html,x')).assertTrue();
    expect(isWebUrl('blob:https://a.com/id')).assertTrue();
    expect(isWebUrl('javascript:void(0)')).assertTrue();
    expect(isWebUrl('zhihu://question/1')).assertFalse();
    expect(isWebUrl('')).assertFalse();
  });

  it('deepLink_whitelist', 0, () => {
    expect(isWhitelistedDeepLink('zhihu://question/1')).assertTrue();
    expect(isWhitelistedDeepLink('bilibili://video/BV1x')).assertTrue();
    expect(isWhitelistedDeepLink('alipays://platformapi/startapp')).assertTrue();
    expect(isWhitelistedDeepLink('openapp.jdmobile://virtual?params={"category":"jump"}')).assertTrue();
    expect(isWhitelistedDeepLink('weixin://dl/chat')).assertTrue();
    // 未收录的自定义 scheme：一律不唤起
    expect(isWhitelistedDeepLink('unknownapp://page')).assertFalse();
    expect(isWhitelistedDeepLink('evilapp://steal')).assertFalse();
    // Web url 不属于深链范畴
    expect(isWhitelistedDeepLink('https://www.zhihu.com')).assertFalse();
  });

  it('decideDeepLink_webAlwaysPass', 0, () => {
    const d = decideDeepLink('https://www.baidu.com', true, false, NOW, 0);
    expect(d.action).assertEqual('pass');
    // 子帧里的自定义 scheme 也必须放行：误杀会让整页资源加载失败
    const d2 = decideDeepLink('zhihu://inframe', false, false, NOW, 0);
    expect(d2.action).assertEqual('pass');
  });

  it('decideDeepLink_unknownSchemeSilentBlock', 0, () => {
    const d = decideDeepLink('unknownapp://page', true, true, NOW, 0);
    expect(d.action).assertEqual('block');
    expect(d.notify).assertFalse();
  });

  it('decideDeepLink_noGestureBlockedWithToast', 0, () => {
    // 页面自动 location.href=zhihu://（无触摸伴随）：拦截 + 提示
    const d = decideDeepLink('zhihu://question/1', true, false, NOW, 0);
    expect(d.action).assertEqual('block');
    expect(d.notify).assertTrue();
  });

  it('decideDeepLink_gestureOpensApp', 0, () => {
    // 用户点击「打开App」按钮（1 秒内有触摸）：唤起
    const d = decideDeepLink('zhihu://question/1', true, true, NOW, NOW - 7000);
    expect(d.action).assertEqual('openApp');
    expect(d.cooled).assertTrue();
    // 冷却中：仍然 openApp 判定，但 cooled=false 调用方应丢弃
    const d2 = decideDeepLink('bilibili://video/1', true, true, NOW, NOW - 1000);
    expect(d2.action).assertEqual('openApp');
    expect(d2.cooled).assertFalse();
  });

  it('classifyLoadError_mainFrameSignalFirst', 0, () => {
    // 主帧信号是决定性的，不再看 hostOf 是否同域
    expect(classifyLoadError('https://a.com/x', 'https://b.com/y', true)).assertTrue();
    expect(classifyLoadError('https://a.com/x', 'https://a.com/y', false)).assertFalse();
    // B站视频页预载 bilivideo 流失败：非主帧，绝不能误弹错误卡
    expect(classifyLoadError('https://upos.bilivideo.com/v.mp4', 'https://www.bilibili.com/', false)).assertFalse();
    // 非 Web scheme 的错误：资源级
    expect(classifyLoadError('bilibili://x', '', true)).assertFalse();
    expect(classifyLoadError('', '', true)).assertFalse();
  });

  it('classifyLoadError_fallbackHostCompare', 0, () => {
    // isMainFrame 信号不可用（null）：降级回退 hostOf 同域对比
    expect(classifyLoadError('https://a.com/x', 'https://a.com/y', null)).assertTrue();
    expect(classifyLoadError('https://cdn.com/v.mp4', 'https://page.com/', null)).assertFalse();
    expect(classifyLoadError('https://a.com/x', '', null)).assertFalse();
  });

  it('downloadNav_ignoreWindow', 0, () => {
    // 选择器存活期：无条件忽略
    expect(shouldIgnoreDownloadNavError(true, 0, NOW)).assertTrue();
    // start 后 5 秒：窗口内忽略
    expect(shouldIgnoreDownloadNavError(false, NOW - 5000, NOW)).assertTrue();
    // start 后 20 秒：窗口已过，正常判定
    expect(shouldIgnoreDownloadNavError(false, NOW - 20000, NOW)).assertFalse();
    // 从未发生过下载导航
    expect(shouldIgnoreDownloadNavError(false, 0, NOW)).assertFalse();
  });

  it('fullscreen_gestureGate', 0, () => {
    expect(shouldAllowFullscreen(NOW - 500, NOW)).assertTrue();
    expect(shouldAllowFullscreen(NOW - 2000, NOW)).assertFalse();
    expect(shouldAllowFullscreen(0, NOW)).assertFalse();
  });

  it('httpError_mainDocDeterministic', 0, () => {
    expect(isMainDocHttpError(404, true)).assertTrue();
    expect(isMainDocHttpError(503, true)).assertTrue();
    expect(isMainDocHttpError(200, true)).assertFalse();
    expect(isMainDocHttpError(404, false)).assertFalse();
    expect(isMainDocHttpError(399, true)).assertFalse();
  });
});
