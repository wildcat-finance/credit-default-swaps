#!/usr/bin/env python3
import hashlib
import pathlib
import struct
import sys

root = pathlib.Path(__file__).resolve().parent.parent
manifest = root / "config/assets.sha256"
expected = {}
for line in manifest.read_text().splitlines():
    digest, name = line.split(maxsplit=1)
    expected[name] = digest

assets = sorted((root / "docs/bd/assets").glob("*.png"))
seen = set()
failed = False
for asset in assets:
    relative = asset.relative_to(root).as_posix()
    seen.add(relative)
    data = asset.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        print(f"{relative}: not a PNG", file=sys.stderr)
        failed = True
        continue
    width, height = struct.unpack(">II", data[16:24])
    if (width, height) != (1920, 1080):
        print(f"{relative}: {width}x{height}; expected 1920x1080", file=sys.stderr)
        failed = True
    digest = hashlib.sha256(data).hexdigest()
    if expected.get(relative) != digest:
        print(f"{relative}: hash mismatch", file=sys.stderr)
        failed = True

if seen != set(expected):
    print("asset manifest and PNG directory differ", file=sys.stderr)
    failed = True

authored_svgs = [
    path for path in root.rglob("*.svg")
    if ".git" not in path.parts and "lib" not in path.parts
]
if authored_svgs:
    print("authored SVG files are not permitted", file=sys.stderr)
    failed = True

if failed:
    raise SystemExit(1)
print("Image dimensions, hashes and raster-only policy passed")
