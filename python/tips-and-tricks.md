# Tips & Tricks

#### Install package from Github repo specific branch:

```bash
pip install git+https://github.com/CEA-MetroCarac/fitspy@pyside6
```

#### Install package in editable mode (useful for dev):

```bash
pip install -e .
```

#### Install correct version of cupy automatically (with GPU acceleration):

```shellscript
uv run --with pip https://raw.githubusercontent.com/CEA-MetroCarac/pyvsnr/main/src/pyvsnr/install_cupy.py
```
