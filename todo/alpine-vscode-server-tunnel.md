# Alpine Vscode Server Tunnel

```bash
# Install alpine
# add community repo
apk update
apk upgrade
apk add curl git
apk add alpine-sdk bash libstdc++ libc6-compat
curl -Lk 'https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-x64' --output vscode_cli.tar.gz
tar -xf vscode_cli.tar.gz
./code tunnel

https://wiki.alpinelinux.org/wiki/Docker
apk add docker docker-cli-compose
```
