#!/usr/bin/env python3
# Check that every free block of an ext2/3/4 image holds only zeros, so
# that nothing removed from it can be read again
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: check_free.py IMAGE
import re, subprocess, sys


def free_ranges(image):
    out = subprocess.run(["dumpe2fs", image], capture_output=True,
                         text=True, check=True).stdout
    bsize = int(re.search(r"^Block size:\s*(\d+)", out, re.M).group(1))
    ranges = []
    for line in re.findall(r"^\s*Free blocks: (.+)$", out, re.M):
        for part in line.split(", "):
            first, _, last = part.partition("-")
            ranges.append((int(first), int(last or first)))
    return bsize, ranges


def main():
    image = sys.argv[1]
    bsize, ranges = free_ranges(image)
    dirty = total = 0
    with open(image, "rb") as f:
        for first, last in ranges:
            f.seek(first * bsize)
            for i in range(last - first + 1):
                total += 1
                if f.read(bsize).strip(b"\0"):
                    dirty += 1
    print("%s: %d free blocks, %d not zero" % (image, total, dirty))
    if dirty:
        sys.exit(1)


if __name__ == "__main__":
    main()
