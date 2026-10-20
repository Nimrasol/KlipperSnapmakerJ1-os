// Periodically pan the framebuffer so that the MDSS display shows it
//
// Copyright (C) 2026  Nimrasol
//
// This file may be distributed under the terms of the GNU GPLv3 license.
//
// The Qualcomm MDSS framebuffer driver of the stock kernel only sends new
// content to the panel on FBIOPAN_DISPLAY.  X (fbdev driver) draws into
// the framebuffer memory without panning, so this tool pans at a fixed
// rate.  Usage: fb-refresher [/dev/fb0] [rate in Hz]

#include <fcntl.h>
#include <linux/fb.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

int
main(int argc, char **argv)
{
    const char *path = argc > 1 ? argv[1] : "/dev/fb0";
    int rate = argc > 2 ? atoi(argv[2]) : 30;
    if (rate < 1)
        rate = 1;
    int fd = open(path, O_RDWR);
    if (fd < 0) {
        perror(path);
        return 1;
    }
    struct fb_var_screeninfo var;
    if (ioctl(fd, FBIOGET_VSCREENINFO, &var) < 0) {
        perror("FBIOGET_VSCREENINFO");
        return 1;
    }
    struct timespec delay = { 0, 1000000000L / rate };
    for (;;) {
        // Errors are expected while the panel is blanked; keep trying
        ioctl(fd, FBIOPAN_DISPLAY, &var);
        nanosleep(&delay, NULL);
    }
}
