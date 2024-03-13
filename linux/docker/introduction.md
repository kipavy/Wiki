# Introduction

## Basics

Here we launch a container named "test" in "detached interactive terminal" so that it runs in the background, and we mount the local pagesweb folder in the /usr/usr/share/nginx container folder in read-only mode, finally using the official nginx image:

```bash
docker run —name test -dit -p 8080:80 -v ~/pagesweb:/usr/usr/share/nginx/html:ro nginx
```

### [Mounting](https://docs.docker.com/storage/bind-mounts/)

\-v src[^1]:dest[^2]:ro[^3]  OR  --mount type=tmpfs[^4],src=folder1,dst=folder2

## [Dockerfile](https://docs.docker.com/reference/dockerfile/)

Dockerfile is used to build docker images (not containers), here is an example of Dockerfile

```docker
FROM debian:latest
LABEL maintainer="kp <info@kp.fr>"

RUN apt-get update \
    && apt-get install -y iputils-ping \
    && apt-get install -y traceroute \
    && apt-get install -y curl \
    && apt-get clean

CMD ["/usr/bin/bash"]
```

### Build & Push Image

You need a free [dockerhub](https://hub.docker.com/) account.

```bash
docker login --username yourmail@gmail.com
docker build -t you_username/your_image:latest .
docker push your_username/your_image:latest
```

## [Docker Compose](https://docs.docker.com/compose/)

The docker compose command makes the creation of containers easy. You first need to create a docker-compose.yml file, here is an example :

```yaml
---
services:
  # MARIADB
  db:
    image: mariadb:latest
    environment:
      MYSQL_RANDOM_ROOT_PASSWORD: 1
      MYSQL_DATABASE: blog
      MYSQL_USER: bloguser
      MYSQL_PASSWORD: pass123
    volumes:
      - dbvol:/var/lib/mysql
    networks:
      - blognet
    restart: always

  # PHPMYADMIN
  dbadmin:
    image: phpmyadmin/phpmyadmin:latest
    environment:
      PMA_HOST: db
    ports:
      - 9090:80
    networks:
      - blognet
    restart: always

  # WORDPRESSs
  web:
    image: wordpress:latest
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_USER: bloguser
      WORDPRESS_DB_PASSWORD: pass123
      WORDPRESS_DB_NAME: blog
    ports:
      - 9000:80
    networks:
      - blognet
    volumes:
      - webvol:/var/www/html/wp-content
    restart: always

volumes:
  dbvol:
  webvol:

networks:
  blognet:
...
```

[^1]: Src folder path or docker volume name

[^2]: Destination folder, inside container

[^3]: Read-Only

[^4]: optional
