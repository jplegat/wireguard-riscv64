#!/bin/bash
set -e

# Stub lsiown (linuxserver helper not present in Debian image).
# Use uid/gid 1000 to match the default host user owning the config volume.
lsiown() {
    chown -R 1000:1000 "${@: -1}"
}
export -f lsiown

# Pre-create the s6 container environment directory so init-wireguard-confs/run
# can write USE_COREDNS there without failing
mkdir -p /run/s6/container_environment

# 1. Module check (from init-wireguard-module/run)
bash /etc/s6-overlay/s6-rc.d/init-wireguard-module/run

# 2. Config generation (from init-wireguard-confs/run)
bash /etc/s6-overlay/s6-rc.d/init-wireguard-confs/run

# 3. Tunnel activation (from svc-wireguard/run)
bash /etc/s6-overlay/s6-rc.d/svc-wireguard/run

# CoreDNS is not available on riscv64; ensure it stays disabled
export USE_COREDNS=false

# Keep container alive
tail -f /dev/null
