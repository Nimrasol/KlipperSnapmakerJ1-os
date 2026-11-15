#!/usr/bin/env python3
# Write one partition of a full eMMC dump to a file (to restore it by EDL)
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: extract_partition.py DUMP NAME OUT
#   eg the stock userdata to return to Android:
#   extract_partition.py sc20w-emmc-full.bin userdata userdata-stock.img
# read_gpt is also used by stock/build.sh.
import struct, sys


def read_gpt(f):
    f.seek(512)
    hdr = f.read(92)
    if hdr[:8] != b"EFI PART":
        raise ValueError("no GPT found; is this a full eMMC dump?")
    entries_lba, count, size = struct.unpack_from("<QII", hdr, 72)
    f.seek(entries_lba * 512)
    table = f.read(count * size)
    parts = {}
    for i in range(count):
        e = table[i * size:(i + 1) * size]
        if e[:16] == b"\0" * 16:
            continue
        first, last = struct.unpack_from("<QQ", e, 32)
        name = e[56:128].decode("utf-16le").rstrip("\0")
        parts[name] = {"index": i + 1, "offset": first * 512,
                       "size": (last - first + 1) * 512}
    return parts


def copy_partition(f, part, path):
    f.seek(part["offset"])
    remaining = part["size"]
    with open(path, "wb") as out:
        while remaining:
            chunk = f.read(min(remaining, 1 << 22))
            if not chunk:
                sys.exit("the dump ends inside partition %d (%d bytes "
                         "missing): is it complete?"
                         % (part["index"], remaining))
            out.write(chunk)
            remaining -= len(chunk)


def main():
    if len(sys.argv) != 4:
        sys.exit("Usage: extract_partition.py DUMP NAME OUT")
    dump, name, out = sys.argv[1:]
    with open(dump, "rb") as f:
        parts = read_gpt(f)
        if name not in parts:
            sys.exit("no partition %s; partitions: %s"
                     % (name, ", ".join(sorted(parts))))
        copy_partition(f, parts[name], out)
    print("%s: %d bytes (partition %d)" % (out, parts[name]["size"],
                                            parts[name]["index"]))


if __name__ == "__main__":
    main()
