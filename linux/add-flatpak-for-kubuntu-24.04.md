---
description: Update, remove & block snap completely + install flatpak for Discover store
---

# Add flatpak for Kubuntu 24.04

{% hint style="warning" %}
This will delete all of your snap apps
{% endhint %}

1. <mark style="color:red;">`sudo apt update && sudo apt full-upgrade && sudo reboot`</mark>
2.

```bash
bash <(curl -fsSL https://gitlab.com/scripts94/kubuntu-get-rid-of-snap/-/raw/main/Kubuntu_get_rid_of_Snap.sh)
```

3.

<pre class="language-bash"><code class="lang-bash"><strong>sudo apt install flatpak plasma-discover-backend-flatpak
</strong>flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
</code></pre>
