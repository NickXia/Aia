/**
 * 搜索引擎定义
 */
export class SearchEngine {
  name: string;
  /** %s 会被替换为编码后的关键词 */
  template: string;

  constructor(name: string, template: string) {
    this.name = name;
    this.template = template;
  }
}

export const ENGINES: SearchEngine[] = [
  new SearchEngine('百度', 'https://www.baidu.com/s?wd=%s'),
  new SearchEngine('必应', 'https://www.bing.com/search?q=%s'),
  new SearchEngine('Google', 'https://www.google.com/search?q=%s'),
  new SearchEngine('搜狗', 'https://www.sogou.com/web?query=%s'),
  new SearchEngine('DuckDuckGo', 'https://duckduckgo.com/?q=%s')
];

export const HOME_PRESETS: string[] = [
  'https://www.baidu.com',
  'https://www.bing.com',
  'https://www.zhihu.com',
  'https://www.bilibili.com'
];

/** 主页快捷入口（可在设置里替换） */
export class SpeedDial {
  name: string;
  url: string;
  color: string;

  constructor(name: string, url: string, color: string) {
    this.name = name;
    this.url = url;
    this.color = color;
  }
}

export const SPEED_DIALS: SpeedDial[] = [
  new SpeedDial('百度', 'https://www.baidu.com', '#3F7BFF'),
  new SpeedDial('知乎', 'https://www.zhihu.com', '#1B7CF2'),
  new SpeedDial('B站', 'https://m.bilibili.com', '#FB7299'),
  new SpeedDial('微博', 'https://m.weibo.cn', '#E6412E'),
  new SpeedDial('淘宝', 'https://www.taobao.com', '#FF6A00'),
  new SpeedDial('豆瓣', 'https://www.douban.com', '#2FA84F'),
  new SpeedDial('Google', 'https://www.google.com', '#4285F4'),
  new SpeedDial('GitHub', 'https://github.com', '#24292F')
];
