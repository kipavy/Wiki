# Easy Monitoring

## (Choice 1) VS Code's docker extension

## (Choice 2) Portainer:

1. Copy paste this in terminal

<pre class="language-bash" data-overflow="wrap"><code class="lang-bash"><strong>docker volume create portainer_data
</strong>docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer-ce:latest
</code></pre>

2. open https://localhost:9443
