#!/bin/bash
set -e

# Check if wg0 config exists
if [ ! -f /etc/wireguard/wg0.conf ]; then
    echo "wg0.conf not found in /etc/wireguard!"
    exit 1
fi

# Check if wg-second-hop config exists
if [ ! -f /etc/wireguard/wg-second-hop.conf ]; then
    echo "wg-second-hop.conf not found in /etc/wireguard!"
    exit 1
fi

# Bring up second hop interface first
# wg-quick up wg-second-hop

# Bring up server (wg0) next
wg-quick up wg0

# Keep container alive
tail -f /dev/null
