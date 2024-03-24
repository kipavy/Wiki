---
description: >-
  Plex Media Server is a software application that allows you to organize and
  stream your collection of movies, TV shows... In short you can have your own
  "Netflix" but better.
---

# Installation

{% hint style="success" %}
You can follow this tutorial if you prefer: [https://github.com/itsToggle/plex\_debrid](https://github.com/itsToggle/plex\_debrid)
{% endhint %}

## Requirements

* A server running linux (e.g Debian) w/ Ethernet (min 1Gbits/s recommended)
* (Optionnal) Smart Plug (If you want to turn on/off your server from anywere + monitor power consumption...)
* 2.99€/month to spend for [https://alldebrid.fr/?uid=3dpui\&lang=fr](https://alldebrid.fr/?uid=3dpui\&lang=fr) (this allows you to have unlimited storage so you can have a poor 120GB SSD on for your server + eliminate need of VPN + Instant availability thanks to caching)

## Mount your debrid services

We need to setup rclone w/ alldebrid so we can have our files on the server without actually storing them on it. See [https://github.com/itsToggle/plex\_debrid?tab=readme-ov-file#1-open\_file\_folder-mount-your-debrid-services](https://github.com/itsToggle/plex\_debrid?tab=readme-ov-file#1-open\_file\_folder-mount-your-debrid-services)

If you're having issues, here is my personnal rclone mouting command:

```bash
rclone mount my-remote:links /home/rdpclient/plexmediaserver/data/rclone --dir-cache-time 10s --allow-other
```

## Setup Plex Media Server

{% hint style="warning" %}
You need to install docker on your server: [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)\
You also need to install docker compose if you don't have it, see [docker](../linux/docker/ "mention")
{% endhint %}

Download this file and edit the path to what you want, if you leave it unchanged, it will create a folder /home/plex and will put everything in it. Note that overseerr[^1], tautulli[^2] and flaresolverr[^3] are optional and can be removed from the compose.

{% file src="../.gitbook/assets/docker-compose.yml" %}

Compose this stack by running this command:

```bash
docker compose up -d
```

You should see something like this:

<figure><img src="../.gitbook/assets/Capture d’écran du 2024-03-24 00-20-12.png" alt=""><figcaption></figcaption></figure>

Open Plex Web UI to start configuration by opening [http://ipaddress:32400/web](http://ipaddress:32400/web) or [localhost:32400/web](https://localhost:32400/web)

## Setup plex\_debrid

See [https://github.com/itsToggle/plex\_debrid?tab=readme-ov-file#3-page\_facing\_up-setup-plex\_debrid](https://github.com/itsToggle/plex\_debrid?tab=readme-ov-file#3-page\_facing\_up-setup-plex\_debrid)

```bash
docker attach plex_debrid  # Then follow instructions
```

## Troobleshooting

If you're having issues with the docker compose, here is a list of the docker run used:

```bash
docker run --name plex_debrid -v /home/rdpclient/plex_debrid/config/:/config --net host -ti --restart unless-stopped --pull=always itstoggle/plex_debrid
  
docker run -d \
  --name=jackett \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -e AUTO_UPDATE=true \
  -p 9117:9117 \
  -v /home/rdpclient/jackett/config/:/config \
  -v /home/rdpclient/jackett/downloads/:/downloads \
  --dns 1.1.1.1 \
  --restart unless-stopped \
  lscr.io/linuxserver/jackett:latest
  
docker run \
-d \
--name plex \
--network=host \
-e TZ=Europe/London \
-v /home/rdpclient/plexmediaserver/config/:/config \
-v /home/rdpclient/plexmediaserver/transcode/:/transcode \
-v /home/rdpclient/plexmediaserver/data/:/data \
--restart unless-stopped \
--pull=always \
lscr.io/linuxserver/plex:latest

docker run -d \
  --name=tautulli \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -p 8181:8181 \
  -v /home/rdpclient/tautulli/config:/config \
  --restart unless-stopped \
  --pull=always \
  lscr.io/linuxserver/tautulli:latest


docker run -d \
  --name=flaresolverr \
  -p 8191:8191 \
  -e LOG_LEVEL=info \
  --restart unless-stopped \
  --pull=always ghcr.io/flaresolverr/flaresolverr:latest

OU
docker run --name flaresolverr --restart unless-stopped --pull=always ngosang/flaresolverr:3.0.0.beta3
OU
docker run --name flaresolverr --restart unless-stopped --pull=always ghcr.io/aeonlucid/flaresolverr:v3beta

docker run -d \
  --name=overseerr \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -p 5055:5055 \
  -v /home/rdpclient/overseerr/config/:/config \
  --restart unless-stopped \
  lscr.io/linuxserver/overseerr:latest
```

[^1]: Provides a clean & modern website for user requests management

[^2]: Provides a monitoring app for your plex

[^3]: Used to bypass some verifications on some sites like ygg
