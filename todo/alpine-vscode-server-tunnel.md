# Alpine Vscode Server Tunnel

```bash
# Install alpine + create alpine normal user
# add community repo
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
cat <<EOF >file
#!/sbin/openrc-run

name="code-tunnel"
command="/home/alpine/code"
command_args="tunnel"
command_user="alpine"
pidfile="/var/run/${RC_SVCNAME}.pid"
logfile="/var/log/${RC_SVCNAME}.log"

depend() {
    need net
}
EOF

chmod +x /etc/init.d/code-tunnel
rc-update add code-tunnel default
rc-service code-tunnel start

```
