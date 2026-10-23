#!/bin/bash
# Container part of boot/build.sh: build lk2nd and the kernel into /out
#
# Copyright (C) 2026  Nimrasol
#
# This file may be distributed under the terms of the GNU GPLv3 license.
set -e

LK2ND_REPO=https://github.com/eazrael/lk2nd.git
LK2ND_COMMIT=f4cb316c8e0c0c0b245399132a44866a63566062
J1_PORT_REPO=https://github.com/eazrael/armbian-build.git
J1_PORT_COMMIT=6bc46d71bfd9d1c3774a47ebd5f5033fc8be8667
KERNEL_REPO=https://github.com/msm8916-mainline/linux.git
KERNEL_TAG=v6.12.1-msm8916
DTB=qcom-msm8909-snapmakerj1

export DEBIAN_FRONTEND=noninteractive
apt-get -qq update
apt-get -qq install -y --no-install-recommends git make gcc-arm-none-eabi \
    libnewlib-arm-none-eabi gcc-arm-linux-gnueabihf libc6-dev-armhf-cross \
    bc bison flex libssl-dev python3 device-tree-compiler kmod cpio \
    xz-utils lz4 zstd ca-certificates gcc libc6-dev > /dev/null
mkdir -p /build
cd /build

# lk2nd at the revision of the klipper4j1 release
git clone -q "$LK2ND_REPO" lk2nd
git -C lk2nd -c advice.detachedHead=false checkout -q "$LK2ND_COMMIT"
make -C lk2nd -s -j"$(nproc)" BOOTLOADER_OUT=snapmakerj1 \
    TOOLCHAIN_PREFIX=arm-none-eabi- lk2nd-msm8909
cp lk2nd/snapmakerj1/*/lk2nd.img /out/lk2nd.img

# Kernel with the J1 device tree and configuration
git init -q j1port
git -C j1port fetch -q --depth 1 "$J1_PORT_REPO" "$J1_PORT_COMMIT"
git -C j1port -c advice.detachedHead=false checkout -q FETCH_HEAD
git clone -q --depth 1 -b "$KERNEL_TAG" "$KERNEL_REPO" linux
cd linux
cp ../j1port/patch/kernel/archive/msm8909-6.12/dt/snapmakerj1.dts \
    arch/arm/boot/dts/qcom/$DTB.dts
grep -q "$DTB.dtb" arch/arm/boot/dts/qcom/Makefile ||
    echo "dtb-\$(CONFIG_ARCH_QCOM) += $DTB.dtb" >> arch/arm/boot/dts/qcom/Makefile
cp ../j1port/config/kernel/linux-msm8909-snapmakerj1.config .config
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-
make -s olddefconfig
make -s -j"$(nproc)" zImage dtbs modules
rm -rf /out/modules
make -s modules_install INSTALL_MOD_PATH=/out/modules INSTALL_MOD_STRIP=1
cp arch/arm/boot/zImage /out/zImage
cp arch/arm/boot/dts/qcom/$DTB.dtb /out/snapmakerj1.dtb
make -s kernelrelease > /out/kernelrelease
{
    echo "lk2nd $(git -C ../lk2nd describe --always --tags)"
    echo "j1port $(git -C ../j1port rev-parse --short HEAD)"
    echo "linux $KERNEL_TAG"
} > /out/versions
