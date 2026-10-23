# KlipperSnapmakerJ1-os

Linux for the display module of the Snapmaker J1 (Quectel SC20-W), so that
the display runs Klipper, Moonraker and KlipperScreen like a Raspberry Pi
does on other printers.

> **Status: experimental.**  The image boots on a J1 (board revision 2):
> KlipperScreen with the J1 theme on the display, WLAN, SSH, Klipper
> connected to the main controller.  The full calibration on the printer
> is not tested yet.

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
  `snapmaker-j1.local` (the name can be changed in KlipperScreen).
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
of your own display module: the calibration pictures and test prints of
the Snapmaker application are taken from it and are not part of this
repository.

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
