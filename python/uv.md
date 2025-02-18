---
description: An extremely fast Python package and project manager, written in Rust.
---

# UV

### Official Doc

[https://docs.astral.sh/uv ](https://docs.astral.sh/uv)

### Installation

[https://docs.astral.sh/uv/getting-started/installation/](https://docs.astral.sh/uv/getting-started/installation/)&#x20;

### Creating and using venv

[https://docs.astral.sh/uv/reference/cli/#uv-venv](https://docs.astral.sh/uv/reference/cli/#uv-venv)

#### create a .venv in current dir, no need to activate venv with uv

```bash
uv venv
```

#### To have pip installed in venv, can be useful for vscode extensions that arent compatible with uv

```bash
uv venv --seed
```

#### Update project's environment (installs project in editable mode)

```bash
uv sync
```

you could also directly run your package's entrypoint(s), uv will installs package in editable mode automatically, e.g:

```bash
uv run fitspy
```



#### TODO

-p 3.X to specify python version

uv pip = pip uv run is like python \<script> (can be used for file or packages scripts)\
uv run python

uvx = uv tool run : run tools without installing e.g:

```bash
uvx fitspy
uvx spectroview
uvx spider
uvx --from jupyterlab jupyter-lab
...
```

uvx can also be really useful to test an app you're developping on different python version without having to create multiple venv, for example, when I'm developping&#x20;

```
uvx --with-editable . -p 3.9 fitspy
```

or if you dont have a entrypoint script for your package you could juste use uv run, but note that each time you test another python version, it will delete and recreate .venv

```bash
 uv run -p 3.9 .\fitspy\apps\pyside\main.py
```



uv cache clean
