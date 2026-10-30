Snapmaker J1: back to the Snapmaker firmware
=============================================

Copy the contents of this archive to a USB stick (FAT32):
  J1_V*.bin        official Snapmaker update package
                   (main controller firmware)
  stock-restore/   the Snapmaker system of the display module
                   (Android, app V2.8.0) with checksums

!!! THIS TAKES A WHILE: ABOUT 3 MINUTES. DO NOT PULL THE USB STICK
!!! AND DO NOT SWITCH THE PRINTER OFF UNTIL THE SNAPMAKER SETUP APPEARS.
The printer restarts by itself on the way; that is normal.

1. Plug the stick into the USB port on the front of the printer.
2. On the touch screen: More -> System, scroll to the end and tap
   Stock Firmware.
   The page shows the package and the system found on the stick.
3. Tap "Restore Stock Firmware" and confirm.
   Leave the stick plugged in and do not switch the printer off.
   - the main controller gets the Snapmaker firmware (1-3 minutes)
   - the printer restarts into the maintenance system, which checks
     the files and writes the Snapmaker system (a few minutes)
   - the printer starts with the Snapmaker system
4. The Snapmaker setup starts as on a new printer: language, WLAN and
   the calibrations (leveling, Z and XY offset); finish it before
   printing.
