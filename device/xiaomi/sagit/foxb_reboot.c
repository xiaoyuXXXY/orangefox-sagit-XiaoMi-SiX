/*
 * foxb_reboot - direct-syscall reboot for OrangeFox sagit recovery.
 *
 * The AOSP /system/bin/reboot sets the sys.powerctl property and relies on
 * init's property service + shutdown path. Inside zip installer scripts that
 * path can stall (the setter blocks waiting for the property service).
 * This tool issues the reboot(2) syscall directly - the same thing busybox
 * reboot did in old recoveries - so it works from any script context.
 *
 * Usage: foxb_reboot [-p|-f|now|recovery|bootloader|download|edl|fastboot|hard|warm|cold]
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <linux/reboot.h>

static const char *MODES[] = {
    "recovery", "bootloader", "download", "edl",
    "fastboot", "hard", "warm", "cold", NULL
};

int main(int argc, char **argv) {
    long cmd = LINUX_REBOOT_CMD_RESTART;
    const char *arg = NULL;
    int i, j, known;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-p") == 0) {
            cmd = LINUX_REBOOT_CMD_POWER_OFF;
        } else if (strcmp(argv[i], "-f") == 0 || strcmp(argv[i], "now") == 0) {
            /* -f (force) and "now" are no-ops for the direct syscall */
            continue;
        } else {
            known = 0;
            for (j = 0; MODES[j]; j++) {
                if (strcmp(argv[i], MODES[j]) == 0) {
                    cmd = LINUX_REBOOT_CMD_RESTART2;
                    arg = argv[i];
                    known = 1;
                    break;
                }
            }
            if (!known) {
                fprintf(stderr, "foxb_reboot: unknown arg '%s', treating as plain reboot\n", argv[i]);
            }
        }
    }

    sync();
    sync();

    if (syscall(__NR_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
                cmd, arg) != 0) {
        fprintf(stderr, "foxb_reboot: reboot syscall failed: %s\n",
                strerror(errno));
        return 1;
    }

    /* unreachable if the syscall succeeded */
    return 0;
}
