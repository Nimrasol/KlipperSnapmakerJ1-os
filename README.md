# KlipperSnapmakerJ1-os

Linux for the display module of the Snapmaker J1 (Quectel SC20-W), so that
the display runs Klipper, Moonraker and KlipperScreen like a Raspberry Pi
does on other printers.

> **Status: experimental.**  The image builds, the boot image signature is
> verified against the stock one, and the user space is tested in
> emulation.  It has not been booted on a printer yet.

This project is not affiliated with or endorsed by Snapmaker.

## Related repositories

| Repository | Content |
| --- | --- |
| [KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1) | Klipper modules, printer configuration, KlipperScreen add-on and theme, main controller firmware patch |
| **KlipperSnapmakerJ1-os** (this one) | Linux image for the J1 display module, the Klipper host |
| [Nimrasol/klipper](https://github.com/Nimrasol/klipper/tree/j1), branch `j1` | Klipper fork with the firmware changes (GD32F305, J1 factory bootloader) as commits on Klipper; the same changes as `firmware/klipper-gd32f305-snapmaker.patch`. The printer runs unmodified Klipper |

The image is installed once.  Afterwards everything printer specific comes
from [KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1)
and is updated through the Moonraker update manager, like Klipper,
Moonraker and KlipperScreen.

## How it works

* The **stock kernel** of the display module (no source available) boots
  a small initramfs of this project instead of Android.  The locked
  bootloader accepts it: it trusts the public AOSP test key, which signs
  the boot image ([analysis](docs/ANALYSIS.md#verified-boot)).
* The initramfs mounts the **userdata partition**, which holds Debian
  bookworm (armhf) with sysvinit, Klipper, Moonraker, KlipperScreen and
  KlipperSnapmakerJ1.
* X runs on the framebuffer with the touch screen; the main controller is
  on `/dev/ttyHSL1`; WLAN uses the stock driver; a USB network gives SSH
  access for setup and rescue.
* The bootloader, Android system and firmware partitions stay unchanged;
  your EDL backup restores the stock system.

Details: [analysis of the module](docs/ANALYSIS.md),
[design](docs/DESIGN.md), [installation](docs/INSTALL.md).

## Building

```
./build.sh /path/to/sc20w-emmc-full.bin [../KlipperSnapmakerJ1]
```

Needs Docker and `qemu-user-static` on Linux or WSL2, and a full eMMC dump
of your own display module: the stock kernel, the WLAN driver and
firmware and the Snapmaker calibration pictures are taken from it and are
not part of this repository.

| Path | Content |
| --- | --- |
| `build.sh` | builds `out/boot.img` and `out/userdata.img` |
| `tools/` | boot image unpack/pack and signing, extraction from the dump |
| `initramfs/` | `/init` (find and mount the root file system, rescue shell) |
| `rootfs/` | Debian packages, setup of the Klipper stack, boot scripts, configuration |
| `docs/` | analysis, design, installation |

## License

GNU GPLv3 for the files of this repository, see [LICENSE](LICENSE).
Debian, Klipper, Moonraker and KlipperScreen keep their licenses.  The
AOSP test key is published by the Android Open Source Project under the
Apache License 2.0 and downloaded at build time.
