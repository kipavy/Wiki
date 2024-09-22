# Examples of use

### Use node and npm commands without installing:

copy paste at end of your \~/.bashrc or \~/.zshrc to have node and npm commands working with docker:

```bash
npm() {
  docker run --rm --network host \
  -v "$(pwd):/workdir" \
  -it node:current-alpine \
  sh -c "cd /workdir && npm $*"
}

node() {
  docker run --rm --network host \
  -v "$(pwd):/workdir" \
  -it node:current-alpine \
  sh -c "cd /workdir && node $*"
}
```

{% hint style="info" %}
That this shouldn't be a permanent setup cause it will be a lot slower than native commands cause this will create and delete a docker container each time you use the command
{% endhint %}

### Monitor Disk Usage

```bash
docker run --rm -it --privileged -v /:/mnt alpine sh -c "apk add ncdu && ncdu -x /mnt --exclude /mnt"
```

### MongoDB

```bash
docker run -d -p 27017:27017 --name mongodb mongo:latest
```

### MySQL

```bash
docker run -d -p 3306:3306 --name=mysql -e MYSQL_ROOT_PASSWORD=my-secret-pw mysql:latest
```

### Multi-repo project, docker compose example at [https://github.com/cvut-chat/cvutchat/](https://github.com/cvut-chat/cvutchat/)
