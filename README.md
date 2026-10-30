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

## Install Klipper (Snapmaker firmware → Klipper)

[![Download: Klipper installation](https://img.shields.io/badge/Download-Klipper_installation-ff8a00?style=for-the-badge&logo=github)](https://github.com/Nimrasol/KlipperSnapmakerJ1-os/releases/latest/download/KlipperSnapmakerJ1-install.zip)

1. Unpack `KlipperSnapmakerJ1-install.zip` and copy its contents
   (`J1_V*.bin` and the folder `install`) to a USB stick (FAT32, 2 GB or
   more).
2. Plug the stick into the USB port on the front of the printer.
3. On the touch screen, start the firmware update from the USB stick and
   confirm.
4. Wait, leave the stick plugged in and do not switch the printer off.
   The printer does the rest by itself:
   - the Snapmaker update up to 99 %;
   - **Klipper installation**, then the screen stays dark for up to a
     minute;
   - the Snapmaker logo and white text while Klipper is written (a few
     minutes);
   - the Klipper main menu.
5. Connect the WLAN: **More → Network → WLAN**.
6. Calibrate in the **Calibration** menu before the first print.

If the screen **Klipper installation** reports a failure, tap **Back to
Snapmaker**: nothing has been changed yet.  The way back to the
Snapmaker firmware: [installation](docs/INSTALL.md#klipper--snapmaker-firmware).

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
> USB stick on the stock touch screen and the way back to the stock
> firmware work and are tested on one J1
> ([installation](docs/INSTALL.md)).

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
  the stock firmware package restores the Snapmaker system from a USB
  stick.

Details: [installation](docs/INSTALL.md),
[analysis of the module](docs/ANALYSIS.md), [design](docs/DESIGN.md),
[development](docs/DEVELOPMENT.md).

## Building

GitHub Actions builds the installation package (**Actions → Build → Run
workflow**, or a tag `vX.Y.Z`).  Building by hand, how the USB stick
installation works and the installation in EDL mode:
[development](docs/DEVELOPMENT.md).

| Path | Content |
| --- | --- |
| `build.sh` | builds `out/lk2nd.img`, `out/linux-boot.img` and `out/userdata.img` |
| `boot/` | lk2nd and kernel build (pinned commits), `extlinux.conf` |
| `rootfs/` | Debian packages, setup of the Klipper stack, services, configuration |
| `install/` | installation package for the USB stick (stock firmware → Klipper) |
| `stock/` | stock firmware package (Klipper → stock firmware) |
| `maint/` | maintenance system, writes the systems from the USB stick |
| `tools/` | partitions of an eMMC dump |
| `docs/` | installation, analysis, design, development |

## License

GNU GPLv3 for the files of this repository, see [LICENSE](LICENSE).
lk2nd, Linux, Debian, Klipper, Moonraker and KlipperScreen keep their
licenses.
