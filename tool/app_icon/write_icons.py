"""Builds the app icons from the robot art.

Runs render_icon_test.dart (Flutter draws each size as raw RGBA), then
writes opaque RGB PNGs into the iOS AppIcon set and the Android mipmaps.
The App Store rejects icons with an alpha channel, so none is written.

Usage, from the project root: python tool/app_icon/write_icons.py
"""

import json
import struct
import subprocess
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "build" / "app_icon"
IOS = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID = {
    "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
}


def png(path: Path, size: int):
    rgba = (RAW / f"icon_{size}.rgba").read_bytes()
    rows = b"".join(
        b"\x00" + b"".join(
            rgba[(y * size + x) * 4:(y * size + x) * 4 + 3]
            for x in range(size))
        for y in range(size))

    def chunk(kind, data):
        body = kind + data
        return (struct.pack(">I", len(data)) + body
                + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF))

    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows, 9))
        + chunk(b"IEND", b""))


def main():
    subprocess.run(
        ["flutter", "test", "tool/app_icon/render_icon_test.dart"],
        cwd=ROOT, check=True, shell=True)
    contents = json.loads((IOS / "Contents.json").read_text())
    for image in contents["images"]:
        points = float(image["size"].split("x")[0])
        scale = int(image["scale"][0])
        png(IOS / image["filename"], round(points * scale))
    for density, size in ANDROID.items():
        png(ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png",
            size)
    print("Icons written")


if __name__ == "__main__":
    main()
