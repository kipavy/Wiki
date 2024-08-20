# Examples of use

### Use node and npm commands without installing:

```bash
docker run --rm --network host \
-v /home/killian/Documents/web_project/:/web_project/ \
-it node:current-alpine \
sh -c "cd web_project && npm i && npm run dev"
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
