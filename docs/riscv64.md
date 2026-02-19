---
layout: default
title: RISC-V 64 WireGuard
nav_order: 1
permalink: /riscv64
---

# WireGuard on RISC-V 64
{: .no_toc }

This guide covers building, updating, and running the WireGuard Docker image on a RISC-V 64-bit SBC (tested on Ubuntu 24.04 LTS).
{: .fs-6 .fw-300 }

---

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## Prerequisites

- Docker installed on the RISC-V SBC
- Docker with `buildx` and QEMU support installed on your build machine (x86-64 or ARM)
- The WireGuard kernel module available on the SBC host:

```bash
sudo modprobe wireguard
lsmod | grep wireguard
```

---

## Building the image

Run this on your **build machine** (cross-compiling for `linux/riscv64` via QEMU):

```bash
docker buildx build \
  --platform linux/riscv64 \
  -f Dockerfile.riscv64 \
  -t wireguard:riscv64-test .
```

### Transferring the image to the SBC

```bash
# On the build machine — export the image
docker save wireguard:riscv64-test | gzip > wireguard-riscv64.tar.gz

# Transfer to the SBC
scp wireguard-riscv64.tar.gz ubuntu@your-sbc-ip:~

# On the SBC — load the image
docker load < wireguard-riscv64.tar.gz
```

---

## Updating the image

After making changes to `Dockerfile.riscv64`, `root/entrypoint-riscv64.sh`, or any file under `root/`:

```bash
# Rebuild
docker buildx build \
  --no-cache \
  --platform linux/riscv64 \
  -f Dockerfile.riscv64 \
  -t wireguard:riscv64-test .

# Re-export and transfer
docker save wireguard:riscv64-test | gzip > wireguard-riscv64.tar.gz
scp wireguard-riscv64.tar.gz ubuntu@your-sbc-ip:~

# On the SBC — stop the stack, reload, restart
docker compose -f docker-compose.riscv64.yml down
docker load < wireguard-riscv64.tar.gz
docker compose -f docker-compose.riscv64.yml up -d
```

---

## Running the container

### docker-compose.riscv64.yml

```yaml
services:
  wireguard:
    image: wireguard:riscv64-test
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - TZ=America/Los_Angeles
      - SERVERURL=spikespiegel.hopto.org
      - SERVERPORT=51822
      - PEERS=5
      - PEERDNS=1.1.1.1
      - INTERNAL_SUBNET=10.13.13.0
      - ALLOWEDIPS=0.0.0.0/0
    volumes:
      - /home/ubuntu/wireguard-server/config:/config
      - /lib/modules:/lib/modules
    ports:
      - 51822:51820/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
    restart: unless-stopped
```

### Starting the stack

```bash
# Foreground (recommended for first run — lets you see logs)
docker compose -f docker-compose.riscv64.yml up

# Background
docker compose -f docker-compose.riscv64.yml up -d
```

### Stopping the stack

```bash
docker compose -f docker-compose.riscv64.yml down
```

### Viewing logs

```bash
docker logs -f wireguard
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `TZ` | — | Timezone (e.g. `America/Los_Angeles`) |
| `SERVERURL` | — | External hostname or IP advertised to peers |
| `SERVERPORT` | `51820` | External UDP port (must match router port forward) |
| `PEERS` | — | Number of peer configs to generate |
| `PEERDNS` | — | DNS server pushed to peers. CoreDNS is unavailable on riscv64 — use an explicit IP (e.g. `1.1.1.1`) |
| `INTERNAL_SUBNET` | `10.13.13.0` | VPN subnet |
| `ALLOWEDIPS` | `0.0.0.0/0` | Allowed IPs in peer configs (controls split tunneling) |

---

## Displaying peer QR codes

Use the built-in `show-peer` utility. Pass the **peer number**, not the peer name:

```bash
# Show QR code for peer 1
docker exec wireguard bash /app/show-peer 1

# Show QR code for peer 2
docker exec wireguard bash /app/show-peer 2
```

Peer configs and pre-rendered PNG QR codes are also saved on the host at:

```
/home/ubuntu/wireguard-server/config/peer1/peer1.conf
/home/ubuntu/wireguard-server/config/peer1/peer1.png
```

To copy a PNG to your local machine for scanning:

```bash
scp ubuntu@your-sbc-ip:/home/ubuntu/wireguard-server/config/peer1/peer1.png ~/Desktop/peer1.png
```

---

## Verifying the tunnel

```bash
# Check WireGuard interface status
docker exec wireguard wg show

# Confirm the container is listening on the correct port
ss -ulnp | grep 51820
```

---

## Architecture notes

| | Alpine images | riscv64 image |
|---|---|---|
| Base image | `ghcr.io/linuxserver/baseimage-alpine:3.23` | `debian:trixie-slim` |
| Init system | s6-overlay | Bash entrypoint (`/entrypoint-riscv64.sh`) |
| CoreDNS | Included | Not available — `USE_COREDNS` is hardcoded to `false` |
| User switching | `abc` (uid 1000) via s6 | Runs as root; config volume chowned to uid 1000 |
