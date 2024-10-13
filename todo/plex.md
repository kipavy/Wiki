# plex

TUTO PLEX GENERER USER PASSWD:

```bash
docker run --rm httpd:alpine htpasswd -nb USERNAME PASS | sed 's/\$/\$\$/g' 
```



SETUP SSL TRAEFIK TURNED CLOUDFLARE SSL MODE TO FULL (not strict) https://www.smarthomebeginner.com/cloudflare-settings-for-traefik-docker/
