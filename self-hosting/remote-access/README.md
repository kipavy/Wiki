# Remote Access

| Tailscale (ZTNA/VPN Mesh)            | Private Network (Peer-to-Peer VPN) | Zero-config WireGuard VPN, NAT traversal.                                                        | Securely accessing management/internal services (SSH, RDP) for a defined group of users/devices.          |
| ------------------------------------ | ---------------------------------- | ------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------- |
| Cloudflare Tunnels (ZTNA/Tunnel)     | Outbound Tunnel to Public Cloud    | Exposing services without opening ports on your firewall; integrated Zero Trust access controls. | Exposing web services publicly or to authenticated users (Zero Trust), even behind CGNAT.                 |
| Reverse Proxy (e.g., Nginx, Traefik) | Publicly Exposed Gateway           | Centralized routing, SSL termination, and caching for web traffic.                               | Publicly exposing multiple web services on a single port/IP (requires a public IP or Cloudflare Tunnels). |
