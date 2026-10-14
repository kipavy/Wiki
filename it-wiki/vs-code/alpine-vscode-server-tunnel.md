---
description: >-
  Starts a VSCode Server that can be used with
  https://marketplace.visualstudio.com/items?itemName=ms-vscode.remote-server
  extension
---

# Alpine Vscode Server Tunnel

### Prerequisites:

* Install alpine + create normal user "alpine"

```bash
# adds community repo
cat > /etc/apk/repositories << EOF; $(echo)

https://dl-cdn.alpinelinux.org/alpine/v$(cut -d'.' -f1,2 /etc/alpine-release)/main/
https://dl-cdn.alpinelinux.org/alpine/v$(cut -d'.' -f1,2 /etc/alpine-release)/community/
https://dl-cdn.alpinelinux.org/alpine/edge/testing/

EOF

apk update
apk upgrade
apk add curl git
apk add alpine-sdk bash libstdc++ libc6-compat


cd /home/alpine
curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz
tar -xf vscode_cli.tar.gz
./code tunnel

https://wiki.alpinelinux.org/wiki/Docker
apk add docker docker-cli-compose

mkdir -p /etc/init.d
# Commande user root so that terminal are root by default in vscode to run docker easily
cat <<EOF >file
#!/sbin/openrc-run

name="code-tunnel"
command="/home/alpine/code"
command_args="tunnel"
command_user="root"
pidfile="/var/run/${RC_SVCNAME}.pid"
logfile="/var/log/${RC_SVCNAME}.log"

depend() {
    need net
}
EOF

chmod +x /etc/init.d/code-tunnel
rc-update add docker boot
rc-update add code-tunnel default
service docker start
rc-service code-tunnel start

```
