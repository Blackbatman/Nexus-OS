/* nexfblit.c — NEXUS live-stage framebuffer player.
 *
 * Plays a packed IGNITION animation (.frb, see pack-frames.py) directly on
 * the Linux framebuffer. This is the QEMU-stage delivery surface of the
 * NEXUS Metro IGNITION boot animation (docs/14); on an installed system the
 * same 48 frames are driven by Plymouth (nexus-hub/plasma/boot-splash/).
 *
 *   nexfblit <file.frb> [--fps 10] [--loop 1] [--clear-color RRGGBB]
 *
 *   --fps N        frames per second (default 10)
 *   --loop N       repeat count, 0 = forever (default 1)
 *   --clear-color  hex RRGGBB used to wipe the screen between plays
 *                  (default 070B18 = docs/14 deep-space)
 *
 * Supports 16 (565), 24 and 32 bpp framebuffers via fb_get layout.
 * Exit codes: 0 played, 1 no framebuffer, 2 bad pack. Print nothing on
 * success (console cleanliness); errors go to stderr.
 *
 * Build (host or in-initramfs): cc -O2 -static -o nexfblit nexfblit.c
 * Test on host syntax only:     cc -fsyntax-only -Wall nexfblit.c
 */
#include <errno.h>
#include <fcntl.h>
#include <linux/fb.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

#define NXFB_MAGIC "NXFB"

typedef struct {
    int fd;
    unsigned char *mem;
    size_t mem_size;
    int w, h;                    /* screen */
    int bpp;                     /* bits per pixel */
    int ro, go, bo;              /* color bit offsets */
    int rl, gl, bl;              /* color bit lengths */
    long line;
} fb_t;

static int fb_open(fb_t *f, const char *dev)
{
    struct fb_var_screeninfo v;
    struct fb_fix_screeninfo s;

    f->fd = open(dev, O_RDWR);
    if (f->fd < 0)
        return -1;
    if (ioctl(f->fd, FBIOGET_VSCREENINFO, &v) < 0 ||
        ioctl(f->fd, FBIOGET_FSCREENINFO, &s) < 0) {
        close(f->fd);
        return -1;
    }
    f->w = (int)v.xres;
    f->h = (int)v.yres;
    f->bpp = (int)v.bits_per_pixel;
    f->ro = v.red.offset;   f->rl = v.red.length;
    f->go = v.green.offset; f->gl = v.green.length;
    f->bo = v.blue.offset;  f->bl = v.blue.length;
    f->line = (long)s.line_length;
    if (f->line == 0)
        f->line = (long)f->w * ((f->bpp + 7) / 8);
    f->mem_size = (size_t)f->line * (size_t)f->h;
    f->mem = mmap(NULL, f->mem_size, PROT_READ | PROT_WRITE, MAP_SHARED, f->fd, 0);
    if (f->mem == MAP_FAILED) {
        close(f->fd);
        return -1;
    }
    return 0;
}

static void fb_close(fb_t *f)
{
    munmap(f->mem, f->mem_size);
    close(f->fd);
}

static inline uint32_t pack_color(const fb_t *f, uint8_t r, uint8_t g, uint8_t b)
{
    uint32_t v = 0;
    if (f->rl >= 8) v |= (uint32_t)r << f->ro; else v |= (uint32_t)(r >> (8 - f->rl)) << f->ro;
    if (f->gl >= 8) v |= (uint32_t)g << f->go; else v |= (uint32_t)(g >> (8 - f->gl)) << f->go;
    if (f->bl >= 8) v |= (uint32_t)b << f->bo; else v |= (uint32_t)(b >> (8 - f->bl)) << f->bo;
    return v;
}

static void fb_clear(const fb_t *f, uint8_t r, uint8_t g, uint8_t b)
{
    uint32_t v = pack_color(f, r, g, b);
    int bytes = f->bpp / 8;
    int x, y;
    for (y = 0; y < f->h; y++) {
        unsigned char *row = f->mem + (size_t)y * f->line;
        if (bytes == 4) {
            uint32_t *p = (uint32_t *)(void *)row;
            for (x = 0; x < f->w; x++) p[x] = v;
        } else if (bytes == 2) {
            uint16_t *p = (uint16_t *)(void *)row;
            for (x = 0; x < f->w; x++) p[x] = (uint16_t)v;
        } else {
            for (x = 0; x < f->w; x++)
                memcpy(row + (size_t)x * bytes, &v, (size_t)bytes);
        }
    }
}

static void fb_blit_center(const fb_t *f, int fw, int fh, const unsigned char *px)
{
    /* px: fw*fh RGB565 little-endian; blit centered, clipped, no scaling */
    int ox = (f->w - fw) / 2, oy = (f->h - fh) / 2;
    int y, x;
    for (y = 0; y < fh; y++) {
        int sy = oy + y;
        if (sy < 0 || sy >= f->h)
            continue;
        unsigned char *row = f->mem + (size_t)sy * f->line;
        for (x = 0; x < fw; x++) {
            int sx = ox + x;
            if (sx < 0 || sx >= f->w)
                continue;
            const unsigned char *s = px + 2 * ((size_t)y * fw + x);
            uint32_t r5 = (uint32_t)s[1] >> 3;
            uint32_t g6 = (((uint32_t)s[1] & 0x07) << 3) | ((uint32_t)s[0] >> 5);
            uint32_t b5 = (uint32_t)s[0] & 0x1F;
            uint8_t r = (uint8_t)((r5 << 3) | (r5 >> 2));
            uint8_t g = (uint8_t)((g6 << 2) | (g6 >> 4));
            uint8_t b = (uint8_t)((b5 << 3) | (b5 >> 2));
            uint32_t v = pack_color(f, r, g, b);
            int bytes = f->bpp / 8;
            if (bytes == 4)
                *(uint32_t *)(void *)(row + (size_t)sx * 4) = v;
            else if (bytes == 2)
                *(uint16_t *)(void *)(row + (size_t)sx * 2) = (uint16_t)v;
            else
                memcpy(row + (size_t)sx * bytes, &v, (size_t)bytes);
        }
    }
}

static void msleep(long ms)
{
    struct timespec ts = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&ts, NULL);
}

int main(int argc, char **argv)
{
    const char *pack = NULL, *dev = "/dev/fb0";
    int fps = 10, loops = 1;
    uint8_t cr = 0x07, cg = 0x0B, cb = 0x18;   /* deep-space 070B18 */
    int i;

    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--fps") && i + 1 < argc) fps = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--loop") && i + 1 < argc) loops = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--dev") && i + 1 < argc) dev = argv[++i];
        else if (!strcmp(argv[i], "--clear-color") && i + 1 < argc) {
            unsigned long v = strtoul(argv[++i], NULL, 16);
            cr = (uint8_t)(v >> 16); cg = (uint8_t)(v >> 8); cb = (uint8_t)v;
        }
        else if (argv[i][0] != '-') pack = argv[i];
    }
    if (!pack || fps <= 0) {
        fprintf(stderr, "usage: nexfblit <file.frb> [--fps N] [--loop N] [--dev /dev/fb0] [--clear-color RRGGBB]\n");
        return 2;
    }

    FILE *fp = fopen(pack, "rb");
    if (!fp) {
        fprintf(stderr, "nexfblit: cannot open %s: %s\n", pack, strerror(errno));
        return 2;
    }
    unsigned char hdr[14];
    if (fread(hdr, 1, 14, fp) != 14 || memcmp(hdr, NXFB_MAGIC, 4) != 0 || hdr[5] != 1) {
        fprintf(stderr, "nexfblit: %s is not an NXFB v1 RGB565 pack\n", pack);
        fclose(fp);
        return 2;
    }
    int count = hdr[6] | (hdr[7] << 8);
    int fw = hdr[8] | (hdr[9] << 8);
    int fh = hdr[10] | (hdr[11] << 8);
    if (count <= 0 || fw <= 0 || fh <= 0 || (long)fw * fh > (1L << 24)) {
        fprintf(stderr, "nexfblit: bad pack geometry %dx%dx%d\n", fw, fh, count);
        fclose(fp);
        return 2;
    }
    size_t fsz = (size_t)fw * fh * 2;
    unsigned char *px = malloc(fsz);
    if (!px) {
        fclose(fp);
        return 2;
    }

    fb_t fb;
    if (fb_open(&fb, dev) != 0) {
        fprintf(stderr, "nexfblit: cannot open framebuffer %s\n", dev);
        free(px);
        fclose(fp);
        return 1;
    }

    long frame_ms = 1000L / fps;
    for (i = 0; i < (loops == 0 ? 0x7FFFFFFF : loops) && 1; i++) {
        int n;
        fb_clear(&fb, cr, cg, cb);
        for (n = 0; n < count; n++) {
            if (fread(px, 1, fsz, fp) != fsz) {
                fseek(fp, 14, SEEK_SET);   /* restart pack on short read */
                if (fread(px, 1, fsz, fp) != fsz)
                    break;
            }
            fb_blit_center(&fb, fw, fh, px);
            msleep(frame_ms);
        }
        if (loops != 0 && i + 1 >= loops)
            break;
        fseek(fp, 14, SEEK_SET);
    }
    fb_clear(&fb, cr, cg, cb);
    free(px);
    fclose(fp);
    fb_close(&fb);
    return 0;
}
