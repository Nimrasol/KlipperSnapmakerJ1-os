# KlipperSnapmakerJ1-os

Linux image for the display module of the Snapmaker J1 (Quectel SC20-W),
so that the display runs Klipper, Moonraker and KlipperScreen like a
Raspberry Pi does on other printers.

> **Status:** planned.  This repository does not contain a build yet.

This project is not affiliated with or endorsed by Snapmaker.

## Related repository

| Repository | Content |
| --- | --- |
| [KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1) | Klipper modules, printer configuration, KlipperScreen add-on and theme, main controller firmware patch |
| **KlipperSnapmakerJ1-os** (this one) | Linux image for the J1 display module, the Klipper host |

The image is installed once.  Afterwards everything printer specific comes
from [KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1)
and is updated through the Moonraker update manager; Klipper, Moonraker
and KlipperScreen are updated through their own entries.

## Planned content

* Build of a Linux system for the SC20-W (kernel, display and touch
  drivers, root file system), built on a PC or with GitHub Actions and
  published as release images.
* Serial connection to the main controller (`/dev/ttyMSM1`), power and
  display handling of the J1.
* Klipper, Moonraker and KlipperScreen preinstalled, with
  KlipperSnapmakerJ1 set up by its `install.sh`.
* Instructions to flash the image and to return to the stock Android
  system.

## License

GNU GPLv3 for the build scripts of this repository.  Third-party
components keep their own licenses.
