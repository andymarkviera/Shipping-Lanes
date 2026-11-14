"""Builds features/app/app_icon.icns (macOS app icon), standard library only.

Run: python3 -I art_sources/app_icon/make_icon.py
Draws a toon container ship on a blue sea inside the macOS rounded-square
margin, at every size an .icns needs, and packs the PNGs into one .icns file.
"""
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "features" / "app" / "app_icon.icns"

SKY = (120, 200, 245)
SEA = (25, 90, 200)
FOAM = (235, 248, 255)
HULL = (205, 45, 40)
HULL_DARK = (40, 30, 45)
BRIDGE = (250, 250, 245)
BOXES = [(240, 170, 30), (40, 160, 90), (230, 90, 40), (60, 120, 220), (200, 60, 140)]


def colour(u, v):
    """RGBA for unit coordinates u, v in [0, 1] (v grows downward)."""
    # macOS icon grid: body is 824/1024 with ~185/1024 corner radius.
    m, r = 100 / 1024, 185 / 1024
    if not (m <= u <= 1 - m and m <= v <= 1 - m):
        return None
    cx = min(max(u, m + r), 1 - m - r)
    cy = min(max(v, m + r), 1 - m - r)
    if (u - cx) ** 2 + (v - cy) ** 2 > r * r:
        return None
    # Hull: trapezoid, deck at 0.56, keel at 0.68, bow on the right.
    if 0.56 <= v <= 0.68:
        t = (v - 0.56) / 0.12
        left, right = 0.22 + 0.04 * t, 0.80 - 0.07 * t
        if left <= u <= right:
            return HULL_DARK if v > 0.655 else HULL
    # Bridge block at the stern.
    if 0.25 <= u <= 0.33 and 0.40 <= v < 0.56:
        if 0.43 <= v <= 0.46 and 0.26 <= u <= 0.32:
            return HULL_DARK
        return BRIDGE
    # Container stacks: three rows, five columns.
    if 0.35 <= u <= 0.74 and 0.41 <= v < 0.56:
        col = int((u - 0.35) / 0.078)
        row = int((v - 0.41) / 0.05)
        lu = (u - 0.35) - col * 0.078
        lv = (v - 0.41) - row * 0.05
        if lu < 0.006 or lv < 0.006:
            return HULL_DARK
        return BOXES[(col * 2 + row) % len(BOXES)]
    # Foam band at the waterline, then sea, then sky.
    if 0.655 <= v <= 0.69:
        return FOAM
    if v > 0.66:
        stripe = int((v - 0.66) * 1024 / 34) % 2 == 1 and int(u * 1024 / 60 + v * 20) % 3 == 0
        return FOAM if stripe else SEA
    return SKY


def render(size):
    ss = 3 if size <= 256 else 2
    rows = []
    for y in range(size):
        row = bytearray([0])
        for x in range(size):
            acc = [0, 0, 0, 0]
            for sy in range(ss):
                for sx in range(ss):
                    c = colour((x + (sx + 0.5) / ss) / size, (y + (sy + 0.5) / ss) / size)
                    if c is not None:
                        acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; acc[3] += 255
            n = ss * ss
            alpha = acc[3] // n
            if alpha:
                cov = acc[3] / 255
                row += bytes([int(acc[0] / cov), int(acc[1] / cov), int(acc[2] / cov), alpha])
            else:
                row += b"\0\0\0\0"
        rows.append(bytes(row))
    return png(size, b"".join(rows))


def png(size, raw):
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


# icns PNG types: ic07 128, ic08 256, ic09 512, ic10 1024 (512@2x),
# ic11 32 (16@2x), ic12 64 (32@2x), ic13 256 (128@2x), ic14 512 (256@2x).
TYPES = [(b"ic11", 32), (b"ic12", 64), (b"ic07", 128), (b"ic08", 256),
         (b"ic13", 256), (b"ic09", 512), (b"ic14", 512), (b"ic10", 1024)]


def main():
    cache = {}
    body = b""
    for tag, size in TYPES:
        if size not in cache:
            cache[size] = render(size)
        body += tag + struct.pack(">I", len(cache[size]) + 8) + cache[size]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_bytes(b"icns" + struct.pack(">I", len(body) + 8) + body)
    print(f"wrote {OUT} ({len(body) + 8} bytes)")


if __name__ == "__main__":
    main()
