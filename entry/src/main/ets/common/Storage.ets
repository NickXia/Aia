import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Bookmark, HistoryEntry, RecordJson, DialItem, DownloadItem } from '../model/Models';

const KEY_DIALS: string = 'dials';

const DEFAULT_DIALS: DialItem[] = [
  { name: '百度', url: 'https://www.baidu.com', color: '#3F7BFF' },
  { name: '知乎', url: 'https://www.zhihu.com', color: '#1B7CF2' },
  { name: 'B站', url: 'https://m.bilibili.com', color: '#FB7299' },
  { name: '微博', url: 'https://m.weibo.cn', color: '#E6412E' },
  { name: '淘宝', url: 'https://www.taobao.com', color: '#FF6A00' },
  { name: '抖音', url: 'https://www.douyin.com', color: '#1C1C24' },
  { name: '七猫小说', url: 'https://www.qimao.com', color: '#E85445' },
  { name: '少数派', url: 'https://sspai.com', color: '#D5413F' }
];

/** 第一版默认集：检测到它即视为未自定义，迁移到新默认集 */
const LEGACY_DEFAULT_MARK: string = 'https://www.douban.com';

const STORE_NAME: string = 'aia_store';
const KEY_BOOKMARKS: string = 'bookmarks';
const KEY_HISTORY: string = 'history';
const KEY_ENGINE: string = 'engine_index';
const KEY_HOMEPAGE: string = 'homepage';
const KEY_BLOCK_IMAGES: string = 'block_images';
const KEY_SAVE_HISTORY: string = 'save_history';
const KEY_JAVASCRIPT: string = 'javascript';
const KEY_DNT: string = 'do_not_track';
const KEY_BG_IMAGE: string = 'bg_image';
const KEY_ELDER: string = 'elder_mode';
const KEY_READING: string = 'reading_theme';
const KEY_DOWNLOADS: string = 'downloads';
const KEY_DESKTOP_UA: string = 'desktop_ua';

/**
 * 轻量本地存储。全部走 Preferences，读写都是同步的（数据量很小）。
 */
export class AiaStore {
  private static pref: preferences.Preferences | null = null;

  static init(context: common.Context): void {
    try {
      const options: preferences.Options = { name: STORE_NAME };
      AiaStore.pref = preferences.getPreferencesSync(context, options);
    } catch (err) {
      AiaStore.pref = null;
    }
  }

  private static getString(key: string, def: string): string {
    if (AiaStore.pref === null) {
      return def;
    }
    try {
      const v: preferences.ValueType = AiaStore.pref.getSync(key, def);
      return typeof v === 'string' ? v as string : def;
    } catch (err) {
      return def;
    }
  }

  private static getBool(key: string, def: boolean): boolean {
    if (AiaStore.pref === null) {
      return def;
    }
    try {
      const v: preferences.ValueType = AiaStore.pref.getSync(key, def);
      return typeof v === 'boolean' ? v as boolean : def;
    } catch (err) {
      return def;
    }
  }

  private static getNumber(key: string, def: number): number {
    if (AiaStore.pref === null) {
      return def;
    }
    try {
      const v: preferences.ValueType = AiaStore.pref.getSync(key, def);
      return typeof v === 'number' ? v as number : def;
    } catch (err) {
      return def;
    }
  }

  private static put(key: string, value: preferences.ValueType): void {
    if (AiaStore.pref === null) {
      return;
    }
    try {
      AiaStore.pref.putSync(key, value);
      AiaStore.pref.flush();
    } catch (err) {
      // 存储失败不影响主流程
    }
  }

  // ------------------------------------------------------------ 书签 / 历史
  static loadBookmarks(): Bookmark[] {
    return AiaStore.decode(AiaStore.getString(KEY_BOOKMARKS, '[]'));
  }

  static saveBookmarks(list: Bookmark[]): void {
    AiaStore.put(KEY_BOOKMARKS, AiaStore.encode(list));
  }

  static loadHistory(): HistoryEntry[] {
    return AiaStore.decode(AiaStore.getString(KEY_HISTORY, '[]'));
  }

  static saveHistoryList(list: HistoryEntry[]): void {
    AiaStore.put(KEY_HISTORY, AiaStore.encode(list));
  }

  private static encode(list: HistoryEntry[] | Bookmark[]): string {
    const raw: RecordJson[] = [];
    for (let i = 0; i < list.length; i++) {
      const item: RecordJson = {
        id: list[i].id,
        title: list[i].title,
        url: list[i].url,
        time: list[i].time
      };
      raw.push(item);
    }
    return JSON.stringify(raw);
  }

  private static decode(text: string): HistoryEntry[] {
    const result: HistoryEntry[] = [];
    try {
      const arr: RecordJson[] = JSON.parse(text) as RecordJson[];
      for (let i = 0; i < arr.length; i++) {
        const r: RecordJson = arr[i];
        result.push(new HistoryEntry(r.id, r.title, r.url, r.time));
      }
    } catch (err) {
      return [];
    }
    return result;
  }

  // ------------------------------------------------------------------ 设置
  static get engineIndex(): number {
    return AiaStore.getNumber(KEY_ENGINE, 0);
  }

  static set engineIndex(v: number) {
    AiaStore.put(KEY_ENGINE, v);
  }

  static get homepage(): string {
    return AiaStore.getString(KEY_HOMEPAGE, 'https://www.baidu.com');
  }

  static set homepage(v: string) {
    AiaStore.put(KEY_HOMEPAGE, v);
  }

  static get blockImages(): boolean {
    return AiaStore.getBool(KEY_BLOCK_IMAGES, false);
  }

  static set blockImages(v: boolean) {
    AiaStore.put(KEY_BLOCK_IMAGES, v);
  }

  static get saveHistory(): boolean {
    return AiaStore.getBool(KEY_SAVE_HISTORY, true);
  }

  static set saveHistory(v: boolean) {
    AiaStore.put(KEY_SAVE_HISTORY, v);
  }

  static get javaScriptEnabled(): boolean {
    return AiaStore.getBool(KEY_JAVASCRIPT, true);
  }

  static set javaScriptEnabled(v: boolean) {
    AiaStore.put(KEY_JAVASCRIPT, v);
  }

  static get doNotTrack(): boolean {
    return AiaStore.getBool(KEY_DNT, true);
  }

  static set doNotTrack(v: boolean) {
    AiaStore.put(KEY_DNT, v);
  }

  /** 自定义主页背景：沙箱内的图片绝对路径，空串表示使用默认宣纸底 */
  static get bgImage(): string {
    return AiaStore.getString(KEY_BG_IMAGE, '');
  }

  static set bgImage(v: string) {
    AiaStore.put(KEY_BG_IMAGE, v);
  }

  /** 关怀模式（老年人模式）：更大的字体与触控目标 */
  static get elderMode(): boolean {
    return AiaStore.getBool(KEY_ELDER, false);
  }

  static set elderMode(v: boolean) {
    AiaStore.put(KEY_ELDER, v);
  }

  /** 主页快捷方式（可编辑） */
  static loadDials(): DialItem[] {
    const raw: string = AiaStore.getString(KEY_DIALS, JSON.stringify(DEFAULT_DIALS));
    try {
      const arr: object[] = JSON.parse(raw) as object[];
      const result: DialItem[] = [];
      let hasLegacyMark: boolean = false;
      for (let i = 0; i < arr.length; i++) {
        const o = arr[i] as Record<string, string>;
        if (typeof o['name'] === 'string' && typeof o['url'] === 'string') {
          if (o['url'] === LEGACY_DEFAULT_MARK) {
            hasLegacyMark = true; // 旧默认集（含豆瓣），整体迁移
          }
          const d: DialItem = { name: o['name'], url: o['url'], color: o['color'] ?? '#3E5C63' };
          result.push(d);
        }
      }
      if (result.length === 0) {
        return DEFAULT_DIALS;
      }
      if (hasLegacyMark) {
        // 用户未自定义过：静默迁移到新默认集（去豆瓣/GitHub，加抖音/七猫）
        AiaStore.saveDials(DEFAULT_DIALS);
        return DEFAULT_DIALS;
      }
      return result;
    } catch (err) {
      return DEFAULT_DIALS;
    }
  }

  static saveDials(list: DialItem[]): void {
    AiaStore.put(KEY_DIALS, JSON.stringify(list));
  }

  /** 阅读模式（羊皮卷主题） */
  static get readingTheme(): boolean {
    return AiaStore.getBool(KEY_READING, false);
  }

  static set readingTheme(v: boolean) {
    AiaStore.put(KEY_READING, v);
  }

  static clearHistory(): void {
    AiaStore.put(KEY_HISTORY, '[]');
  }

  // ------------------------------------------------------------ 下载记录
  static loadDownloads(): DownloadItem[] {
    const result: DownloadItem[] = [];
    try {
      const arr: object[] = JSON.parse(AiaStore.getString(KEY_DOWNLOADS, '[]')) as object[];
      for (let i = 0; i < arr.length; i++) {
        const o = arr[i] as Record<string, string | number>;
        const d: DownloadItem = new DownloadItem(
          o['guid'] as string, o['url'] as string,
          o['fileName'] as string, o['path'] as string);
        d.total = typeof o['total'] === 'number' ? o['total'] as number : 0;
        d.received = typeof o['received'] === 'number' ? o['received'] as number : 0;
        d.state = (o['state'] as string) === 'progressing' ? 'failed' : o['state'] as string;
        d.time = typeof o['time'] === 'number' ? o['time'] as number : 0;
        result.push(d);
      }
    } catch (err) {
      return [];
    }
    return result;
  }

  static saveDownloads(list: DownloadItem[]): void {
    const raw: Record<string, string | number>[] = [];
    for (let i = 0; i < list.length; i++) {
      const d = list[i];
      const o: Record<string, string | number> = {
        'guid': d.guid, 'url': d.url, 'fileName': d.fileName, 'path': d.path,
        'total': d.total, 'received': d.received, 'state': d.state, 'time': d.time
      };
      raw.push(o);
    }
    AiaStore.put(KEY_DOWNLOADS, JSON.stringify(raw));
  }

  static get desktopUA(): boolean {
    return AiaStore.getBool(KEY_DESKTOP_UA, false);
  }

  static set desktopUA(v: boolean) {
    AiaStore.put(KEY_DESKTOP_UA, v);
  }

  /** 保留最近 50 条下载记录 */
  static trimDownloads(list: DownloadItem[]): DownloadItem[] {
    return list.length > 50 ? list.slice(0, 50) : list;
  }
}
