#!/bin/bash

# Initial setup for Wireguard

ENV_FILE="/srv/home-server/.env"
WIREGUARD_PORTAL_ADMIN_API_TOKEN=$(grep '^WIREGUARD_PORTAL_ADMIN_API_TOKEN=' "$ENV_FILE" | cut -d '=' -f2-)


# Create default interface (wg0)

INTERFACE_PRIVATE_KEY=$(docker exec -u root wireguard-vpn wg genkey)
INTERFACE_PUBLIC_KEY=$(echo "$INTERFACE_PRIVATE_KEY" | docker exec -i -u root wireguard-vpn wg pubkey)

docker exec -i wireguard-vpn curl -s -X POST \
  -u "admin:$WIREGUARD_PORTAL_ADMIN_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- \
  http://localhost:8888/api/v1/interface/new <<EOF
{
  "Identifier": "wg0",
  "DisplayName": "wg0",
  "Mode": "server",
  "PrivateKey": "$INTERFACE_PRIVATE_KEY",
  "PublicKey": "$INTERFACE_PUBLIC_KEY",
  "Addresses": [
    "10.255.0.2/32"
  ],
  "ListenPort": 51820,
  "PreUp": "iptables -t nat -A POSTROUTING -d 10.8.0.0/24 -j MASQUERADE",
  "PeerDefEndpoint": "49.13.87.41:51820",
  "PeerDefNetwork": [
    "10.255.0.0/24"
  ],
  "PeerDefAllowedIPs": [
    "10.8.0.0/24"
  ]
}
EOF

# Create initial peer for admin

ADMIN_DEFAULT_PEER_PRIVATE_KEY=$(docker exec -u root wireguard-vpn wg genkey)

docker exec -i wireguard-vpn curl -s -X POST \
  -u "admin:$WIREGUARD_PORTAL_ADMIN_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- \
  http://localhost:8888/api/v1/peer/new <<EOF
{
  "Identifier": "admin-default-peer",
  "InterfaceIdentifier": "wg0",
  "PrivateKey": "$ADMIN_DEFAULT_PEER_PRIVATE_KEY"
}
EOF

