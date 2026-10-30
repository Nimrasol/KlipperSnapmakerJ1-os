Snapmaker J1: install Klipper (KlipperSnapmakerJ1-os)
======================================================

This installs Klipper on a printer that still runs the Snapmaker system.
No EDL and no opening of the printer: everything runs from the USB stick.

Copy the whole contents of this archive to a USB stick (FAT32):
  J1_V*.bin             an update package for the Snapmaker system
  install/              the Klipper system and its installer

1. Plug the stick into the USB port on the front of the printer.
2. On the Snapmaker touch screen, start a firmware update from the USB
   stick (Settings -> About / Firmware update) and confirm.
   - the main controller is updated first (a few minutes)
   - the printer then restarts by itself a few times while it installs
     Klipper.  Leave the stick plugged in and do not switch it off.
     The screen stays dark for up to a minute once, then shows the
     Snapmaker logo and white text while the Klipper system is written.
3. After a few minutes the printer starts Klipper.  Its first start
   installs the Klipper firmware on the main controller (about a minute),
   then the touch screen shows KlipperScreen.

After the main controller update the touch screen shows "Klipper
installation" while the installer starts.  If it reports a failure, or
stays there without restarting the printer, tap "Back to Snapmaker": the
Snapmaker app comes back (it may be an older version; update it again with
an official Snapmaker update package).  Until the printer restarts into the
installer, nothing of the Snapmaker system has been changed.

After the first start, connect the WLAN (More -> Network -> WLAN) and run
the calibrations.
