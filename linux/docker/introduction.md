# Introduction

## Basics

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

[^1]: Src folder path or docker volume name

[^2]: Destination folder, inside container

[^3]: Read-Only

[^4]: optional
