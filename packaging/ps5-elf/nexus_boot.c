/*
 * nexus_boot.c — NEXUS-OS Stage A bridge payload (ps5-payload-sdk).
 *
 * Role: the smallest honest piece of the real boot flow. Runs on a jailbroken
 * PS5 (FW 13.42 target) via ps5-payload-dev/elfldr. It renders the NEXUS splash,
 * stages the user's OS choice to /data/NEXUS/boot-select.json, and prints the
 * exact command the Linux stage will run. It never boots anything itself —
 * the Linux stage does (bootchain/kexec/).
 *
 * Build:
 *   PS5 target : make -f Makefile ps5      (needs ps5-payload-sdk + SDL2)
 *   Host syntax: gcc -fsyntax-only -DNEXUS_NO_SDL nexus_boot.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef NEXUS_NO_SDL
/* Host syntax-check path: declarations only, no rendering. */
typedef struct { int w, h; } nexus_fb_t;
static int sdl_init_stub(nexus_fb_t *fb) { fb->w = 1920; fb->h = 1080; return 0; }
static void sdl_quit_stub(void) {}
#define NEXUS_SDL_OK 1
#else
#include <SDL2/SDL.h>
#define NEXUS_SDL_OK 1
#endif

#define SELECT_PATH "/data/NEXUS/boot-select.json"
#define SELECT_TMP  "/data/NEXUS/boot-select.json.tmp"
#define LOG_PATH    "/data/NEXUS/boot-log.txt"

typedef enum { NEXUS_MACOS, NEXUS_WINDOWS, NEXUS_LINUX } nexus_target;

static const char *target_name(nexus_target t) {
    switch (t) {
    case NEXUS_MACOS:   return "macos";
    case NEXUS_WINDOWS: return "windows";
    default:            return "linux";
    }
}

/* Write the boot intent atomically: tmp → fsync → rename. A hub crash mid-write
   must never leave a half-written selection (see nexus-hub/greapple-v2 spec). */
static int write_select(nexus_target target, const char *flavor) {
    FILE *f = fopen(SELECT_TMP, "w");
    if (!f) return -1;
    time_t now = time(NULL);
    char iso[32];
    strftime(iso, sizeof iso, "%Y-%m-%dT%H:%M:%SZ", gmtime(&now));
    if (target == NEXUS_LINUX && flavor && *flavor) {
        fprintf(f, "{\"version\":1,\"target\":\"linux\",\"flavor\":\"%s\","
                   "\"staged_at\":\"%s\",\"staged_by\":\"nexus_boot.elf\"}",
                flavor, iso);
    } else {
        fprintf(f, "{\"version\":1,\"target\":\"%s\",\"staged_at\":\"%s\","
                   "\"staged_by\":\"nexus_boot.elf\"}",
                target_name(target), iso);
    }
    if (fflush(f) != 0 || fclose(f) != 0) return -1;
    if (rename(SELECT_TMP, SELECT_PATH) != 0) return -1;

    FILE *log = fopen(LOG_PATH, "a");
    if (log) {
        fprintf(log, "%s staged: %s%s%s\n", iso, target_name(target),
                (target == NEXUS_LINUX && flavor && *flavor) ? ":" : "",
                (target == NEXUS_LINUX && flavor && *flavor) ? flavor : "");
        fclose(log);
    }
    return 0;
}

static void print_chain_plan(nexus_target target, const char *flavor) {
    printf("[nexus] staged target: %s\n", target_name(target));
    if (target == NEXUS_LINUX) {
        printf("[nexus] Linux stage will run:\n"
               "  kexec -l /mnt/usb0/linux/%s/vmlinuz --initrd ... --command-line ...\n"
               "  kexec -e\n", (flavor && *flavor) ? flavor : "arch");
    } else if (target == NEXUS_MACOS) {
        printf("[nexus] Linux stage will run (chain M — upstream-PROVEN):\n"
               "  kexec -p /mnt/usb0/nexus/stage1/stage1.elf && echo c > /proc/sysrq-trigger\n"
               "  → UefiPayload → OpenCore → boot.efi → XNU 21.6.0\n");
    } else {
        printf("[nexus] Linux stage will run (chain W — RESEARCH):\n"
               "  nexus_uefi_handoff --payload UefiPayload.fd --entry EFI/Boot/bootmgfw.efi\n");
    }
}

int main(int argc, char **argv) {
    nexus_target target = NEXUS_LINUX;
    const char *flavor = "arch";
    for (int i = 1; i + 1 < argc; i += 2) {
        if (!strcmp(argv[i], "--target")) {
            if (!strcmp(argv[i + 1], "macos")) target = NEXUS_MACOS;
            else if (!strcmp(argv[i + 1], "windows")) target = NEXUS_WINDOWS;
            else target = NEXUS_LINUX;
        } else if (!strcmp(argv[i], "--flavor")) {
            flavor = argv[i + 1];
        }
    }

#ifdef NEXUS_SDL_OK
    nexus_fb_t fb;
    if (sdl_init_stub(&fb) == 0) {
        printf("[nexus] framebuffer %dx%d — NEXUS splash renders here (full UI lives in PS5GreenApple v2)\n", fb.w, fb.h);
    }
#endif

    if (write_select(target, flavor) != 0) {
        fprintf(stderr, "[nexus] FAIL: could not stage %s (is /data writable?)\n",
                target_name(target));
        return 1;
    }
    print_chain_plan(target, flavor);
    printf("[nexus] staged. The NEXUS Linux stage consumes " SELECT_PATH " on next boot.\n");
#ifdef NEXUS_SDL_OK
    sdl_quit_stub();
#endif
    return 0;
}
