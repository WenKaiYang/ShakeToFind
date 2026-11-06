# -*- coding: utf-8 -*-
"""ShakeToFind 品牌图标生成器。

设计：放大镜 + 放大的鼠标指针
    - 冰白镜片：高对比，缩到 16px 仍能看清指针；像玻璃一样微透。
    - 青→靛渐变镜圈：呼应“快速移动 / 速度”的冷色科技感。
    - 深色指针：Windows 默认箭头造型，一眼认出是“鼠标指针”。
    - 琥珀手柄端：暖色点睛，让图标在深色任务栏上也有识别度。
    放大镜 = “找鼠标”，镜片里的大指针 = “会变大的指针”，正好是这个工具的功能。

用法（在仓库根目录）：
    python assets\\icon\\build_icon.py

输出：
    assets/icon/ShakeToFind.ico   多尺寸图标（16~256），安装包 / 快捷方式 / 托盘共用
    assets/icon/preview.png       设计预览图（浅色 / 深色 / 尺寸适配）

修改颜色或形状后重新运行即可；不要手改 .ico 或 preview.png。
"""
from __future__ import annotations

import io
import math
import os
import struct

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
DESIGN = 1024.0  # 设计稿坐标系边长

# ---------- 调色板 ----------
CURSOR = "#0F172A"        # 指针本体（深蓝黑）
RIM_STOPS = ["#A5F3FC", "#22D3EE", "#3B82F6", "#4F46E5"]  # 镜圈渐变：冰青 → 靛蓝
LENS_STOPS = ["#FFFFFF", "#E9F1FF", "#CDDEFF"]           # 冰白镜片渐变
AMBER = "#F59E0B"         # 手柄端暖色

ICO_SIZES = (16, 20, 24, 32, 40, 48, 64, 96, 128, 256)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgba(h, a=255):
    return rgb(h) + (a,)


def linear_gradient(size, hex_stops, p0, p1):
    """沿 p0→p1 的线性渐变（返回 RGBA 图）。"""
    stops = [(t, rgb(h)) for t, h in hex_stops]
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    vx, vy = p1[0] - p0[0], p1[1] - p0[1]
    t = np.clip(((xx - p0[0]) * vx + (yy - p0[1]) * vy) / (vx * vx + vy * vy), 0.0, 1.0)
    ts = np.array([s[0] for s in stops], np.float32)
    cs = np.array([s[1] for s in stops], np.float32)
    out = np.zeros((size, size, 4), np.float32)
    for c in range(3):
        out[..., c] = np.interp(t, ts, cs[:, c])
    out[..., 3] = 255
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def circle_mask(size, cx, cy, r):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return m


def ring_mask(size, cx, cy, r_out, width):
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([cx - r_out, cy - r_out, cx + r_out, cy + r_out], fill=255)
    ri = r_out - width
    d.ellipse([cx - ri, cy - ri, cx + ri, cy + ri], fill=0)
    return m


def capsule_mask(size, p0, p1, width):
    """两端圆头的胶囊遮罩。"""
    m = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(m)
    r = width / 2.0
    d.line([p0, p1], fill=255, width=int(round(width)))
    for p in (p0, p1):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=255)
    return m


def blank(size):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def paint(im, mask, color):
    im.alpha_composite(Image.composite(Image.new("RGBA", im.size, color), blank(im.width), mask))


# Windows 鼠标指针轮廓（归一化坐标；x 上限 0.62，y 上限 1.0）
ARROW = [(0.010, 0.00), (0.010, 0.86), (0.220, 0.66), (0.360, 1.00),
         (0.540, 0.93), (0.400, 0.60), (0.620, 0.54)]


def arrow_points(tip, h):
    return [(tip[0] + x * h, tip[1] + y * h) for x, y in ARROW]


def draw_arrow(im, tip, h, fill, edge=None, edge_px=0.0):
    d = ImageDraw.Draw(im, "RGBA")
    pts = arrow_points(tip, h)
    if edge is not None:
        d.line(pts + [pts[0]], fill=edge, width=int(round(edge_px * 2)), joint="curve")
    d.polygon(pts, fill=fill)


# ---------- 几何配置 ----------
# full 用于 32px 及以上；small 用于 24px 及以下（镜圈更粗、细节更少，缩小后才看得清）。
GEOM = {
    "full": dict(r_out=336.0, ring_w=88.0, hlen=252.0, hwid=122.0, edge_px=8.0,
                 cap_from=0.84, cap_w=0.92, fit_margin=6.0, pad=0.05),
    "small": dict(r_out=352.0, ring_w=106.0, hlen=250.0, hwid=138.0, edge_px=7.0,
                  cap_from=0.86, cap_w=0.86, fit_margin=16.0, pad=0.045),
}


def render(level="full"):
    """渲染 1024 设计稿。level: full（32px 以上）/ small（24px 以下）。"""
    S = int(DESIGN)
    cx = cy = DESIGN / 2.0
    g = GEOM[level]
    small = level == "small"
    r_out, ring_w = g["r_out"], g["ring_w"]
    hlen, hwid = g["hlen"], g["hwid"]
    edge_px = g["edge_px"]
    r_in = r_out - ring_w

    diag = 1.0 / math.sqrt(2.0)
    hstart = (cx + (r_out - ring_w * 0.45) * diag, cy + (r_out - ring_w * 0.45) * diag)
    hend = (hstart[0] + hlen * diag, hstart[1] + hlen * diag)

    tip = (cx - 0.50 * r_in, cy - 0.60 * r_in)
    arrow_h = 400.0
    while arrow_h > 120 and max(
            math.hypot(px - cx, py - cy) for px, py in arrow_points(tip, arrow_h)) > r_in - g["fit_margin"]:
        arrow_h -= 4.0

    img = blank(S)

    # 镜片：冰白渐变
    img.alpha_composite(Image.composite(
        linear_gradient(S, [(0.0, LENS_STOPS[0]), (0.5, LENS_STOPS[1]), (1.0, LENS_STOPS[2])],
                        (cx - r_in, cy - r_in), (cx + r_in, cy + r_in)),
        blank(S), circle_mask(S, cx, cy, r_in)))

    # 镜片内侧底部柔影，制造玻璃厚度
    if not small:
        shade = blank(S)
        sd = ImageDraw.Draw(shade)
        sd.arc([cx - (r_in - 8), cy - (r_in - 8), cx + (r_in - 8), cy + (r_in - 8)],
               start=25, end=155, fill=rgba("#0F172A", 35), width=14)
        img.alpha_composite(Image.composite(
            shade.filter(ImageFilter.GaussianBlur(14)), blank(S), circle_mask(S, cx, cy, r_in)))

    r_in_m = circle_mask(S, cx, cy, r_in)

    # 指针投影
    shadow = blank(S)
    draw_arrow(shadow, (tip[0] + 15, tip[1] + 19), arrow_h, (0, 0, 0, 70))
    img.alpha_composite(Image.composite(
        shadow.filter(ImageFilter.GaussianBlur(20)), blank(S), r_in_m))

    # 指针主体
    draw_arrow(img, tip, arrow_h, rgba(CURSOR), edge=(255, 255, 255, 220), edge_px=edge_px)

    # 镜圈 + 手柄（同一段青→靛渐变）
    ring_grad = linear_gradient(
        S, [(0.0, RIM_STOPS[0]), (0.28, RIM_STOPS[1]), (0.62, RIM_STOPS[2]), (1.0, RIM_STOPS[3])],
        (cx - r_out, cy - r_out), (cx + r_out, cy + r_out))
    rim = blank(S)
    rim.alpha_composite(Image.composite(ring_grad, blank(S), ring_mask(S, cx, cy, r_out, ring_w)))
    rim.alpha_composite(Image.composite(ring_grad, blank(S), capsule_mask(S, hstart, hend, hwid)))
    img.alpha_composite(rim)

    # 手柄端琥珀色短帽
    paint(img, capsule_mask(S,
                            (hstart[0] + hlen * g["cap_from"] * diag,
                             hstart[1] + hlen * g["cap_from"] * diag),
                            hend, hwid * g["cap_w"]), rgba(AMBER))

    # 镜圈左上高光弧
    if not small:
        hi = blank(S)
        hd = ImageDraw.Draw(hi)
        hd.arc([cx - r_out + 30, cy - r_out + 30, cx + r_out - 30, cy + r_out - 30],
               start=200, end=300, fill=rgba("#CFFAFE", 120), width=15)
        img.alpha_composite(hi.filter(ImageFilter.GaussianBlur(5)))

    # 裁掉多余空白并居中，四周留安全边距
    content = img.crop(img.getbbox())
    side = max(content.size)
    pad = int(round(side * g["pad"]))
    canvas = blank(side + pad * 2)
    canvas.alpha_composite(content, ((canvas.width - content.width) // 2,
                                     (canvas.height - content.height) // 2))
    return canvas


def frame(level, size):
    """按目标尺寸出图：24px 及以下用 small 级别，以上用 full 级别。"""
    master = render(level)
    return master.resize((size, size), Image.LANCZOS)


# ---------------- ICO 写入（小尺寸用 BMP 帧，128/256 用 PNG 帧，兼容性最好） ----------------
def _dib_payload(im):
    w, h = im.size
    px = np.asarray(im.convert("RGBA"), dtype=np.uint8)[::-1]  # 自下而上
    bgra = px[:, :, [2, 1, 0, 3]].tobytes()
    row_bytes = ((w + 31) // 32) * 4
    mask = bytearray(row_bytes * h)
    alpha = px[:, :, 3]
    for y in range(h):
        base = y * row_bytes
        for x in range(w):
            if alpha[y, x] == 0:
                mask[base + (x >> 3)] |= 0x80 >> (x & 7)
    header = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, len(bgra) + len(mask), 0, 0, 0, 0)
    return header + bgra + bytes(mask)


def write_ico(path, images):
    """images: [(size, RGBA 图), ...]"""
    payloads = []
    for size, im in sorted(images):
        if size >= 128:
            buf = io.BytesIO()
            im.save(buf, "PNG")
            payloads.append((size, buf.getvalue()))
        else:
            payloads.append((size, _dib_payload(im)))

    offset = 6 + 16 * len(payloads)
    directory = b""
    for size, data in payloads:
        dim = 0 if size >= 256 else size
        directory += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(data), offset)
        offset += len(data)

    with open(path, "wb") as f:
        f.write(struct.pack("<HHH", 0, 1, len(payloads)))
        f.write(directory)
        for _, data in payloads:
            f.write(data)


# ---------------- 预览图 ----------------
def _font(size, bold=False):
    win = os.environ.get("WINDIR", r"C:\Windows")
    candidates = ["msyhbd.ttc", "msyh.ttc"] if bold else ["msyh.ttc", "msyhbd.ttc"]
    for name in candidates:
        p = os.path.join(win, "Fonts", name)
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size, index=0)
            except OSError:
                pass
    return ImageFont.load_default(size=size)


def build_preview(path):
    W, H = 1500, 1400
    BG = "#F1F5F9"
    INK = "#0F172A"
    MUTED = "#64748B"
    sheet = Image.new("RGBA", (W, H), rgba(BG))
    d = ImageDraw.Draw(sheet)
    f_title = _font(60, bold=True)
    f_sub = _font(24)
    f_h = _font(26, bold=True)
    f_body = _font(17)
    f_label = _font(18)
    f_hex = _font(17, bold=True)

    d.text((80, 62), "ShakeToFind", font=f_title, fill=rgba(INK))
    d.text((82, 134), "快速移动即放大的找鼠标工具 · 品牌图标", font=f_sub, fill=rgba(MUTED))

    icon256 = frame("full", 256)
    for x, bg, caption in (
            (80, "#FFFFFF", "浅色背景 · 资源管理器 / 安装向导"),
            (790, "#0F172A", "深色背景 · 深色任务栏 / 托盘")):
        d.rounded_rectangle([x, 200, x + 630, 610], radius=28, fill=rgba(bg),
                            outline=rgba("#E2E8F0") if bg == "#FFFFFF" else None, width=2)
        sheet.alpha_composite(icon256, (x + (630 - 256) // 2, 236))
        f_cap = _font(20)
        tw = d.textlength(caption, font=f_cap)
        d.text((x + (630 - tw) / 2, 540), caption, font=f_cap,
               fill=rgba(MUTED if bg == "#FFFFFF" else "#94A3B8"))

    # ---- 多尺寸适配 ----
    d.text((80, 660), "多尺寸适配", font=f_h, fill=rgba(INK))
    d.text((80, 698), "Windows 按场景自动挑选尺寸：托盘 16/20，开始菜单 32/48，大图标 256。",
           font=f_body, fill=rgba(MUTED))
    d.rounded_rectangle([80, 742, 1420, 1076], radius=22, fill=rgba("#FFFFFF"))

    x = 100
    gaps = {256: 26, 128: 26, 96: 24, 64: 22, 48: 20, 40: 20, 32: 20, 24: 18, 20: 16, 16: 0}
    for s in (256, 128, 96, 64, 48, 40, 32, 24, 20, 16):
        im = frame("small" if s <= 24 else "full", s)
        sheet.alpha_composite(im, (x, 770 + (256 - s) // 2))
        tw = d.textlength(str(s), font=f_body)
        d.text((x + s / 2 - tw / 2, 1034), str(s), font=f_body, fill=rgba(MUTED))
        x += s + gaps[s]

    # 右侧设计说明
    notes = [
        ("设计说明", True),
        ("冰白镜片配深色指针，", False),
        ("缩到 16px 仍一眼可辨；", False),
        ("青→靛渐变镜圈，呼应", False),
        ("“快速移动”的速度感；", False),
        ("琥珀手柄端在深色任务", False),
        ("栏上也留一个暖色记号。", False),
    ]
    ny = 790
    for text, bold in notes:
        d.text((1075, ny), text, font=_font(19 if bold else 18, bold=bold),
               fill=rgba(INK if bold else MUTED))
        ny += 38 if bold else 32

    # ---- 小尺寸像素检查 + 配色（深色条） ----
    d.rounded_rectangle([80, 1100, 1420, 1340], radius=22, fill=rgba("#0F172A"))
    d.text((104, 1116), "小尺寸像素检查（5×）", font=_font(18, bold=True), fill=rgba("#CBD5E1"))
    px = 104
    for s in (16, 20, 24, 32):
        big = frame("small" if s <= 24 else "full", s).resize((s * 5, s * 5), Image.NEAREST)
        sheet.alpha_composite(big, (px, 1152))
        d.text((px, 1302), f"{s}px", font=f_label, fill=rgba("#94A3B8"))
        px += s * 5 + 56

    d.text((820, 1116), "配色", font=_font(18, bold=True), fill=rgba("#CBD5E1"))
    x = 820
    for name, col in (("指针", CURSOR), ("冰青", RIM_STOPS[1]), ("靛蓝", RIM_STOPS[3]),
                      ("镜片", LENS_STOPS[1]), ("琥珀", AMBER)):
        d.rounded_rectangle([x, 1150, x + 26, 1176], radius=7, fill=rgba(col))
        d.text((x, 1184), name, font=f_label, fill=rgba("#CBD5E1"))
        d.text((x, 1212), col, font=f_hex, fill=rgba("#94A3B8"))
        x += 104

    d.text((80, 1362), "图标源文件：assets/icon/build_icon.py · 重新生成：python assets\\icon\\build_icon.py",
           font=_font(16), fill=rgba(MUTED))

    sheet.convert("RGB").save(path, quality=95)
    return path


def main():
    frames = {s: frame("small" if s <= 24 else "full", s) for s in ICO_SIZES}
    ico_path = os.path.join(HERE, "ShakeToFind.ico")
    write_ico(ico_path, list(frames.items()))
    preview_path = build_preview(os.path.join(HERE, "preview.png"))

    print(f"[OK] {ico_path}  ({os.path.getsize(ico_path)} bytes, {len(frames)} sizes: "
          f"{', '.join(str(s) for s in ICO_SIZES)})")
    print(f"[OK] {preview_path}")


if __name__ == "__main__":
    main()
