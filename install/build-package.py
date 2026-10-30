#!/usr/bin/env python3
# Build a Snapmaker J1 update package (J1_V*.bin) that the stock USB-update
# flow accepts, carrying the genuine stock main controller firmware (entry
# type 0) and our installer app (entry type 3).
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# The package format (from the stock app, UpdateFileParser):
#   offset 0   2 bytes   header tag
#   offset 2   32 bytes  version string ("J1_V...")
#   offset 38  1 byte    entry count N
#   offset 39  N*9 bytes table of contents, each entry:
#                          1 byte  type (0 MC, 1 EM, 2 BT, 3 screen APK)
#                          4 bytes offset from file start (big endian)
#                          4 bytes size (big endian)
#   then        the payloads at their offsets
#
# Usage: build-package.py STOCK_PACKAGE INSTALLER_APK OUT_PACKAGE
import struct, sys

HDR = 39  # bytes before the table of contents


def parse(data):
    n = data[38]
    entries = []
    for i in range(n):
        t, off, size = struct.unpack_from(">BII", data, HDR + 9 * i)
        entries.append({"type": t, "off": off, "size": size})
    name = data[2:2 + 32].split(b"\0")[0].decode("ascii", "replace").strip()
    return name, entries


def main():
    if len(sys.argv) != 4:
        sys.exit("Usage: build-package.py STOCK_PACKAGE INSTALLER_APK OUT")
    stock = open(sys.argv[1], "rb").read()
    apk = open(sys.argv[2], "rb").read()
    name, entries = parse(stock)
    mc = next((e for e in entries if e["type"] == 0), None)
    if mc is None:
        sys.exit("stock package has no main controller entry (type 0)")
    mc_bin = stock[mc["off"]:mc["off"] + mc["size"]]

    # New layout: header, then the genuine MC, then our APK.
    count = 2
    base = HDR + 9 * count
    mc_off = base
    apk_off = mc_off + len(mc_bin)
    out = bytearray(stock[:HDR])          # keep tag, version, and count field
    out[38] = count
    out += struct.pack(">BII", 0, mc_off, len(mc_bin))
    out += struct.pack(">BII", 3, apk_off, len(apk))
    assert len(out) == base
    out += mc_bin
    out += apk

    open(sys.argv[3], "wb").write(out)

    # Self-check: re-parse and confirm the payloads come back byte for byte.
    name2, entries2 = parse(bytes(out))
    data = bytes(out)
    for e in entries2:
        e["data"] = data[e["off"]:e["off"] + e["size"]]
    got_mc = next(e for e in entries2 if e["type"] == 0)["data"]
    got_apk = next(e for e in entries2 if e["type"] == 3)["data"]
    assert got_mc == mc_bin, "MC payload mismatch"
    assert got_apk == apk, "APK payload mismatch"
    print("package %s: %s  (MC %d bytes, installer %d bytes, total %d)"
          % (sys.argv[3], name2, len(mc_bin), len(apk), len(out)))


if __name__ == "__main__":
    main()
