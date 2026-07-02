#!/usr/bin/env python3
"""Render Play Store icon (512x512) and feature graphic (1024x500) PNGs.

Zero third-party deps: pure stdlib zlib + hand-rolled PNG chunks.
Anti-aliasing via 2x2 supersampling of the shape masks so the rounded
notebook corners don't stair-step.

Run:
    python3 screenshots/_render_assets.py
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

# Colors (RGB)
TEAL = (0x00, 0x89, 0x7B)
WHITE = (0xFF, 0xFF, 0xFF)

HERE = Path(__file__).resolve().parent


# ----- PNG encoder ---------------------------------------------------------

def _png_chunk(kind: bytes, data: bytes) -> bytes:
    crc = zlib.crc32(kind + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", crc)


def save_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    """pixels is a flat RGB bytearray of length width*height*3."""
    signature = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    # Add filter byte 0 at the start of each scanline
    stride = width * 3
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride : (y + 1) * stride])
    idat = zlib.compress(bytes(raw), 9)
    path.write_bytes(
        signature
        + _png_chunk(b"IHDR", ihdr)
        + _png_chunk(b"IDAT", idat)
        + _png_chunk(b"IEND", b"")
    )


# ----- Canvas + shape helpers ---------------------------------------------

class Canvas:
    def __init__(self, w: int, h: int, bg: tuple[int, int, int]) -> None:
        self.w = w
        self.h = h
        buf = bytearray(w * h * 3)
        for i in range(w * h):
            buf[i * 3 : i * 3 + 3] = bytes(bg)
        self.buf = buf

    def _set(self, x: int, y: int, color: tuple[int, int, int]) -> None:
        i = (y * self.w + x) * 3
        self.buf[i : i + 3] = bytes(color)

    def _blend(
        self, x: int, y: int, color: tuple[int, int, int], alpha: float
    ) -> None:
        if alpha <= 0:
            return
        if alpha >= 1:
            self._set(x, y, color)
            return
        i = (y * self.w + x) * 3
        r, g, b = self.buf[i], self.buf[i + 1], self.buf[i + 2]
        nr = round(color[0] * alpha + r * (1 - alpha))
        ng = round(color[1] * alpha + g * (1 - alpha))
        nb = round(color[2] * alpha + b * (1 - alpha))
        self.buf[i : i + 3] = bytes((nr, ng, nb))

    def rect(
        self,
        x: int,
        y: int,
        w: int,
        h: int,
        color: tuple[int, int, int],
    ) -> None:
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.w, x + w), min(self.h, y + h)
        for py in range(y0, y1):
            base = (py * self.w + x0) * 3
            for px in range(x0, x1):
                i = base + (px - x0) * 3
                self.buf[i : i + 3] = bytes(color)

    def rounded_rect(
        self,
        x: float,
        y: float,
        w: float,
        h: float,
        r: float,
        color: tuple[int, int, int],
    ) -> None:
        """Anti-aliased rounded rect via 2x2 supersampling of the corner arcs."""
        x0 = int(x)
        y0 = int(y)
        x1 = int(x + w)
        y1 = int(y + h)
        cx0, cx1 = x + r, x + w - r
        cy0, cy1 = y + r, y + h - r
        for py in range(max(0, y0), min(self.h, y1 + 1)):
            for px in range(max(0, x0), min(self.w, x1 + 1)):
                # For pixels safely in the straight interior, take full alpha.
                if (cx0 <= px + 0.5 <= cx1) or (cy0 <= py + 0.5 <= cy1):
                    if x <= px + 0.5 <= x + w and y <= py + 0.5 <= y + h:
                        self._set(px, py, color)
                    continue
                # Otherwise we are near a corner: supersample 2x2 in the pixel.
                hits = 0
                for sy in (0.25, 0.75):
                    for sx in (0.25, 0.75):
                        fx, fy = px + sx, py + sy
                        # Which corner center are we nearest?
                        ccx = cx0 if fx < cx0 else cx1
                        ccy = cy0 if fy < cy0 else cy1
                        dx = fx - ccx
                        dy = fy - ccy
                        if dx * dx + dy * dy <= r * r:
                            hits += 1
                if hits:
                    self._blend(px, py, color, hits / 4)


# ----- Compositions --------------------------------------------------------

def render_icon() -> None:
    c = Canvas(512, 512, TEAL)
    # Notebook cover
    c.rounded_rect(120, 80, 272, 352, 24, WHITE)
    # Spine
    c.rect(152, 112, 14, 288, TEAL)
    # Page lines
    c.rect(188, 152, 176, 18, TEAL)
    c.rect(188, 212, 176, 18, TEAL)
    c.rect(188, 272, 176, 18, TEAL)
    c.rect(188, 332, 136, 18, TEAL)
    save_png(HERE / "store_icon.png", 512, 512, c.buf)


def render_feature() -> None:
    c = Canvas(1024, 500, TEAL)
    # Notebook centered vertically, offset left
    nb_x, nb_y, nb_w, nb_h = 90, 70, 300, 360
    c.rounded_rect(nb_x, nb_y, nb_w, nb_h, 24, WHITE)
    # Spine + lines proportional to the icon
    c.rect(nb_x + 34, nb_y + 32, 14, nb_h - 64, TEAL)
    c.rect(nb_x + 82, nb_y + 72, 192, 18, TEAL)
    c.rect(nb_x + 82, nb_y + 132, 192, 18, TEAL)
    c.rect(nb_x + 82, nb_y + 192, 192, 18, TEAL)
    c.rect(nb_x + 82, nb_y + 252, 150, 18, TEAL)
    save_png(HERE / "feature_graphic.png", 1024, 500, c.buf)


if __name__ == "__main__":
    render_icon()
    render_feature()
    print("wrote store_icon.png (512x512) and feature_graphic.png (1024x500)")
