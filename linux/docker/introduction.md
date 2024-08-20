# Introduction

## Installation

<pre class="language-bash" data-full-width="false"><code class="lang-bash"><a data-footnote-ref href="#user-content-fn-1">sudo groupadd docker ; sudo usermod -aG docker $USER</a>
</code></pre>

[https://docs.docker.com/engine/install/](https://docs.docker.com/engine/install/)

## Basics

Here we launch a container named "test" in "detached interactive terminal" so that it runs in the background, and we mount the local pagesweb folder in the /usr/usr/share/nginx container folder in read-only mode, finally using the official nginx image:

```bash
docker run —name test -dit -p 8080:80 -v ~/pagesweb:/usr/usr/share/nginx/html:ro nginx
```

### [Mounting](https://docs.docker.com/storage/bind-mounts/)

\-v src[^2]:dest[^3]:ro[^4]  OR  --mount type=tmpfs[^5],src=folder1,dst=folder2

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

### [Install](https://docs.docker.com/compose/install/)

```bash
sudo apt update
sudo apt install docker-compose-plugin
```

### Usage

The docker compose command makes the creation of containers easy. You first need to create a docker-compose.yml file, here is an example :

{% hint style="warning" %}
Be Careful: Each Docker Volume/Network used need to be created in the compose file outside of services (level 0 of yaml), see the end of the example. By default all of the containers will be created in the same docker network.
{% endhint %}

<pre class="language-yaml"><code class="lang-yaml">services:
  # MARIADB
  <a data-footnote-ref href="#user-content-fn-6">db</a>:
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

  # WORDPRESS
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
</code></pre>

and run:

<pre class="language-bash" data-full-width="false"><code class="lang-bash">docker compose up <a data-footnote-ref href="#user-content-fn-7">-d</a>
</code></pre>

### Examples



### [Basic commands](https://docs.docker.com/reference/cli/docker/compose/)

* Run Docker Compose file: <mark style="color:red;">`docker compose up -d`</mark>
* Start all services: <mark style="color:red;">`docker compose up`</mark>
* Stop all services: <mark style="color:red;">`docker compose down`</mark>



[^1]: If you don't do this before install you may have permissions issues with docker

[^2]: Src folder path or docker volume name

[^3]: Destination folder, inside container

[^4]: Read-Only

[^5]: optional

[^6]: hostname of container, can be used thanks to docker dns service

[^7]: Detached mode: Run containers in the background
