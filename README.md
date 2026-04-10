# Container for OpenCode

**Run the OpenCode agent in an isolated, safer environment using Podman.**

## Introduction
This repository provides a container setup for running OpenCode in a relaxed, "safe-vibe" development environment. It ensures a reproducible workspace while protecting your host system and keeping dependencies isolated.

## Prerequisites
- Podman (rootless recommended). Minimum tested: Podman 4.x.
- A POSIX shell (bash, zsh).
- Optional: a ~/.gitconfig file if you plan to share Git identity with the container.

## Quickstart

### Download from GitHub (default)
Fetches the latest release `.deb` from GitHub at build time:

```bash
podman build --no-cache -t opencode:latest .
```

### Use a local `.deb` file (avoids GitHub API rate limiting)
Place the `opencode-desktop-linux-amd64.deb` file in the repository root, then pass `INSTALL_SOURCE=local`:

```bash
podman build --no-cache --build-arg INSTALL_SOURCE=local -t opencode:latest .
```

You can also pin to a specific version when downloading from GitHub:

```bash
podman build --no-cache --build-arg OPENCODE_VERSION=v1.2.3 -t opencode:v1.2.3 .
```

### Build-arg Reference
| Argument | Default | Description |
| :--- | :--- | :--- |
| `INSTALL_SOURCE` | *(empty)* | Set to `local` to install from a `.deb` in the build context instead of downloading. |
| `OPENCODE_VERSION` | `latest` | GitHub release tag to download (e.g. `v1.2.3`). Ignored when `INSTALL_SOURCE=local`. |

If you want to enable Exa web tools at runtime, add `-e OPENCODE_ENABLE_EXA=1` to your `podman run` command.

## Usage

Run directly (interactive):

```bash
podman run --rm --userns=keep-id -ti \
  -v opencode:/home/opencode \
  -v "$PWD":/work \
  -v "$HOME"/.gitconfig:/home/opencode/.gitconfig \
  opencode:latest
```

With Exa enabled:

```bash
podman run --rm --userns=keep-id -ti \
  -e OPENCODE_ENABLE_EXA=1 \
  -v opencode:/home/opencode \
  -v "$PWD":/work \
  -v "$HOME"/.gitconfig:/home/opencode/.gitconfig \
  opencode:latest
```

Setup aliases (replace if changed)

```bash
OC="alias oc='podman run --hostname vibe --name opencode --rm --userns=keep-id -ti -v opencode:/home/opencode -v \"\$PWD\":/work -v \"\$HOME\"/.gitconfig:/home/opencode/.gitconfig opencode:latest'"
OCW="alias ocw='podman run --hostname vibe --name opencode --rm --userns=keep-id -ti -p 4096:4096 -v opencode:/home/opencode -v \"\$PWD\":/work -v \"\$HOME\"/.gitconfig:/home/opencode/.gitconfig opencode:latest opencode-cli web --hostname 0.0.0.0'"
grep -q "^alias oc=" ~/.bashrc && sed -i "s|^alias oc=.*|$OC|" ~/.bashrc || echo "$OC" >> ~/.bashrc
grep -q "^alias ocw=" ~/.bashrc && sed -i "s|^alias ocw=.*|$OCW|" ~/.bashrc || echo "$OCW" >> ~/.bashrc
source ~/.bashrc
```

### Flag Reference
| Flag | Description |
| :--- | :--- |
| `--rm` | Remove the container automatically when it exits. |
| `--userns=keep-id` | Map the container user to your host user (keeps file ownership sane). |
| `-ti` | Allocate a TTY and run an interactive terminal session. |
| `-v opencode:/home...` | Persist OpenCode home data in a named volume between sessions. |
| `-v "$PWD":/work` | Mount current directory to `/work` so edits are visible on the host. |
| `-v .../.gitconfig` | Share host git configuration (identity/settings) with the container. |

### Signal Handling (CTRL+C)
`tini` is installed in the image and set as `ENTRYPOINT` PID 1. It properly reaps zombie processes and forwards `SIGINT`/`SIGTERM` to child processes, so **CTRL+C works in both interactive TUI mode and headless web-server mode** without any extra runtime flags.

If you prefer to use the runtime-injected init (equivalent behaviour, no image rebuild required), pass `--init` to `podman run` — but this is redundant when using this image since `tini` is already baked in.

## Troubleshooting
- If Podman is not found, install Podman for your distribution or use Docker as an alternative (adjust flags). 
- Permission errors when mounting: ensure rootless Podman is configured, or run with appropriate privileges. Avoid running containers as root unless necessary.
- If ~/.gitconfig is missing, the -v "$HOME"/.gitconfig mount will fail; either create a gitconfig or remove that mount.
- Port conflicts for 4096: choose a different host port (`-p HOST:4096`) when running ocw.

## Security Notes
- Containers reduce risk but are not a full security guarantee. Avoid running untrusted code without extra precautions.
- Be cautious when mounting host directories ("-v $PWD:/work"); this gives the container access to those files. Consider read-only mounts when appropriate: `-v "$PWD":/work:ro`.
- Sharing ~/.gitconfig exposes your git identity; prefer explicit environment variables for credentials and identity where possible.
- For stricter isolation consider SELinux, seccomp, user namespaces, or running inside a dedicated VM.
