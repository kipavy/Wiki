# Useful Tips

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
