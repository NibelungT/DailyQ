#!/usr/bin/env python3
"""从 icon-source.jpg 生成全套应用图标（Android + Web + 品牌母版）。

不依赖 PIL：用 Chrome 的 canvas 做缩放与抗锯齿，截透明底图后用纯 Python 裁剪。
用法：python tool/gen_icon_q.py
"""
from __future__ import annotations

import json
import os
import struct
import subprocess
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "branding" / "icon-source.jpg"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
# 按需覆盖：CHROME_PATH=/path/to/chrome python tool/gen_icon_q.py
CHROME = os.environ.get("CHROME_PATH") or next(
    (
        c
        for c in (
            "C:/Program Files/Google/Chrome/Application/chrome.exe",
            "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/usr/bin/google-chrome",
        )
        if Path(c).exists()
    ),
    "chrome",
)
TMP = ROOT / "build" / "icon-tmp"

# (输出相对路径, 像素尺寸, 图形占画布高度比例, 是否烘焙圆角)
ICONS = [
    ("android/mipmap-mdpi/ic_launcher.png", 48, 0.56, True),
    ("android/mipmap-hdpi/ic_launcher.png", 72, 0.56, True),
    ("android/mipmap-xhdpi/ic_launcher.png", 96, 0.56, True),
    ("android/mipmap-xxhdpi/ic_launcher.png", 144, 0.56, True),
    ("android/mipmap-xxxhdpi/ic_launcher.png", 192, 0.56, True),
    ("android/mipmap-mdpi/ic_launcher_foreground.png", 108, 0.42, False),
    ("android/mipmap-hdpi/ic_launcher_foreground.png", 162, 0.42, False),
    ("android/mipmap-xhdpi/ic_launcher_foreground.png", 216, 0.42, False),
    ("android/mipmap-xxhdpi/ic_launcher_foreground.png", 324, 0.42, False),
    ("android/mipmap-xxxhdpi/ic_launcher_foreground.png", 432, 0.42, False),
    ("web/favicon.png", 64, 0.58, False),
    ("web/icons/Icon-192.png", 192, 0.56, True),
    ("web/icons/Icon-512.png", 512, 0.56, True),
    ("web/icons/Icon-maskable-192.png", 192, 0.40, False),
    ("web/icons/Icon-maskable-512.png", 512, 0.40, False),
    ("branding/icon-1024.png", 1024, 0.50, False),
    ("branding/icon-512-rounded.png", 512, 0.56, True),
]

GAP = 24


def layout() -> tuple[list[dict], int, int]:
    rows, cur, cur_w = [], [], 0
    max_w = 1700
    for item in ICONS:
        _, size, _, _ = item
        need = size if not cur else size + GAP
        if cur and cur_w + need > max_w:
            rows.append(cur)
            cur, cur_w = [], 0
            need = size
        cur.append(item)
        cur_w += need
    if cur:
        rows.append(cur)

    placed, y = [], 0
    width = 0
    for row in rows:
        x = 0
        row_h = max(i[1] for i in row)
        for name, size, ratio, rounded in row:
            placed.append(
                {"name": name, "size": size, "ratio": ratio, "rounded": rounded, "x": x, "y": y}
            )
            x += size + GAP
        width = max(width, x - GAP)
        y += row_h + GAP
    return placed, width, y - GAP


def build_html(placed: list[dict], width: int, height: int) -> str:
    items = "\n".join(
        f'<canvas id="c{i}" width="{p["size"]}" height="{p["size"]}" '
        f'style="left:{p["x"]}px;top:{p["y"]}px"></canvas>'
        for i, p in enumerate(placed)
    )
    meta = json.dumps(
        [{k: p[k] for k in ("x", "y", "size", "ratio", "rounded")} for p in placed]
    )
    return f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><style>
html,body{{margin:0;padding:0;background:transparent;width:{width}px;height:{height}px;overflow:hidden}}
canvas{{position:absolute;display:block}}
</style></head><body>
{items}
<script>
const META = {meta};
const img = new Image();
img.onload = () => {{
  // 找图形包围盒（排除接近白色的背景）
  const t = document.createElement('canvas');
  t.width = img.width; t.height = img.height;
  const tc = t.getContext('2d');
  tc.drawImage(img, 0, 0);
  const data = tc.getImageData(0, 0, img.width, img.height).data;
  let minX = img.width, minY = img.height, maxX = -1, maxY = -1;
  for (let y = 0; y < img.height; y += 2) {{
    for (let x = 0; x < img.width; x += 2) {{
      const o = (y * img.width + x) * 4;
      const lum = (data[o] * 299 + data[o+1] * 587 + data[o+2] * 114) / 1000;
      if (lum < 160) {{
        if (x < minX) minX = x; if (y < minY) minY = y;
        if (x > maxX) maxX = x; if (y > maxY) maxY = y;
      }}
    }}
  }}
  if (maxX < 0) {{ minX = 0; minY = 0; maxX = img.width - 1; maxY = img.height - 1; }}
  const pad = 4;
  minX = Math.max(0, minX - pad); minY = Math.max(0, minY - pad);
  maxX = Math.min(img.width - 1, maxX + pad); maxY = Math.min(img.height - 1, maxY + pad);
  const sw = maxX - minX + 1, sh = maxY - minY + 1;

  META.forEach((m, i) => {{
    const c = document.getElementById('c' + i);
    const g = c.getContext('2d');
    g.imageSmoothingEnabled = true;
    g.imageSmoothingQuality = 'high';
    if (m.rounded) {{
      const r = m.size * 0.22;
      g.beginPath();
      g.moveTo(r, 0); g.lineTo(m.size - r, 0); g.quadraticCurveTo(m.size, 0, m.size, r);
      g.lineTo(m.size, m.size - r); g.quadraticCurveTo(m.size, m.size, m.size - r, m.size);
      g.lineTo(r, m.size); g.quadraticCurveTo(0, m.size, 0, m.size - r);
      g.lineTo(0, r); g.quadraticCurveTo(0, 0, r, 0);
      g.closePath();
      g.fillStyle = '#FFFFFF'; g.fill();
      g.clip();
    }} else {{
      g.fillStyle = '#FFFFFF'; g.fillRect(0, 0, m.size, m.size);
    }}
    let dh = m.size * m.ratio;
    let dw = dh * sw / sh;
    if (dw > m.size * 0.92) {{ dw = m.size * 0.92; dh = dw * sh / sw; }}
    g.drawImage(img, minX, minY, sw, sh, (m.size - dw) / 2, (m.size - dh) / 2, dw, dh);
  }});
  document.title = 'READY ' + sw + 'x' + sh;
}};
img.src = 'icon-source.jpg';
</script></body></html>"""


def read_png(path: Path) -> tuple[int, int, int, bytes]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", "not a png"
    pos, idat, w, h, ct = 8, b"", 0, 0, 0
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos : pos + 4])
        typ = data[pos + 4 : pos + 8]
        chunk = data[pos + 8 : pos + 8 + length]
        pos += 12 + length
        if typ == b"IHDR":
            w, h, _, ct, _, _, _ = struct.unpack(">IIBBBBB", chunk)
        elif typ == b"IDAT":
            idat += chunk
        elif typ == b"IEND":
            break
    raw = zlib.decompress(idat)
    ch = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ct]
    stride = w * ch
    out = bytearray(h * stride)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        ft = raw[p]
        p += 1
        line = bytearray(raw[p : p + stride])
        p += stride
        if ft == 1:
            for i in range(ch, stride):
                line[i] = (line[i] + line[i - ch]) & 255
        elif ft == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ft == 3:
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ft == 4:
            for i in range(stride):
                a = line[i - ch] if i >= ch else 0
                b = prev[i]
                c = prev[i - ch] if i >= ch else 0
                pp = a + b - c
                pa, pb, pc = abs(pp - a), abs(pp - b), abs(pp - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        out[y * stride : (y + 1) * stride] = line
        prev = line
    return w, h, ch, bytes(out)


def write_png(path: Path, w: int, h: int, rgba: bytes) -> None:
    raw = bytearray()
    stride = w * 4
    for y in range(h):
        raw.append(0)
        raw += rgba[y * stride : (y + 1) * stride]

    def chunk(tag: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + tag
            + payload
            + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)
        )

    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main() -> int:
    if not SRC.exists():
        print(f"✗ 缺少源图 {SRC}")
        return 1
    placed, width, height = layout()
    TMP.mkdir(parents=True, exist_ok=True)
    html = TMP / "sheet.html"
    (TMP / "icon-source.jpg").write_bytes(SRC.read_bytes())
    html.write_text(build_html(placed, width, height), encoding="utf-8")

    shot = TMP / "sheet.png"
    cmd = [
        CHROME,
        "--headless=new",
        "--disable-gpu",
        "--no-sandbox",
        "--hide-scrollbars",
        "--force-device-scale-factor=1",
        "--default-background-color=00000000",
        "--allow-file-access-from-files",
        "--virtual-time-budget=6000",
        f"--window-size={width},{height}",
        f"--screenshot={shot}",
        html.as_uri(),
    ]
    subprocess.run(cmd, check=False, capture_output=True)
    if not shot.exists():
        print("✗ 截图失败，Chrome 没有产出")
        return 1

    sw, sh, ch, pixels = read_png(shot)
    print(f"画布 {sw}x{sh}，通道 {ch}")
    if ch != 4:
        print("! 截图不是 RGBA，圆角外的透明区域会被压成实色")

    for item in placed:
        size, x, y = item["size"], item["x"], item["y"]
        out = bytearray()
        for row in range(size):
            start = ((y + row) * sw + x) * ch
            seg = pixels[start : start + size * ch]
            if ch == 4:
                out += seg
            elif ch == 3:
                for i in range(0, len(seg), 3):
                    out += seg[i : i + 3] + b"\xff"
        target = (RES if item["name"].startswith("android/") else ROOT) / item["name"]
        if item["name"].startswith("android/"):
            target = RES / item["name"].split("/", 1)[1]
        elif item["name"].startswith("web/"):
            target = ROOT / "web" / item["name"].split("/", 1)[1]
        else:
            target = ROOT / "assets" / "branding" / Path(item["name"]).name
        write_png(target, size, size, bytes(out))
        print(f"  {target.relative_to(ROOT)}  {size}x{size}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
