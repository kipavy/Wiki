---
description: CI/CD Examples
---

# CI/CD

## Github Actions

### Docker image build publish

[https://github.com/kipavy/debrid-client-proxy/blob/main/.github/workflows/docker-image.yml](https://github.com/kipavy/debrid-client-proxy/blob/main/.github/workflows/docker-image.yml)

another more complex example with testing requirement: [https://github.com/Slynax/dump.fun/actions/runs/13072892669](https://github.com/Slynax/dump.fun/actions/runs/13072892669)

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
