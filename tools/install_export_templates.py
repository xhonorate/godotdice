#!/usr/bin/env python3
"""Install only the pinned desktop templates using validated ZIP HTTP ranges.

No third-party Python packages required. The upstream bundle also contains large
mobile templates, so its central directory identifies only requested members.
"""
import argparse
import concurrent.futures
import os
from pathlib import Path
import struct
import sys
import urllib.request
import zlib

VERSION = "4.7.2.stable"
URL = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
BUNDLE_SIZE = 1281349702
WANTED = {
    "macos.zip", "linux_release.x86_64", "linux_debug.x86_64",
    "windows_release_x86_64.exe", "windows_debug_x86_64.exe",
    "windows_release_x86_64_console.exe", "windows_debug_x86_64_console.exe",
    "version.txt", "icudt_godot.dat",
}

def fetch_range(start, end):
    request = urllib.request.Request(URL, headers={"Range": f"bytes={start}-{end}", "User-Agent": "RogueDice-template-installer/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        if response.status != 206:
            raise RuntimeError(f"Server ignored range request ({response.status}); refusing full bundle download")
        data = response.read()
    if len(data) != end - start + 1:
        raise RuntimeError("Incomplete export template download")
    return data

def entries():
    tail = fetch_range(BUNDLE_SIZE - 131072, BUNDLE_SIZE - 1)
    offset = tail.rfind(b"PK\x05\x06")
    if offset < 0:
        raise RuntimeError("Upstream ZIP end record was not found")
    end = struct.unpack_from("<4s4H2LH", tail, offset)
    directory_start, directory_size = end[6], end[5]
    data = tail[directory_start - (BUNDLE_SIZE - len(tail)):][:directory_size]
    result = []
    position = 0
    while position < len(data):
        item = struct.unpack_from("<4s6H3L5H2L", data, position)
        if item[0] != b"PK\x01\x02":
            raise RuntimeError("Malformed upstream ZIP central directory")
        name = data[position + 46:position + 46 + item[10]].decode("utf-8")
        if name.removeprefix("templates/") in WANTED:
            result.append((name.removeprefix("templates/"), item[4], item[7], item[8], item[9], item[16]))
        position += 46 + item[10] + item[11] + item[12]
    if {entry[0] for entry in result} != WANTED:
        raise RuntimeError("Upstream bundle is missing a pinned desktop template")
    return result

def install(entry, target):
    name, method, crc, compressed_size, uncompressed_size, offset = entry
    destination = target / name
    if destination.exists() and destination.stat().st_size == uncompressed_size:
        # Avoid redownloading only when exact ZIP CRC also verifies.
        if zlib.crc32(destination.read_bytes()) & 0xFFFFFFFF == crc:
            print(f"Already verified: {name}", flush=True)
            return
    header = fetch_range(offset, offset + 29)
    fields = struct.unpack("<4s5H3L2H", header)
    if fields[0] != b"PK\x03\x04":
        raise RuntimeError("Malformed ZIP member header")
    start = offset + 30 + fields[-2] + fields[-1]
    print(f"Downloading {name} ({compressed_size // 1048576} MiB)", flush=True)
    packed = fetch_range(start, start + compressed_size - 1)
    data = packed if method == 0 else zlib.decompress(packed, -15) if method == 8 else None
    if data is None or len(data) != uncompressed_size or zlib.crc32(data) & 0xFFFFFFFF != crc:
        raise RuntimeError(f"Template integrity check failed: {name}")
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    temporary.write_bytes(data)
    temporary.replace(destination)
    if name.startswith("linux_"):
        destination.chmod(0o755)
    print(f"Installed: {name}", flush=True)

def default_directory():
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support/Godot/export_templates" / VERSION
    if os.name == "nt":
        return Path(os.environ["APPDATA"]) / "Godot/export_templates" / VERSION
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot/export_templates" / VERSION

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=default_directory())
    args = parser.parse_args()
    args.directory.mkdir(parents=True, exist_ok=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        list(executor.map(lambda entry: install(entry, args.directory), entries()))
    print(f"Godot {VERSION} desktop templates ready at {args.directory}")

if __name__ == "__main__":
    main()
