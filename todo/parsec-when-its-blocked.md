# Parsec when it's blocked

1. Open a terminal on [https://console.cloud.google.com/](https://console.cloud.google.com/)
2.

```bash
docker run -d \
  --name=webtop \
  -e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC \
  -p 8080:3000 -p 3001:3001 \
  -v /path/to/data:/config \
  --shm-size="1gb" \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:ubuntu-xfce-0c4653f4-ls225 && \
docker exec -u root webtop /bin/bash -c "curl -L -o /tmp/parsec.deb https://builds.parsec.app/package/parsec-linux.deb && apt update && apt install -y /tmp/parsec.deb && sudo -u abc DISPLAY=:1 parsecd &"
```

3. On the top right of the terminal, click on previsualize on port 8080
4. Set parsec decoder to Software ( Parsec settings > Client > Decoder > Software )
