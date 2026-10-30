# Installation

Klipper is installed from a USB stick on the Snapmaker touch screen.  The
way back to the Snapmaker firmware works the same way.  No tools, no
opening of the printer.

## Downloads

[![Download: Klipper installation](https://img.shields.io/badge/Download-Klipper_installation-ff8a00?style=for-the-badge&logo=github)](https://github.com/Nimrasol/KlipperSnapmakerJ1-os/releases/latest/download/KlipperSnapmakerJ1-install.zip)
&nbsp;
[![Download: Stock firmware](https://img.shields.io/badge/Download-Stock_firmware-555555?style=for-the-badge&logo=github)](https://github.com/Nimrasol/KlipperSnapmakerJ1-os/releases/latest/download/J1-Stock-Firmware.zip)

| File | For |
| --- | --- |
| `KlipperSnapmakerJ1-install.zip` | Snapmaker firmware → Klipper |
| `J1-Stock-Firmware.zip` | Klipper → Snapmaker firmware |

You need a USB stick formatted with FAT32 (2 GB or more).  Unpack the
zip file and copy **its contents** to the top level of the stick.

## Snapmaker firmware → Klipper

1. Copy the contents of `KlipperSnapmakerJ1-install.zip` to the stick:
   `J1_V*.bin` and the folder `install`.
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
Snapmaker**: nothing has been changed yet.

> [!WARNING]
> **Calibrate the printer right after the installation, before the first
> print.**  Klipper starts with the values of an uncalibrated J1: the
> nozzle height above the bed and the offset between the two nozzles are
> not right, the first layer fails and a nozzle can crash into the bed.
> In the **Calibration** menu run the assisted workflows in this order:
> **Heated Bed Leveling, Z Offset Calibration, XY Offset Calibration,
> Offset Calibration Check**, then **Vibration Compensation** once.

## Klipper → Snapmaker firmware

1. Copy the contents of `J1-Stock-Firmware.zip` to the stick:
   `J1_V*.bin` and the folder `stock-restore`.
2. Plug the stick into the USB port on the front of the printer.
3. On the touch screen: **More → System**, scroll to the end, tap
   **Stock Firmware**, then **Restore Stock Firmware** and confirm.
4. Wait, leave the stick plugged in and do not switch the printer off.
   The printer restarts by itself and starts the Snapmaker system (a few
   minutes).
5. The Snapmaker setup starts as on a new printer: language, WLAN and the
   calibrations.

## After the installation

The printer is reachable at **http://snapmaker-j1.local** (Mainsail).
The [user manual](https://github.com/Nimrasol/KlipperSnapmakerJ1/blob/main/docs/Manual.md)
describes every screen.  Updates come through **More → Update**.

Building the packages yourself and the installation in EDL mode:
[development](DEVELOPMENT.md).
