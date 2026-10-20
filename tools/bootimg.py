#!/usr/bin/env python3
# Unpack and pack Android boot images (header version 0) of the SC20-W
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# The stock image has the device trees appended to the zImage (dt size 0
# in the header) and the AOSP verified boot signature after the image.
import argparse, json, os, struct, sys

MAGIC = b"ANDROID!"
HEADER = "<8s10I16s512s32s1024s"


def pad(n, page):
    return (n + page - 1) // page * page


def read_header(data):
    if data[:8] != MAGIC:
        raise ValueError("not an Android boot image")
    (magic, kernel_size, kernel_addr, ramdisk_size, ramdisk_addr,
     second_size, second_addr, tags_addr, page_size, dt_size, os_version,
     name, cmdline, image_id, extra_cmdline) = struct.unpack_from(HEADER,
                                                                  data)
    return {
        "kernel_size": kernel_size, "kernel_addr": kernel_addr,
        "ramdisk_size": ramdisk_size, "ramdisk_addr": ramdisk_addr,
        "second_size": second_size, "second_addr": second_addr,
        "tags_addr": tags_addr, "page_size": page_size, "dt_size": dt_size,
        "os_version": os_version,
        "name": name.rstrip(b"\0").decode(),
        "cmdline": (cmdline.rstrip(b"\0")
                    + extra_cmdline.rstrip(b"\0")).decode(),
        "image_id": image_id.hex(),
    }


def image_size(hdr):
    page = hdr["page_size"]
    return (page + pad(hdr["kernel_size"], page)
            + pad(hdr["ramdisk_size"], page) + pad(hdr["second_size"], page)
            + pad(hdr["dt_size"], page))


def unpack(path, outdir):
    data = open(path, "rb").read()
    hdr = read_header(data)
    page = hdr["page_size"]
    os.makedirs(outdir, exist_ok=True)
    pos = page
    for part in ("kernel", "ramdisk", "second", "dt"):
        size = hdr[part + "_size"]
        if size:
            with open(os.path.join(outdir, part), "wb") as f:
                f.write(data[pos:pos + size])
        pos += pad(size, page)
    with open(os.path.join(outdir, "header.json"), "w") as f:
        json.dump(hdr, f, indent=1)
    sig = data[pos:]
    if sig[:2] == b"\x30\x82":
        length = 4 + struct.unpack(">H", sig[2:4])[0]
        with open(os.path.join(outdir, "signature"), "wb") as f:
            f.write(sig[:length])
    return hdr


def pack(hdr, kernel, ramdisk, out, second=b"", dt=b""):
    page = hdr["page_size"]
    cmdline = hdr["cmdline"].encode()
    if len(cmdline) > 512 + 1024 - 2:
        raise ValueError("kernel command line too long")
    header = struct.pack(
        HEADER, MAGIC, len(kernel), hdr["kernel_addr"], len(ramdisk),
        hdr["ramdisk_addr"], len(second), hdr["second_addr"],
        hdr["tags_addr"], page, len(dt), hdr["os_version"],
        hdr["name"].encode(), cmdline[:511], bytes.fromhex(hdr["image_id"]),
        cmdline[511:])
    image = bytearray(header.ljust(page, b"\0"))
    for part in (kernel, ramdisk, second, dt):
        image += part + b"\0" * (pad(len(part), page) - len(part))
    with open(out, "wb") as f:
        f.write(image)
    return len(image)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("unpack", help="split a boot image into its parts")
    p.add_argument("image")
    p.add_argument("outdir")
    p = sub.add_parser("pack", help="build a boot image from its parts")
    p.add_argument("--header", required=True,
                   help="header.json of the stock image (addresses)")
    p.add_argument("--kernel", required=True)
    p.add_argument("--ramdisk", required=True)
    p.add_argument("--cmdline", help="replace the kernel command line")
    p.add_argument("out")
    args = parser.parse_args()
    if args.cmd == "unpack":
        hdr = unpack(args.image, args.outdir)
        print(json.dumps(hdr, indent=1))
    else:
        hdr = json.load(open(args.header))
        if args.cmdline is not None:
            hdr["cmdline"] = args.cmdline
        size = pack(hdr, open(args.kernel, "rb").read(),
                    open(args.ramdisk, "rb").read(), args.out)
        print("%s: %d bytes" % (args.out, size))


if __name__ == "__main__":
    sys.exit(main())
