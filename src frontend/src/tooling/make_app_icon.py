"""Recreate the full SRC logo as crisp SVG (outlined text) + high-res PNG."""

from __future__ import annotations

import math
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT_DIR = Path(r"d:\homework\CanSat\app\src frontend\src\assets\icons")
OUT_DIR.mkdir(parents=True, exist_ok=True)

NAVY = (3, 39, 99)
RED = (251, 23, 24)
BG_TOP = (248, 250, 254)
BG_BOTTOM = (188, 205, 235)
NAVY_HEX = "#032763"
RED_HEX = "#FB1718"

SIZE = 2048
ROCKWELL = Path(r"C:\Windows\Fonts\ROCKEB.TTF")
if not ROCKWELL.exists():
    ROCKWELL = Path(r"C:\Windows\Fonts\ROCKB.TTF")
ARIAL_BOLD = Path(r"C:\Windows\Fonts\arialbd.ttf")


def make_gradient_bg(size: int) -> Image.Image:
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        t = (y / (size - 1)) ** 0.85
        r = int(BG_TOP[0] + (BG_BOTTOM[0] - BG_TOP[0]) * t)
        g = int(BG_TOP[1] + (BG_BOTTOM[1] - BG_TOP[1]) * t)
        b = int(BG_TOP[2] + (BG_BOTTOM[2] - BG_TOP[2]) * t)
        for x in range(size):
            px[x, y] = (r, g, b)
    return img


def build_arc(
    cx: float,
    cy: float,
    rx_o: float,
    ry_o: float,
    rx_i: float,
    ry_i: float,
    start_deg: float = 205,
    end_deg: float = 335,
    steps: int = 180,
) -> list[tuple[float, float]]:
    """Tapered red arch — thick at crown, pointed tips."""
    start, end = math.radians(start_deg), math.radians(end_deg)
    outer: list[tuple[float, float]] = []
    inner: list[tuple[float, float]] = []
    for i in range(steps + 1):
        t = i / steps
        ang = start + (end - start) * t
        thick = math.sin(t * math.pi) ** 0.55
        rx_in = rx_o - (rx_o - rx_i) * thick
        ry_in = ry_o - (ry_o - ry_i) * thick
        bulge = 1.0 + 0.02 * thick
        outer.append((cx + rx_o * bulge * math.cos(ang), cy + ry_o * bulge * math.sin(ang)))
        inner.append((cx + rx_in * math.cos(ang), cy + ry_in * math.sin(ang)))
    return outer + list(reversed(inner))


def poly_to_svg_d(pts: list[tuple[float, float]]) -> str:
    parts = [f"M {pts[0][0]:.2f},{pts[0][1]:.2f}"]
    for x, y in pts[1:]:
        parts.append(f"L {x:.2f},{y:.2f}")
    parts.append("Z")
    return " ".join(parts)


def text_to_svg_path(
    text: str,
    font_path: Path,
    font_size_px: float,
    x_center: float,
    baseline_y: float,
) -> str:
    """Convert glyphs to a single SVG path, horizontally centered at x_center."""
    font = TTFont(str(font_path))
    glyph_set = font.getGlyphSet()
    cmap = font.getBestCmap()
    units_per_em = font["head"].unitsPerEm
    scale = font_size_px / units_per_em

    # Advance widths for centering
    advances = []
    glyphs = []
    for ch in text:
        name = cmap.get(ord(ch))
        if name is None:
            continue
        glyphs.append(name)
        advances.append(glyph_set[name].width)

    total_w = sum(advances) * scale
    pen_x = x_center - total_w / 2
    path_parts: list[str] = []

    for name, adv in zip(glyphs, advances):
        pen = SVGPathPen(glyph_set)
        glyph_set[name].draw(pen)
        raw = pen.getCommands()
        # Font coords: y-up. SVG: y-down. Scale + flip + translate.
        # Parse path commands and transform — use a simple matrix via string rewrite
        # Easier: apply transform attribute per glyph group.
        path_parts.append(
            f'<path transform="translate({pen_x:.2f} {baseline_y:.2f}) '
            f'scale({scale:.6f} {-scale:.6f})" d="{raw}" fill="{NAVY_HEX}"/>'
        )
        pen_x += adv * scale

    font.close()
    return "\n  ".join(path_parts)


def draw_logo_png() -> Path:
    size = SIZE
    img = make_gradient_bg(size)
    draw = ImageDraw.Draw(img)

    src_font = ImageFont.truetype(str(ROCKWELL), int(size * 0.26))
    sub_font = ImageFont.truetype(str(ARIAL_BOLD), int(size * 0.052))

    cx = size / 2
    src_y = size * 0.50
    sub_y = size * 0.72

    src_text = "SRC"
    bbox = draw.textbbox((0, 0), src_text, font=src_font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    src_x = (size - tw) / 2 - bbox[0]
    src_top = src_y - th / 2 - bbox[1]

    # Arc wraps SRC: tips near letter sides / mid-height, peak just above tops
    arc_cx = cx
    arc_cy = src_y + th * 0.28
    rx_o, ry_o = tw * 0.72, th * 1.15
    rx_i, ry_i = tw * 0.55, th * 0.82
    poly = build_arc(arc_cx, arc_cy, rx_o, ry_o, rx_i, ry_i, 208, 332)

    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(overlay).polygon(poly, fill=(*RED, 255))
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=0.5))
    composed = Image.alpha_composite(img.convert("RGBA"), overlay)
    draw2 = ImageDraw.Draw(composed)

    # Text on top so letters stay crisp over any arc overlap
    draw2.text((src_x, src_top), src_text, font=src_font, fill=NAVY)

    sub_text = "Space Research Center"
    sb = draw2.textbbox((0, 0), sub_text, font=sub_font)
    stw, sth = sb[2] - sb[0], sb[3] - sb[1]
    draw2.text(
        ((size - stw) / 2 - sb[0], sub_y - sth / 2 - sb[1]),
        sub_text,
        font=sub_font,
        fill=NAVY,
    )

    master = composed.convert("RGB")
    master_path = OUT_DIR / "src_logo_master.png"
    master.save(master_path, "PNG", optimize=True)
    print(f"saved {master_path}")

    icon = master.resize((1024, 1024), Image.Resampling.LANCZOS)
    icon_path = OUT_DIR / "app_icon.png"
    icon.save(icon_path, "PNG", optimize=True)
    print(f"saved {icon_path}")
    return icon_path


def write_svg() -> Path:
    size = 1024
    cx = size / 2
    src_y = size * 0.50
    sub_y = size * 0.72
    src_size = size * 0.26
    sub_size = size * 0.052

    # Approximate letter width for arc sizing (Rockwell Extra Bold "SRC")
    approx_tw = src_size * 2.05
    approx_th = src_size * 0.85
    arc_cy = src_y + approx_th * 0.28
    poly = build_arc(
        cx,
        arc_cy,
        approx_tw * 0.72,
        approx_th * 1.15,
        approx_tw * 0.55,
        approx_th * 0.82,
        208,
        332,
    )
    arc_d = poly_to_svg_d(poly)

    # Baseline ≈ vertical center of em box for display size
    src_baseline = src_y + src_size * 0.35
    sub_baseline = sub_y + sub_size * 0.35

    src_paths = text_to_svg_path("SRC", ROCKWELL, src_size, cx, src_baseline)
    sub_paths = text_to_svg_path(
        "Space Research Center", ARIAL_BOLD, sub_size, cx, sub_baseline
    )

    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#F8FAFE"/>
      <stop offset="100%" stop-color="#BCCDEB"/>
    </linearGradient>
  </defs>
  <rect width="{size}" height="{size}" fill="url(#bg)"/>
  <path d="{arc_d}" fill="{RED_HEX}"/>
  {src_paths}
  {sub_paths}
</svg>
'''
    path = OUT_DIR / "src_logo.svg"
    path.write_text(svg, encoding="utf-8")
    print(f"saved {path}")
    return path


def main() -> None:
    draw_logo_png()
    write_svg()


if __name__ == "__main__":
    main()
