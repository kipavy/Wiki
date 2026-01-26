---
description: An extremely fast Python package and project manager, written in Rust.
---

# UV

Official Doc: [https://docs.astral.sh/uv](https://docs.astral.sh/uv)

Installation: [https://docs.astral.sh/uv/getting-started/installation/](https://docs.astral.sh/uv/getting-started/installation/)&#x20;

### Creating and using venv

[https://docs.astral.sh/uv/reference/cli/#uv-venv](https://docs.astral.sh/uv/reference/cli/#uv-venv)

{% hint style="info" %}
`-p 3.X` in any command to specify a python version to use
{% endhint %}

{% hint style="info" %}
Replace all `pip ...` commands by `uv pip ...` to use uv
{% endhint %}

#### create a .venv in current dir, no need to activate venv with uv

```bash
uv venv
```

#### To have pip installed in venv, can be useful for vscode extensions that arent compatible with uv

```bash
uv venv --seed
```

#### Project's environment (installs project in editable mode)

If you have pyproject.toml in your project, this command will create/update .venv for the project

```bash
uv sync
```

you could also directly run your package's entrypoint(s), uv will installs package in editable mode automatically, e.g:

```bash
uv run fitspy
```

#### Working with uvx

`uvx` is short for `uv tool run` It can run python modules without installing, e.g:

```bash
# from PyPi Package
uvx fitspy  
uvx spider

# From Github repo
uvx git+https://github.com/CEA-MetroCarac/fitspy@c3a00fd  # Specific commit

# Custom entrypoint
uvx --from jupyterlab jupyter-lab
uvx --from git+https://github.com/CEA-MetroCarac/fitspy fitspy
```

uvx can also be really useful to test an app you're developping on different python version without having to create multiple venv, for example, when I'm developping:

```shellscript
uvx --with-editable . -p 3.9 fitspy
```

or if you dont have a entrypoint script for your package you could juste use uv run, but note that each time you test another python version, it will delete and recreate .venv

```shellscript
 uv run -p 3.9 ./fitspy/apps/pyside/main.py
```

#### UV Cache Clean

Use this command to clean UV's cache:

```shellscript
uv cache clean
```
