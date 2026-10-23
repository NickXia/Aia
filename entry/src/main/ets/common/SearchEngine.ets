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


