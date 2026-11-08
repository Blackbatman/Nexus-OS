# Install guide — FTP (network delivery to the PS5)

The proven scene pipeline uses John Törnblom's `ps5-payload-dev` tooling:

| Tool | Port | Role |
| --- | --- | --- |
| `ps5-payload-dev/elfldr` | **9021** | receives and runs `.elf` payloads on the jailbroken PS5 |
| `ps5-payload-dev/ftpsrv` | **2121** | file transfer to/from the console (`/data`, `/mnt/usb0`) |

## Flow

```bash
# 0) jailbreak entry (operator-run — APPROVAL GATE)
#    per firmware: FW 7.00-13.60 Relapse-Exploit · 13.20/13.60 optional Byepervisor-Reborn HV
#    FW <= 12.00 era PPPwn-family · FW 14.x: no public entry (docs/09-firmware-coverage.md)
#    → launch elfldr on the console

# 1) upload the payload
curl -T packaging/ps5-elf/build/nexus_boot.elf ftp://<PS5_IP>:2121/data/homebrew/

# 2) run it (elfldr accepts payloads on port 9021)
socat - TCP:<PS5_IP>:9021 < packaging/ps5-elf/build/nexus_boot.elf

# 3) pull logs / push chain artifacts
curl ftp://<PS5_IP>:2121/data/NEXUS/boot-log.txt
curl -T bootchain/stage1/stage1.elf ftp://<PS5_IP>:2121/mnt/usb0/nexus/stage1/
```

## Makefile shortcut

```bash
make -C packaging/ps5-elf deploy PS5_HOST=192.168.1.50 PS5_PORT=9021
```

## Safety

- All transfers are to storage you laid out (`usb.md` § PS5 boot USB).
- Nothing here touches the console's internal SSD (upstream policy: locked).
- The gate philosophy extends to the network: the PS5 payload only talks to
  your LAN; it initiates nothing else.
