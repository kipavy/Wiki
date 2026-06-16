---
description: CI/CD Examples
---

# CI/CD

## Github Actions

### Docker image build publish

A minimal workflow that builds on every push to `main` and publishes to GitHub Container Registry (GHCR). No secrets to configure — `GITHUB_TOKEN` is provided automatically:

```yaml
name: Build and push image

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write          # needed to push to GHCR
    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
```

{% hint style="info" %}
Push to Docker Hub instead by setting `registry` to `docker.io` (or omitting it) and using `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` repository secrets for the login step.
{% endhint %}

Full examples:

* [Simple build/publish](https://github.com/kipavy/debrid-client-proxy/blob/main/.github/workflows/docker-image.yml)
* [More complex, with a testing requirement](https://github.com/Slynax/dump.fun/actions/runs/13072892669)

### Pypi releases (test on pre-release, official on releases)

[https://github.com/CEA-MetroCarac/pyvsnr/tree/main/.github/workflows](https://github.com/CEA-MetroCarac/pyvsnr/tree/main/.github/workflows)

### Trigger Dokploy deploy by API

really useful to fully configure dokploy automatically by API

[https://github.com/kipavy/roquette/blob/main/.github/workflows/deploy.yml](https://github.com/kipavy/roquette/blob/main/.github/workflows/deploy.yml)

### Github Pages build:

{% tabs %}
{% tab title="ViteJS" %}
[https://github.com/kipavy/trade-of-exile/blob/main/.github/workflows/deploy.yml](https://github.com/kipavy/trade-of-exile/blob/main/.github/workflows/deploy.yml)
{% endtab %}

{% tab title="NextJS" %}
[https://github.com/kipavy/Portfolio/blob/main/.github/workflows/nextjs.yml](https://github.com/kipavy/Portfolio/blob/main/.github/workflows/nextjs.yml)
{% endtab %}
{% endtabs %}

### flutter apk release build

[https://github.com/C0gn1to/mobile/blob/master/.github/workflows/build-apk.yml](https://github.com/C0gn1to/mobile/blob/master/.github/workflows/build-apk.yml)

### Chrome .crx build

[https://raw.githubusercontent.com/Jord38/fluxer-theme-inspector/refs/heads/main/.github/workflows/build.yml](https://raw.githubusercontent.com/Jord38/fluxer-theme-inspector/refs/heads/main/.github/workflows/build.yml)

## Gitlab CI/CD

### Ruff check+format -> tests -> build

using uv image instead of python for faster CI

disabled cache because gitlab runners dont have enough space to install python packages (wow)

Also publish docs site using gitlab pages and zensical

[https://gitlab.com/yoanncure/ontoflow\_core/-/pipelines/2391025651](https://gitlab.com/yoanncure/ontoflow_core/-/pipelines/2391025651)
