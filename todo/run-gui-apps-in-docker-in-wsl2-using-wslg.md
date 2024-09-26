# Run GUI apps in docker in WSL2 using WSLg

It may be necessary to install fonts:

RUN apk add font-noto font-noto-cjk font-noto-emoji

```bash
docker run -it --rm \
  -v $(pwd):/app \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir \
  -e PULSE_SERVER=/mnt/wslg/PulseServer \
  image
```
