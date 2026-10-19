# -*- coding: utf-8 -*-
"""生成 Aia 工程所需的矢量图标 (SVG) 与应用图标 (PNG)。
纯标准库实现，无需第三方依赖。
用法: python tools/gen_assets.py
"""
import os
import struct
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MEDIA = os.path.join(ROOT, 'entry', 'src', 'main', 'resources', 'base', 'media')
APP_MEDIA = os.path.join(ROOT, 'AppScope', 'resources', 'base', 'media')

INK = '#7C828C'


def svg(body, color=INK, fill='none', width='1.7'):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" '
        'fill="%s" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round">%s</svg>'
        % (fill, color, width, body)
    )


ICONS = {
    # 导航
    'ic_back': '<path d="M15 5 8 12l7 7"/>',
    'ic_forward': '<path d="M9 5l7 7-7 7"/>',
    'ic_home': '<path d="M3.5 10.4 12 3.4l8.5 7"/><path d="M6 9.4V20.4h12V9.4"/>',
    'ic_refresh': '<path d="M20.4 12a8.4 8.4 0 1 1-2.5-6"/><path d="M20.6 4.2v4.5h-4.5"/>',
    'ic_close': '<path d="M18.2 5.8 5.8 18.2M5.8 5.8l12.4 12.4"/>',
    'ic_close_sm': '<path d="M17.5 6.5 6.5 17.5M6.5 6.5l11 11"/>',
    'ic_plus': '<path d="M12 5.2v13.6M5.2 12h13.6"/>',
    'ic_more': '<path d="M5 12h.01M12 12h.01M19 12h.01" stroke-width="2.8"/>',
    'ic_chevron_right': '<path d="M9.5 5.5 16 12l-6.5 6.5"/>',
    'ic_chevron_down': '<path d="M5.5 9.5 12 16l6.5-6.5"/>',

    # 功能
    'ic_search': '<circle cx="11" cy="11" r="6.4"/><path d="M15.8 15.8 20.5 20.5"/>',
    'ic_shield': '<path d="M12 3.2 5 6v6c0 4.3 3 7.4 7 8.8 4-1.4 7-4.5 7-8.8V6z"/>',
    'ic_shield_off': '<path d="M12 3.2 5 6v6c0 4.3 3 7.4 7 8.8 4-1.4 7-4.5 7-8.8V6z"/>'
                     '<path d="M9.2 12.2 11.4 14.4l3.9-4.2" stroke="none" fill="none"/>',
    'ic_lock': '<rect x="5" y="10.4" width="14" height="10.2" rx="2.4"/>'
               '<path d="M8.4 10.4V8a3.6 3.6 0 0 1 7.2 0v2.4"/>',
    'ic_star': '<path d="M12 3.6l2.6 5.4 5.9.8-4.3 4.1 1.1 5.9-5.3-2.9-5.3 2.9 1.1-5.9L3.5 9.8l5.9-.8z"/>',
    'ic_bookmark': '<path d="M6.6 3.6h10.8a1 1 0 0 1 1 1V21L12 16.4 5.6 21V4.6a1 1 0 0 1 1-1z"/>',
    'ic_history': '<circle cx="12" cy="12" r="8.4"/><path d="M12 7.4V12l3.2 2"/>',
    'ic_download': '<path d="M12 4v10.4M8 10.6l4 4 4-4M4.6 19.4h14.8"/>',
    'ic_settings': '<path d="M4 7.2h3.4M11.6 7.2H20M4 12h8.4M16.6 12H20M4 16.8h5.4M13.6 16.8H20"/>'
                   '<circle cx="9.5" cy="7.2" r="2.1"/><circle cx="14.5" cy="12" r="2.1"/>'
                   '<circle cx="11.5" cy="16.8" r="2.1"/>',
    'ic_share': '<path d="M12 3.6v10.6"/><path d="M8.4 7.2 12 3.6l3.6 3.6"/>'
                '<path d="M6.2 11.6H5a1.3 1.3 0 0 0-1.3 1.3v7.4A1.3 1.3 0 0 0 5 21.6h14a1.3 1.3 0 0 0 1.3-1.3v-7.4a1.3 1.3 0 0 0-1.3-1.3h-1.2"/>',
    'ic_moon': '<path d="M20.4 13.4A8.6 8.6 0 1 1 10.6 3.6a6.9 6.9 0 0 0 9.8 9.8z"/>',
    'ic_incognito': '<path d="M3.4 3.6 20.6 20.4"/>'
                    '<path d="M10.4 6.2A9 9 0 0 1 12 6c4.5 0 8 3 9 6-.4 1.2-1.2 2.4-2.2 3.4"/>'
                    '<path d="M6.4 8.2C4.7 9.5 3.5 11 3 12c1 3 4.5 6 9 6 1.4 0 2.7-.3 3.9-.8"/>',
    'ic_globe': '<circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17"/>'
                '<path d="M12 3.5c2.4 2.4 3.6 5.4 3.6 8.5s-1.2 6.1-3.6 8.5c-2.4-2.4-3.6-5.4-3.6-8.5S9.6 5.9 12 3.5z"/>',
    'ic_trash': '<path d="M4.2 7h15.6M9.6 7V4.8h4.8V7M6.4 7l.9 13.2h9.4L17.6 7"/>',
    'ic_check': '<path d="M4.8 12.4 9.6 17.2 19.2 6.6"/>',
    'ic_grid': '<rect x="3.6" y="3.6" width="7" height="7" rx="2.1"/>'
               '<rect x="13.4" y="3.6" width="7" height="7" rx="2.1"/>'
               '<rect x="3.6" y="13.4" width="7" height="7" rx="2.1"/>'
               '<rect x="13.4" y="13.4" width="7" height="7" rx="2.1"/>',
    'ic_tabs': '<rect x="3.4" y="7.4" width="12.8" height="13.2" rx="2.6"/>'
               '<path d="M8.2 4.2h10.2a2.4 2.4 0 0 1 2.4 2.4v10.6"/>',
    'ic_phone': '<rect x="7" y="2.6" width="10" height="18.8" rx="2.6"/><path d="M10.6 18.4h2.8"/>',
    'ic_desktop': '<rect x="2.8" y="4.4" width="18.4" height="12.4" rx="2.2"/><path d="M9 20.4h6M12 16.8v3.6"/>',
    'ic_copy': '<rect x="8.6" y="8.6" width="11.2" height="11.2" rx="2.4"/>'
               '<path d="M15.4 5.6H7.2a2.4 2.4 0 0 0-2.4 2.4v8.2"/>',
    'ic_arrow_up': '<path d="M12 19V5.2M6.4 10.8 12 5.2l5.6 5.6"/>',
}

ACCENT_ICONS = {
    'ic_star_fill': ('<path d="M12 3.2l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17.2l-5.4 2.9 1-6.1L3.2 9.7l6.1-.9z"/>',
                     '#2B6EF2', '#2B6EF2'),
    'ic_aia_mark': ('<path fill-rule="evenodd" d="M12 4.2 17.9 19.8h-3.3l-1.1-3.2H9.4l-1.1 3.2H5.1L11 4.2h1zM12 7.8l1.95 5.7h-3.9L12 7.8z"/>',
                    '#33302A', '#33302A'),
    'ic_shield_fill': ('<path d="M12 2.6 4.6 5.6v6.2c0 4.6 3.2 7.9 7.4 9.4 4.2-1.5 7.4-4.8 7.4-9.4V5.6z"/>',
                       '#2B6EF2', '#2B6EF2'),
    'ic_globe_fill': ('<circle cx="12" cy="12" r="9"/>', '#2B6EF2', '#2B6EF2'),
}


FILLED_SVGS = {
    'ic_hills': (320, 90, '<path d="M0 66 Q36 30 76 54 T150 48 T228 60 T320 42 V90 H0 Z" fill="#3E5C63" fill-opacity="0.16"/>'
                          '<path d="M0 80 Q56 48 116 68 T232 72 T320 60 V90 H0 Z" fill="#33302A" fill-opacity="0.12"/>'),
}


def write_icons():
    for name, body in ICONS.items():
        with open(os.path.join(MEDIA, name + '.svg'), 'w', encoding='utf-8') as f:
            f.write(svg(body))
    for name, (body, color, fill) in ACCENT_ICONS.items():
        with open(os.path.join(MEDIA, name + '.svg'), 'w', encoding='utf-8') as f:
            f.write(svg(body, color=color, fill=fill, width='1.6'))
    for name, (w, h, body) in FILLED_SVGS.items():
        doc = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">%s</svg>'
               % (w, h, w, h, body))
        with open(os.path.join(MEDIA, name + '.svg'), 'w', encoding='utf-8') as f:
            f.write(doc)


# ---------------------------------------------------------------- app icon png
SIZE = 512
SS = 2  # 超采样倍数


def build_icon(path):
    n = SIZE * SS
    radius = 118 * SS
    pad = 0
    c1 = (249, 246, 238)
    c2 = (233, 226, 209)
    ink = (51, 48, 42)
    seal = (168, 63, 46)

    # A 字形几何（相对 512 画布，偶奇填充：外轮廓 + 三角镂空）
    outer = [(256.0, 152.0), (354.0, 360.0), (302.0, 360.0), (289.0, 318.0),
             (223.0, 318.0), (210.0, 360.0), (158.0, 360.0)]
    counter = [(256.0, 192.0), (292.0, 274.0), (222.0, 274.0)]

    def inside_poly(px, py, pts):
        inside = False
        j = len(pts) - 1
        for i in range(len(pts)):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > py) != (yj > py):
                xint = xi + (py - yi) * (xj - xi) / (yj - yi)
                if xint > px:
                    inside = not inside
            j = i
        return inside

    buf = bytearray(n * n * 4)
    for y in range(n):
        fy = y / SS
        for x in range(n):
            fx = x / SS
            # 圆角矩形遮罩
            dx = max(radius / SS * 0 - 0, 0)
            cx_ = min(max(fx, 118.0), SIZE - 118.0)
            cy_ = min(max(fy, 118.0), SIZE - 118.0)
            if (fx - cx_) ** 2 + (fy - cy_) ** 2 > 118.0 ** 2:
                continue
            t = (fx + fy) / (SIZE * 2.0)
            r = int(c1[0] + (c2[0] - c1[0]) * t)
            g = int(c1[1] + (c2[1] - c1[1]) * t)
            b = int(c1[2] + (c2[2] - c1[2]) * t)

            inside = inside_poly(fx, fy, outer) != inside_poly(fx, fy, counter)
            # 朱砂小印（圆角小方块，位于 A 右下）
            sx0, sy0, sx1, sy1 = 352.0, 308.0, 396.0, 352.0
            in_seal_box = sx0 <= fx <= sx1 and sy0 <= fy <= sy1
            if in_seal_box:
                dx = min(fx - sx0, sx1 - fx)
                dy = min(fy - sy0, sy1 - fy)
                in_seal_box = dx >= 0 and dy >= 0 and (min(dx, dy) > 8 or dx * dx + dy * dy <= 64.0)
            if inside:
                r, g, b = ink
            elif in_seal_box:
                r, g, b = seal
            i = (y * n + x) * 4
            buf[i] = r
            buf[i + 1] = g
            buf[i + 2] = b
            buf[i + 3] = 255

    # 降采样
    rows = []
    for y in range(SIZE):
        row = bytearray()
        for x in range(SIZE):
            rs = gs = bs = as_ = 0
            for dy in range(SS):
                for dx in range(SS):
                    i = ((y * SS + dy) * n + (x * SS + dx)) * 4
                    a = buf[i + 3]
                    rs += buf[i] * a
                    gs += buf[i + 1] * a
                    bs += buf[i + 2] * a
                    as_ += a
            if as_ == 0:
                row += b'\x00\x00\x00\x00'
            else:
                row += bytes([rs // as_, gs // as_, bs // as_, as_ // (SS * SS)])
        rows.append(bytes(row))

    raw = b''.join(b'\x00' + r for r in rows)
    comp = zlib.compress(raw, 9)

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    ihdr = struct.pack('>IIBBBBB', SIZE, SIZE, 8, 6, 0, 0, 0)
    png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', ihdr)
           + chunk(b'IDAT', comp) + chunk(b'IEND', b''))
    for target in (path, os.path.join(MEDIA, 'app_icon.png')):
        with open(target, 'wb') as f:
            f.write(png)
    print('icon ->', path, len(png), 'bytes')


if __name__ == '__main__':
    os.makedirs(MEDIA, exist_ok=True)
    os.makedirs(APP_MEDIA, exist_ok=True)
    write_icons()
    build_icon(os.path.join(APP_MEDIA, 'app_icon.png'))
    print('svg icons:', len(ICONS) + len(ACCENT_ICONS))
