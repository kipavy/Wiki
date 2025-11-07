# Parsec when it's blocked

1. Open a terminal on [https://console.cloud.google.com/](https://console.cloud.google.com/)
2.

```bash
docker run -d \
  --name=webtop \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -p 8080:3000 \
  -p 3001:3001 \
  -v /path/to/data:/config \
  --shm-size="1gb" \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:ubuntu-xfce
```

3. On the top right of the terminal, click on previsualize on port 8080
4. In the VM, open a terminal:

```
curl -L -o parsec-linux.deb https://builds.parsec.app/package/parsec-linux.deb \
  && sudo apt update \
  && sudo apt install -y ./parsec-linux.deb \
  && sudo dpkg -i ./parsec-linux.deb \
  && parsecd
```

1. Set parsec decoder to Software ( Parsec settings > Client > Decoder > Software )
