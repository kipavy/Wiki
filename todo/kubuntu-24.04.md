---
description: Update, remove & block snap completely + install flatpak for Discover store
---

# Kubuntu 24.04

{% hint style="warning" %}
This will delete all of your snap apps
{% endhint %}

1. <mark style="color:red;">`sudo apt update && sudo apt full-upgrade`</mark>
2. Reboot
3. [https://gitlab.com/scripts94/kubuntu-get-rid-of-snap/-/raw/main/Kubuntu\_get\_rid\_of\_Snap.sh?ref\_type=heads](https://gitlab.com/scripts94/kubuntu-get-rid-of-snap/-/raw/main/Kubuntu\_get\_rid\_of\_Snap.sh?ref\_type=heads)
4.

    ```bash
    sudo apt install flatpak plasma-discover-backend-flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    ```
