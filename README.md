# KlipperSnapmakerJ1-os

**The operating system of the display module for
[Klipper on the Snapmaker J1](https://github.com/Nimrasol/KlipperSnapmakerJ1).**

The touch screen of the J1 is a small computer of its own (Quectel SC20-W
module).  This repository turns it into the Klipper host of the printer:
it builds the Linux system that runs Klipper, Moonraker, KlipperScreen and
Mainsail on the display, the way a Raspberry Pi does on other printers.
That is why the J1 needs no extra computer or screen for Klipper.

> **Looking for the firmware for your J1?**  Start at
> [KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1):
> the features, the user manual, the download and the installation are
> there.  This repository is for building the display system yourself.

## The project at a glance

| Repository | Role in the project |
| --- | --- |
| [KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1) | **Start here.** Everything printer specific: Klipper modules and configuration, the KlipperScreen calibration menu and theme, the main controller firmware, the user manual, downloads and installation |
| **KlipperSnapmakerJ1-os** (this one) | The Linux system of the display module: boot loader, kernel, Debian with Klipper, Moonraker, KlipperScreen and Mainsail. Installed once |
| [Nimrasol/klipper](https://github.com/Nimrasol/klipper/tree/j1), branch `j1` | Klipper with the main controller support (GD32F305 chip, J1 factory bootloader) as commits, for reference and review. The printer itself runs unmodified Klipper |

The system is installed once.  Afterwards everything printer specific
comes from KlipperSnapmakerJ1 and is updated through the Moonraker update
manager, like Klipper, Moonraker, KlipperScreen and Mainsail.

> **Status:** runs on the J1 (board revision 2): KlipperScreen with the J1
> theme on the display, WLAN, SSH, Mainsail, Klipper connected to the main
> controller, printing and the calibration menu.  The installation from a
> USB stick is in preparation; today the image is installed in the EDL
> mode of the module ([installation](docs/INSTALL.md)).

## How it works

* The stock bootloader (unchanged) starts
  [lk2nd](https://github.com/msm8916-mainline/lk2nd) from the **boot
  partition**.  lk2nd sets up the panel and starts Linux from the
  **cache partition** (`extlinux.conf`, kernel, device tree).
* A **mainline kernel** (msm8916-mainline 6.12) with the device tree of
  the J1 display module.  lk2nd and the device tree are the work of
  [eazrael](https://wiki.evilazrael.de/snapmaker-j1-klipper-installation);
  this project builds them from his repositories at fixed commits.
* The **userdata partition** holds a minimal Debian bookworm (armhf,
  systemd) with Klipper, Moonraker, KlipperScreen and KlipperSnapmakerJ1.
  KlipperScreen runs in the Wayland kiosk `cage`, without a desktop;
  Mainsail is served on port 80 and the printer is found as
  `snapmaker-j1.local` (the name can be changed in KlipperScreen).  When
  the WLAN connects, a NetworkManager dispatcher script lets Moonraker
  check for updates (it checks otherwise only at its start and weekly).
  Linux is up about 8 s after the bootloader.
* The main controller is on `/dev/ttyMSM1`; WLAN uses the open `wcn36xx`
  driver with the firmware of the module's own modem and persist
  partitions.
* The Qualcomm boot chain, Android system and recovery stay unchanged;
  your EDL backup restores the stock system.

Details: [analysis of the module](docs/ANALYSIS.md),
[design](docs/DESIGN.md), [installation](docs/INSTALL.md).

## Building

```
./build.sh /path/to/sc20w-emmc-full.bin [../KlipperSnapmakerJ1]
```

Needs Docker and `qemu-user-static` on Linux or WSL2, and a full eMMC dump
of your own display module: the WLAN driver and configuration of its
system partition are taken from it and are not part of this repository.

| Path | Content |
| --- | --- |
| `build.sh` | builds `out/lk2nd.img`, `out/linux-boot.img` and `out/userdata.img` |
| `boot/` | lk2nd and kernel build (pinned commits), `extlinux.conf` |
| `rootfs/` | Debian packages, setup of the Klipper stack, services, configuration |
| `tools/` | extraction from the dump |
| `docs/` | analysis, design, installation |

## License

GNU GPLv3 for the files of this repository, see [LICENSE](LICENSE).
lk2nd, Linux, Debian, Klipper, Moonraker and KlipperScreen keep their
licenses.
