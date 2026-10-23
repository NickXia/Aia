import { describe, it, expect } from '@ohos/hypium';
import { sanitizeFileName, resolveInput, hostOf, looksLikeUrl } from '../main/ets/common/UrlUtils';
import { SearchEngine } from '../main/ets/common/SearchEngine';

/** UrlUtils 纯函数单测：文件名清洗（审查 #11）与地址栏输入解析 */
export default describe('urlUtilsTest', () => {
  it('sanitizeFileName_whitelist', 0, () => {
    expect(sanitizeFileName('setup.exe')).assertEqual('setup.exe');
    expect(sanitizeFileName('正常名称.zip')).assertEqual('正常名称.zip');
    expect(sanitizeFileName('report 2026.pdf')).assertEqual('report_2026.pdf');
    // 路径穿越被清洗
    expect(sanitizeFileName('../../evil')).assertEqual('.._.._evil');
    expect(sanitizeFileName('a/b?c*.apk')).assertEqual('a_b_c_.apk');
  });

  it('sanitizeFileName_dotTraversal', 0, () => {
    // '.'、'..'、空串是危险/无效文件名，清洗为空串（调用方兜底命名）
    expect(sanitizeFileName('.')).assertEqual('');
    expect(sanitizeFileName('..')).assertEqual('');
    expect(sanitizeFileName('')).assertEqual('');
    expect(sanitizeFileName('???')).assertEqual('___');
  });

  it('resolveInput_urlVsSearch', 0, () => {
    const baidu: SearchEngine = new SearchEngine('百度', 'https://www.baidu.com/s?wd=%s');
    expect(resolveInput('baidu.com', baidu)).assertEqual('https://baidu.com');
    expect(resolveInput('192.168.1.1:8080', baidu)).assertEqual('http://192.168.1.1:8080');
    expect(resolveInput('zhihu://question/1', baidu)).assertEqual('zhihu://question/1');
    expect(resolveInput('鸿蒙浏览器', baidu)).assertEqual('https://www.baidu.com/s?wd=' + encodeURIComponent('鸿蒙浏览器'));
    expect(resolveInput('', baidu)).assertEqual('');
  });

  it('looksLikeUrl_cases', 0, () => {
    expect(looksLikeUrl('www.baidu.com')).assertTrue();
    expect(looksLikeUrl('10.0.0.1')).assertTrue();
    expect(looksLikeUrl('搜一下天气')).assertFalse();
    expect(looksLikeUrl('has space.com')).assertFalse();
  });

  it('hostOf_basic', 0, () => {
    expect(hostOf('https://www.zhihu.com/question/1')).assertEqual('www.zhihu.com');
    expect(hostOf('http://10.0.0.1:8080/x')).assertEqual('10.0.0.1');
  });
});
