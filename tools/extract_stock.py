#!/usr/bin/env python3
# Extract the stock parts the image needs from a full eMMC dump of the J1
# display module
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# The kernel, its modules and the WLAN firmware belong to Quectel,
# Qualcomm and Snapmaker and are not part of this repository; they are
# taken from the dump of the user's own display module (read with the
# Qualcomm EDL mode, see docs/INSTALL.md).
#
# Output (in OUTDIR):
#   partitions.json        GPT of the dump (offsets, sizes)
#   boot.img               stock boot partition (kernel with device trees)
#   modem.img              NON-HLOS firmware (vfat, mounted as /firmware)
#   persist.img            calibration data (ext4, mounted as /persist)
#   system/...             WLAN driver and configuration from /system
import argparse, json, os, struct, subprocess, sys

# The firmware directory links WCNSS_qcom_cfg.ini to /data and the NV
# file to /persist; Android copies the configuration from /etc/wifi.  The
# NV file is read from persist.img when the root file system is built.
SYSTEM_FILES = [
    "lib/modules/pronto/pronto_wlan.ko",
    "etc/firmware/wlan/prima/WCNSS_cfg.dat",
    "etc/wifi/WCNSS_qcom_cfg.ini",
    "build.prop",
]
COPY_PARTITIONS = ["boot", "modem", "persist"]


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
            out.write(chunk)
            remaining -= len(chunk)


def extract_system(dump, part, outdir):
    # debugfs reads the ext4 system partition straight from the dump
    source = "%s?offset=%d" % (dump, part["offset"])
    for name in SYSTEM_FILES:
        dest = os.path.join(outdir, "system", name)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        result = subprocess.run(
            ["debugfs", "-R", "dump /%s %s" % (name, dest), source],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        if not os.path.exists(dest) or os.path.getsize(dest) == 0:
            sys.exit("%s not found in the system partition: %s"
                     % (name, result.stderr.decode(errors="replace")))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("dump", help="full eMMC dump (sc20w-emmc-full.bin)")
    parser.add_argument("outdir")
    args = parser.parse_args()
    os.makedirs(args.outdir, exist_ok=True)
    with open(args.dump, "rb") as f:
        parts = read_gpt(f)
        for name in COPY_PARTITIONS:
            copy_partition(f, parts[name],
                           os.path.join(args.outdir, name + ".img"))
    extract_system(os.path.abspath(args.dump), parts["system"], args.outdir)
    with open(os.path.join(args.outdir, "partitions.json"), "w") as f:
        json.dump(parts, f, indent=1)
    print("extracted %s, system files and partitions.json to %s"
          % (", ".join(n + ".img" for n in COPY_PARTITIONS), args.outdir))


if __name__ == "__main__":
    main()
