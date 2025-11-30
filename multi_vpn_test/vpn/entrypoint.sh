#!/bin/bash
set -e

# Check if wg0 config exists
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "wg0.conf not found in /etc/wireguard!"
    exit 1
fi

# Bring up server (wg0) next
wg-quick up wg0

# Keep container alive
tail -f /dev/null
