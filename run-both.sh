podman run --rm --userns=keep-id -ti \
  -e DISPLAY=$DISPLAY \
  -e XDG_RUNTIME_DIR=/run/user/$(id -u) \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /run/user/$(id -u):/run/user/$(id -u) \
  -v opencode:/home/opencode \
  -v "$PWD":/work \
  -v "$HOME"/.gitconfig:/home/opencode/.gitconfig \
  opencode:latest both
