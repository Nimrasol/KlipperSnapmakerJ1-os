# Installation

> **Experimental.**  The image has been built and its user space tested in
> emulation, but it has not been booted on a printer yet.  Keep the full
> backup of your display module: it is the way back to the stock system.

## What you need

* A full eMMC backup of your display module (`sc20w-emmc-full.bin`), read
  in Qualcomm EDL mode with [bkerler/edl](https://github.com/bkerler/edl):
  `edl rf sc20w-emmc-full.bin`.  The build takes the stock kernel, WLAN
  driver and firmware and the calibration pictures from it.  The stock
  Android has ADB enabled, so `adb reboot edl` enters the EDL mode over
  the same USB connection.
* A Linux PC (or WSL2) with Docker and `qemu-user-static` (binfmt handler
  for ARM).
* [KlipperSnapmakerJ1](https://github.com/Nimrasol/KlipperSnapmakerJ1)
  checked out next to this repository.

## 1. Main controller firmware (while the stock display still runs)

The main controller has to run the Klipper firmware before the display
changes, because the stock display installs it through its USB update.
Build it from the Klipper version the image contains (the one in
`KlipperSnapmakerJ1/versions.conf`):

```
git clone https://github.com/Klipper3d/klipper.git ~/klipper
git -C ~/klipper checkout \
    $(awk '$1 == "klipper" {print $2}' KlipperSnapmakerJ1/versions.conf)
KLIPPER_DIR=~/klipper KlipperSnapmakerJ1/firmware/build.sh
```

(needs `gcc-arm-none-eabi`), copy `KlipperSnapmakerJ1/firmware/out/update.bin`
to a USB stick and install it with the display's firmware update from
USB.  Afterwards the stock display can no longer control the printer;
later firmware updates are installed from Linux with
`scripts/snapmaker_j1_flash.py` (see the docs of KlipperSnapmakerJ1).

## 2. Build the image

```
./build.sh /path/to/sc20w-emmc-full.bin
```

Results: `out/boot.img` (stock kernel with the initramfs of this project,
signed for the stock bootloader) and `out/userdata.img` (the Linux root
file system, grown to the partition on the first boot).

## 3. Flash the display module

Put the display module into EDL mode (`adb reboot edl` from the stock
system, `sudo reboot-edl` from KlipperSnapmakerJ1-os) and write the two
partitions:

```
edl w boot out/boot.img
edl w userdata out/userdata.img
edl reset
```

This replaces the Android data partition (the Snapmaker application and
its data); system, recovery and the boot chain stay unchanged.

## 4. First boot

The bootloader shows its logo, then Linux starts.  The first boot grows
the file system and creates the SSH keys, then KlipperScreen appears.

* **Screen upside down or touch mirrored:** change `ROTATION` (CW/CCW)
  or `TOUCH_ROTATION` in `/etc/klipper-os.conf` and reboot.
* **Black screen:** connect over USB (below) and check
  `/var/log/supervisor/KlipperScreen.out` and `/var/log/Xorg.0.log`.

## 5. Access and WLAN

The display module offers a USB network (RNDIS) on the USB connection
used for EDL: give the PC the address `192.168.42.2/24`, then

```
ssh pi@192.168.42.1        # password: klipper - change it with passwd
```

Add your WLAN to `/etc/wpa_supplicant/wpa_supplicant.conf` and run
`sudo /etc/init.d/j1-network restart`.  Mainsail or Fluidd can then use
Moonraker on port 7125 of the printer.

## Updates

Moonraker's update manager updates Klipper, Moonraker, KlipperScreen and
KlipperSnapmakerJ1 from their GitHub repositories (KlipperSnapmakerJ1 only
while its repository is public; otherwise Moonraker cannot fetch it).
The image installs the versions of `KlipperSnapmakerJ1/versions.conf`.  When a Klipper update changes the protocol to the
main controller, Klipper reports it; rebuild the firmware on the display
module with `~/KlipperSnapmakerJ1/firmware/build.sh` and install it.

## Rescue

If the root file system cannot be started, the initramfs offers a shell
over the USB network: `telnet 192.168.42.1`.  Creating `/rescue` on the
root file system enters this shell on purpose.

## Back to the stock system

1. Main controller, while Linux still runs: stop Klipper and install a
   stock `mc.bin` with `scripts/snapmaker_j1_flash.py` of
   KlipperSnapmakerJ1 (the cached package of the stock display is in
   the backup at `/data/data/com.snapmaker.j1/app_update/mc.bin`).
2. Display module, from your backup:
   ```
   tools/extract_partition.py sc20w-emmc-full.bin boot boot-stock.img
   tools/extract_partition.py sc20w-emmc-full.bin userdata userdata-stock.img
   edl w boot boot-stock.img
   edl w userdata userdata-stock.img
   edl reset
   ```
