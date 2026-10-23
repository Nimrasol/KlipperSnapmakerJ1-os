#!/bin/bash
# Build lk2nd and the mainline Linux kernel for the J1 display module
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
#
# Usage: boot/build.sh OUT_DIR
#
# Results in OUT_DIR: lk2nd.img (for the boot partition), zImage,
# snapmakerj1.dtb, kernelrelease and modules/ (to install in the root file
# system).
#
# lk2nd (a second stage bootloader started by the stock bootloader) turns
# on the panel, keeps the display controller scanning out a framebuffer and
# boots the kernel named in extlinux/extlinux.conf of an ext2 partition.
# Both parts come from eazrael's Snapmaker J1 port (klipper4j1): his lk2nd
# branch, and his device tree and kernel configuration for the kernel of
# the msm8916-mainline project.  They are fetched at fixed revisions
# (boot/inside.sh).
set -e

[ -n "$1" ] || { sed -n '8,12p' "$0"; exit 1; }
OUT="$(realpath -m "$1")"
SRC="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$OUT"

docker run --rm -v "$OUT:/out" -v "$SRC:/src:ro" debian:bookworm \
    bash -e /src/inside.sh
ls -l "$OUT"
