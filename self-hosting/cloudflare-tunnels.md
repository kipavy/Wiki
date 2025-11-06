# Cloudflare Tunnels

1. Insall cloudflared https://community-scripts.github.io/ProxmoxVE/scripts?id=cloudflared
2. &#x20;Log in to cloudflare account:

```
# NOTE TO ME TODO:
 either use cloudflared tunnel login if its straight forward
 or
 CF_ACCOUNT_ID= Click on the domain name, scroll down and copy Account ID
 CF_API_TOKEN=  https://dash.cloudflare.com/profile/api-tokens > Create Token > "Zero Trust Tunnel" > Ensure Account | Cloudflare Tunnel | Edit.

and add --account-id "$CF_ACCOUNT_ID" to command
```

3. Edit services and paste this:

```bash
TUNNEL_NAME="lxc-gateway"
TUNNEL_UUID=$(cloudflared tunnel create "$TUNNEL_NAME" --json | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')

cat > /usr/local/etc/cloudflared/config.yml <<EOF
tunnel: $TUNNEL_UUID
credentials-file: /root/.cloudflared/$TUNNEL_UUID.json
ingress:
  - hostname: app1.yourcustomdomain.com
    service: http://10.0.3.10:80

  - hostname: app2.yourcustomdomain.com
    service: http://10.0.3.11:8080
    
  - service: http_status:404
EOF
```

4. Cloudflare Zero Trust Dashboard -> Access -> Tunnels -> Add Public Hostnames
5.

```bash
# might already be setup in helper script lxc
sudo cloudflared service install --config /etc/cloudflared/config.yml
sudo systemctl enable --now cloudflared.service
```
