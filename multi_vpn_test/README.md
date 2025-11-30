# Multi-Hop VPN Setup with WireGuard

This setup creates a multi-hop VPN where:
1. Peers connect to `wg0` (your server on port 51820)
2. All traffic from `wg0` peers is routed through `wg-second-hop` (Proton VPN)

## Architecture

```
Peer → wg0 (10.255.0.0/24) → wg-second-hop (Proton VPN) → Internet
```

## Configuration Files

### wg0.conf
- **Interface**: Your server interface that peers connect to
- **Network**: 10.255.0.0/24
- **Port**: 51820
- **Peers**: Add your peer configurations here

### wg-second-hop.conf
- **Interface**: Proton VPN connection
- **Network**: 10.2.0.2/32 (assigned by Proton VPN)
- **Routing**: All traffic (0.0.0.0/0, ::/0) goes through Proton VPN

## How It Works

The `entrypoint.sh` script:

1. **Brings up wg-second-hop first** - Establishes connection to Proton VPN
2. **Configures routing** - Creates a custom routing table (200) that routes all traffic from wg0 peers (10.255.0.0/24) through wg-second-hop
3. **Sets up NAT/Masquerading** - Makes traffic from wg0 peers appear to come from wg-second-hop
4. **Configures iptables** - Allows forwarding between wg0 and wg-second-hop
5. **Brings up wg0** - Starts the server interface

## Setup Instructions

1. **Copy your config files** to `/srv/docker_data/vpn_test/`:
   ```bash
   cp wg0.conf /srv/docker_data/vpn_test/
   cp wg-second-hop.conf /srv/docker_data/vpn_test/
   ```

2. **Ensure your config files are named correctly**:
   - `wg0.conf` - Server interface
   - `wg-second-hop.conf` - Proton VPN interface

3. **Start the container**:
   ```bash
   cd multi_vpn_test
   docker-compose up -d
   ```

4. **Check logs**:
   ```bash
   docker logs vpn
   ```

## Testing

1. **Connect a peer** to wg0 using the peer configuration
2. **Check routing** on the server:
   ```bash
   docker exec vpn ip route show table 200
   docker exec vpn iptables -t nat -L POSTROUTING -v
   ```
3. **Test connectivity** from the peer - all traffic should go through Proton VPN

## Troubleshooting

### Traffic not routing through second hop
- Check that wg-second-hop is up: `docker exec vpn wg show`
- Verify routing table: `docker exec vpn ip route show table 200`
- Check iptables rules: `docker exec vpn iptables -t nat -L -v`

### Peer can't connect
- Verify wg0 is listening: `docker exec vpn wg show wg0`
- Check firewall rules on host (port 51820/udp must be open)
- Verify peer configuration matches wg0.conf

### DNS issues
- wg-second-hop.conf includes DNS = 10.2.0.1 (Proton VPN DNS)
- Peers should use this DNS or configure their own

## Network Details

- **wg0 network**: 10.255.0.0/24
  - Server: 10.255.0.1
  - Peers: 10.255.0.2, 10.255.0.3, etc.
  
- **wg-second-hop network**: 10.2.0.2/32 (assigned by Proton VPN)

## Security Notes

- Keep your private keys secure
- Use strong peer public keys
- Consider firewall rules to restrict access
- Monitor logs for suspicious activity
