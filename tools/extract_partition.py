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
import os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from extract_stock import copy_partition, read_gpt  # noqa: E402


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
