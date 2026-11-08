# Install guide — USB (live USB for all targets)

## Linux flavor (NEXUS-OS live ISO)

```bash
# find your device (assume /dev/sdX — double-check!)
lsblk -o NAME,SIZE,MODEL

# write it (destroys the stick — this is the one destructive step in this repo)
dd if=NEXUS-OS.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Or use Ventoy (keeps the stick multi-ISO — handy with the Windows target):

```bash
ventoy -i /dev/sdX && cp NEXUS-OS.iso /mnt/ventoy/
```

## Windows target

`packaging/windows-media/make-windows-media.sh` produces `NEXUS-Windows.iso`
from **your own licensed media**; write it the same way, or drop the original
ISO onto a Ventoy stick and keep the NEXUS notes next to it.

## PS5 boot USB (the Linux stage USB)

The PS5 chains read from a USB stick laid out like this:

```
/mnt/usb0
├── linux/<flavor>/vmlinuz + initrd      # PS5-built kernels (8 flavors)
├── nexus/stage1/stage1.elf              # built via bootchain/stage1
├── nexus/uefi/UefiPayload.fd            # built via bootchain/stage1 + EDK2
└── data/NEXUS/boot-select.json          # written by the hub (Stage A)
```

Safe steps (no destructive ops on the console side):

1. `packaging/build.sh ps5` on a host with ps5-payload-sdk → `nexus_boot.elf`
2. Deploy: see `ftp.md` (elfldr :9021, ftpsrv :2121)
3. Verify with dry-runs first:
   ```bash
   bootchain/kexec/nexus-boot-select.sh --dry-run --select /path/boot-select.json
   ```
