# Tips & Tricks

### Clean every unused images, containers, networks & build cache)

```bash
docker system prune -a
```

### Delete all containers at once

```bash
docker rm -f $(docker ps -aq)
```

### Build image in docker compose

It is possible to build an image directly inside docker compose.

<pre class="language-yaml"><code class="lang-yaml">udf:
    build: https://github.com/kipavy/tradingview-udf-binance-node.git
    restart: always
<strong>    ports:
</strong>      - "9090:443"
</code></pre>

Even better, you can specify a branch, example for dev branch:

{% hint style="warning" %}
Keep the .git before the # or this syntax may not work
{% endhint %}

```yaml
build: https://github.com/kipavy/tradingview-udf-binance-node.git#dev
```

You can also specify a custom Dockerfile name using context:

```yaml
services:
  web:
    build:
      # build context: where to look for Dockerfile, as seen it can also be a distant URL
      context: ./app
      # Custom Dockerfile name, relative to the context directory
      dockerfile: Dockerfile.dev
```

***

### Get container start command

You started a container with docker run CLI but you forgot the command you used ? You can kinda get it back with these steps:

1. Get your container ID (you can just take a few char if you want):

```bash
docker ps
```

2. Run this with your ID at the end (lets say b0ca0c234177):

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro assaflavie/runlike b0ca0c234177
```

If you think you'll use it frequently you can add an alias to your \~/.bashrc or \~/.zshrc:

```bash
alias runlike="docker run --rm -v /var/run/docker.sock:/var/run/docker.sock:ro assaflavie/runlike"
```

After restarting your terminal, you can use it like this:

```bash
runlike rclone  # container name
runlike c64  # container ID
```

### Run GUI apps in docker in WSL2 using WSLg

```bash
docker run -it --rm \
  -v $(pwd):/app \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir \
  -e PULSE_SERVER=/mnt/wslg/PulseServer \
  image
```

If fonts are missing in your app, it may be necessary to install fonts, on alpine I needed to run this for firefox to work properly:

```bash
apk add font-noto font-noto-cjk font-noto-emoji
```

### Get container IP from service name

```bash
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(docker compose ps -q <service_name>)
```

### Get container IP from id or name

```bash
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' <container_name_or_id>
```

### Get volume mount folder

```bash
docker volume inspect -f '{{ .Mountpoint }}' <volume_name>
```
