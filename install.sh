#!/usr/bin/env bash
# ------------------------------------------------------------------
# setup-zram.sh — cleanly configure ZRAM on openSUSE using systemd-zram-generator
# Author: Zakaria Farhati + ChatGPT ofc
# ------------------------------------------------------------------

set -e

# ====== Configuration ======
ZRAM_SIZE="ram*0.75"          # 75% of your RAM
COMPRESSION_ALGO="zstd"       # best balance for Intel i5 5th gen
PRIORITY="100"

# ====== Package installation ======
echo "[+] Installing required packages..."
sudo zypper --non-interactive install \
    systemd-zram-service \
    zram-generator \
    util-linux-systemd >/dev/null 2>&1 || {
        echo "[!] Failed to install required packages!"
        exit 1
    }

# ====== Stop any old services ======
echo "[+] Stopping any existing ZRAM services..."
sudo systemctl stop systemd-zram-setup@zram0.service 2>/dev/null || true
sudo systemctl stop zramswap.service 2>/dev/null || true

# ====== Reset existing zram device ======
if [[ -e /sys/block/zram0/reset ]]; then
    echo "[+] Resetting existing /dev/zram0..."
    echo 1 | sudo tee /sys/block/zram0/reset >/dev/null
fi

# ====== Reload zram module ======
echo "[+] Reloading zram kernel module..."
sudo rmmod zram 2>/dev/null || true
sudo modprobe zram

# ====== Write configuration ======
echo "[+] Writing /etc/systemd/zram-generator.conf..."
sudo tee /etc/systemd/zram-generator.conf >/dev/null <<EOF
[zram0]
zram-size = ${ZRAM_SIZE}
compression-algorithm = ${COMPRESSION_ALGO}
swap-priority = ${PRIORITY}
EOF

# ====== Reload and restart service ======
echo "[+] Reloading systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "[+] Starting ZRAM service..."
if ! sudo systemctl restart systemd-zram-setup@zram0.service; then
    echo "[!] Failed to start ZRAM service — check logs with:"
    echo "    sudo systemctl status systemd-zram-setup@zram0.service -n 20"
    exit 1
fi

# ====== Display final status ======
echo
echo "✅ ZRAM configuration complete!"
echo
echo "ZRAM info:"
sudo zramctl || echo "zramctl not found"
echo
echo "Swap info:"
sudo swapon --show || echo "No active swap found"
