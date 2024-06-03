# Docker compose

It is possible to build an image directly inside docker compose.\


```docker
udf:
    build: https://github.com/Crackvignoule/tradingview-udf-binance-node.git
    restart: always
    ports:
      - "9090:443"
```

Even better, you can specify a branch, example for dev branch:

```docker
build: https://github.com/Crackvignoule/tradingview-udf-binance-node.git#dev
```
