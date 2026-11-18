"""Make the in-game icon from the logo: docs/logo.png -> Media/icon.tga.

    python scripts/make_icon.py

Decodes the PNG (8-bit RGB or RGBA, not interlaced), scales it to 64x64 by
averaging (gamma-correct) and writes an uncompressed 32-bit TGA, as the client
loads it. Python 3 standard library only.
"""
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOGO = ROOT / "docs" / "logo.png"
ICON = ROOT / "ForeverJunkItems" / "Media" / "icon.tga"
SIZE = 64


def read_png(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG file")
    pos, idat, header = 8, b"", None
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            idat += body
        elif kind == b"IEND":
            break
        pos += 12 + length
    width, height, depth, color, _, _, interlace = header
    if depth != 8 or color not in (2, 6) or interlace:
        raise ValueError("needs an 8-bit RGB or RGBA PNG without interlacing")
    channels = 4 if color == 6 else 3
    raw = zlib.decompress(idat)
    stride = width * channels
    rows, previous, pos = [], bytearray(stride), 0
    for _ in range(height):
        kind = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = previous[i]
            corner = previous[i - channels] if i >= channels else 0
            if kind == 1:
                line[i] = (line[i] + left) & 255
            elif kind == 2:
                line[i] = (line[i] + up) & 255
            elif kind == 3:
                line[i] = (line[i] + (left + up) // 2) & 255
            elif kind == 4:
                p = left + up - corner
                pa, pb, pc = abs(p - left), abs(p - up), abs(p - corner)
                predictor = left if pa <= pb and pa <= pc else (up if pb <= pc else corner)
                line[i] = (line[i] + predictor) & 255
        rows.append(line)
        previous = line
    return width, height, channels, rows


def downscale(width, height, channels, rows, size):
    to_linear = [(v / 255.0) ** 2.2 for v in range(256)]
    out = bytearray()
    for ty in range(size):
        y0, y1 = ty * height // size, (ty + 1) * height // size
        for tx in range(size):
            x0, x1 = tx * width // size, (tx + 1) * width // size
            acc = [0.0, 0.0, 0.0, 0.0]
            count = 0
            for y in range(y0, y1):
                row = rows[y]
                for x in range(x0, x1):
                    i = x * channels
                    alpha = row[i + 3] / 255.0 if channels == 4 else 1.0
                    for c in range(3):
                        acc[c] += to_linear[row[i + c]] * alpha
                    acc[3] += alpha
                    count += 1
            alpha = acc[3] / count
            rgb = [((acc[c] / acc[3]) ** (1 / 2.2)) if acc[3] else 0.0 for c in range(3)]
            out += bytes(int(round(v * 255)) for v in rgb) + bytes((int(round(alpha * 255)),))
    return out


def write_tga(path, size, rgba):
    # Uncompressed true colour, 32 bits, origin top left (descriptor 0x28).
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, size, size, 32, 0x28)
    body = bytearray()
    for i in range(0, len(rgba), 4):
        r, g, b, a = rgba[i:i + 4]
        body += bytes((b, g, r, a))
    path.write_bytes(header + bytes(body))


def main():
    width, height, channels, rows = read_png(LOGO)
    if width != height:
        print(f"logo must be square, got {width}x{height}", file=sys.stderr)
        return 1
    write_tga(ICON, SIZE, downscale(width, height, channels, rows, SIZE))
    print(f"{ICON.relative_to(ROOT).as_posix()} written from {width}x{height} logo")
    return 0


if __name__ == "__main__":
    sys.exit(main())
