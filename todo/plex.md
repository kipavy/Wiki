# plex

TUTO PLEX GENERER USER PASSWD: docker run --rm httpd:alpine htpasswd -nb USERNAME PASS | sed 's/$/\$$/g'

SETUP SSL TRAEFIK TURNED CLOUDFLARE SSL MODE TO FULL (not strict) https://www.smarthomebeginner.com/cloudflare-settings-for-traefik-docker/

SI PB AVEEC RCLONE CONTAINER: fusermount -u /mnt/mountpoint
