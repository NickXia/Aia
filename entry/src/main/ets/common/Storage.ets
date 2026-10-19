import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Bookmark, HistoryEntry, RecordJson } from '../model/Models';

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

  static clearHistory(): void {
    AiaStore.put(KEY_HISTORY, '[]');
  }
}
