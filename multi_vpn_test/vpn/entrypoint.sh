#!/bin/bash
set -e

# Check if config exists
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "WireGuard configuration not found in /etc/wireguard!"
    exit 1
fi

# Bring up WireGuard interface
wg-quick up wg0

# Keep container alive
tail -f /dev/null
