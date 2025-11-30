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

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1

# Function to cleanup on exit
cleanup() {
    echo "Cleaning up..."
    # Try to find the second hop interface
    local cleanup_if=$(ip -o -4 addr show | grep -E '10\.2\.0\.' | awk '{print $2}' | head -n1)
    if [ -z "$cleanup_if" ]; then
        cleanup_if="wg-second-hop"
    fi
    
    # Remove iptables rules
    iptables -t nat -D POSTROUTING -s 10.255.0.0/24 -o "$cleanup_if" -j MASQUERADE 2>/dev/null || true
    ip6tables -t nat -D POSTROUTING -s 10.255.0.0/24 -o "$cleanup_if" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i wg0 -o "$cleanup_if" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "$cleanup_if" -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    # Remove routing rules
    ip rule del from 10.255.0.0/24 table 200 2>/dev/null || true
    # Bring down interfaces
    wg-quick down wg0 2>/dev/null || true
    wg-quick down wg-second-hop 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# Bring up second hop interface first (Proton VPN)
echo "Bringing up wg-second-hop (Proton VPN)..."
wg-quick up wg-second-hop

# Wait a moment for the interface to stabilize
sleep 2

# Get the actual interface name (might be wg-second-hop or something else)
SECOND_HOP_IF=$(ip -o -4 addr show | grep -E '10\.2\.0\.' | awk '{print $2}' | head -n1)
if [ -z "$SECOND_HOP_IF" ]; then
    SECOND_HOP_IF="wg-second-hop"
fi

echo "Second hop interface: $SECOND_HOP_IF"

# Set up routing: route traffic from wg0 peers through wg-second-hop
# This ensures all traffic from wg0 peers goes through the second hop
ip route add default dev "$SECOND_HOP_IF" table 200 2>/dev/null || true
ip rule add from 10.255.0.0/24 table 200 2>/dev/null || true

# Set up NAT/masquerading so traffic from wg0 peers appears to come from wg-second-hop
iptables -t nat -A POSTROUTING -s 10.255.0.0/24 -o "$SECOND_HOP_IF" -j MASQUERADE
ip6tables -t nat -A POSTROUTING -s 10.255.0.0/24 -o "$SECOND_HOP_IF" -j MASQUERADE 2>/dev/null || true

# Allow forwarding between wg0 and wg-second-hop
iptables -A FORWARD -i wg0 -o "$SECOND_HOP_IF" -j ACCEPT
iptables -A FORWARD -i "$SECOND_HOP_IF" -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Bring up server (wg0) next
echo "Bringing up wg0 (server interface)..."
wg-quick up wg0

echo "Multi-hop VPN setup complete!"
echo "wg0 peers can now connect and their traffic will be routed through wg-second-hop (Proton VPN)"

# Keep container alive
tail -f /dev/null
