---
description: >-
  Split DNS lets you split your DNS requests on different DNS servers depending
  on the website. For example you can use your own local DNS only for your
  domain.
---

# Split DNS

All you queries will work as usual, as if you wouldn't have tailscale enabled, only the requests for your domain will use your adguard local DNS (when tailscale is enabled), removing the need to buy a domain (except if you need a public app, like immich, that's useful for 24/24 sync, without having to enable tailscale). It also lets you use your domain for private apps such as adguard.yourdomain.fr which you obviously don't want to expose to internet.



You can use any domain you want without buying it, this will require local DNS rewrites for all your domains/subdomains. In this case you need to generate your own SSL certificate as any public ssl cert provider won't be able to see your domain (because it doesn't exist outsite your network). This may generate errors on your browser because its a self-signed certificate, you can bypass this by double clicking the .cert



If you have bought a domain name, you don't need to generate your certificate, NPM can do it for you. To avoid creating requesting another cert for each subdomain you can ask a cert for \*.YOURDOMAIN.FR and reuse this for each proxy.

{% hint style="warning" %}
Adguard Home: \*.yourdomain.fr is not covering yourdomain.fr. You need 2 rules
{% endhint %}

{% hint style="warning" %}
A lot of apps need Websocket enabled in NPM
{% endhint %}

### Script to generate HTTPS cert valid for 100 years

{% code fullWidth="false" %}
```bash
DOMAIN=legoatdesserveurs.fr
NPM_IP=192.168.1.110

openssl req -x509 -nodes -days 36500 -newkey rsa:2048 \
    -keyout wildcard.key \
    -out wildcard.crt \
    -subj "/C=FR/ST=Local/L=Home/O=HomeLab/CN=*.$DOMAIN" \
    -addext "subjectAltName = DNS:*.$DOMAIN,DNS:$DOMAIN,IP:$NPM_IP"
```
{% endcode %}

you'll need to install the .cert on your computer, on windows just double click it and add it to "trust certificates" store.\
I dont use dokploy for proxy/https cause I couldnt find how to use my custom cert and NPMplus works great and easy to setup.

