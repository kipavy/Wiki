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

## Setup

{% hint style="warning" %}
You need to install docker on your server: [https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)\
You also need to install docker compose if you don't have it, see [docker](../linux/docker/ "mention")
{% endhint %}

Download this file and edit the path to what you want, if you leave it unchanged, it will create a folder /home/plex and will put everything in it.

{% file src="../.gitbook/assets/docker-compose.yml" %}

Compose this stack by running this command:

```bash
docker compose up -d
```

You should see something like this:

<figure><img src="../.gitbook/assets/Capture d’écran du 2024-03-24 00-20-12.png" alt=""><figcaption></figcaption></figure>

