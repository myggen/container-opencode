FROM docker.io/library/debian:stable-slim
# Maintainer and image description
LABEL maintainer="Espen Myrland  <espenmyr@gmail.com>" \
      description="(More) Secure working environment for opencode with developer tools and VS Code (X11/Wayland)"
# Software versions
ENV NVM_VERSION=v0.40.4 \
    UV_VERSION=0.11.7 \
    PIPENV_VERSION=2026.5.2 \
    RUFF_VERSION=0.15.11 \
    OPENCODE_VERSION=latest \
    BIOME_VERSION=latest
# Opencode search with Exa
# ENV OPENCODE_ENABLE_EXA=1
# Minimal environment variables for build and environment
ENV DEBIAN_FRONTEND="noninteractive" \
    LANG=nb_NO.UTF-8 \
    LC_ALL=nb_NO.UTF-8 \
    HOME=/home/opencode \
    PATH="/usr/local/bin:$PATH" \
    NVM_DIR=/home/opencode/.local/lib/nvm \
    TERM=xterm-256color \
    EDITOR=vim \
    # X11/Wayland display passthrough — override at runtime if needed
    DISPLAY=:0 \
    WAYLAND_DISPLAY=wayland-0 \
    XDG_RUNTIME_DIR=/run/user/1000 \
    # Tell Electron/VS Code to prefer Wayland when available, fall back to X11
    ELECTRON_OZONE_PLATFORM_HINT=auto

# Install required packages
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
      bash-completion \
      bc \
      ca-certificates \
      curl \
      git \
      gnupg \
      golang \
      govulncheck \
      iputils-ping \
      jq \
      less \
      locales \
      lsof \
      man-db \
      nano \
      pipx \
      procps \
      ripgrep \
      rsync \
      shfmt \
      tini \
      tree \
      unzip \
      vim \
      zip \
      file \
      xxd \
      # X11 / Wayland runtime libraries required by VS Code (Electron)
      libx11-6 \
      libx11-xcb1 \
      libxcb1 \
      libxcb-dri3-0 \
      libxcomposite1 \
      libxcursor1 \
      libxdamage1 \
      libxext6 \
      libxfixes3 \
      libxi6 \
      libxkbcommon0 \
      libxkbcommon-x11-0 \
      libxkbfile1 \
      libxrandr2 \
      libxrender1 \
      libxss1 \
      libxtst6 \
      # Wayland
      libwayland-client0 \
      libwayland-cursor0 \
      libwayland-egl1 \
      # GPU / DRM (needed by Electron even without a real GPU)
      libgbm1 \
      libdrm2 \
      # GTK and related (VS Code's native file dialogs, menus)
      libgtk-3-0 \
      libgdk-pixbuf-2.0-0 \
      libpango-1.0-0 \
      libpangocairo-1.0-0 \
      libcairo2 \
      libatk1.0-0 \
      libatk-bridge2.0-0 \
      libatspi2.0-0 \
      # ALSA stub — VS Code links against it even if no audio needed
      libasound2 \
      # Nss — required by Chromium/Electron networking stack
      libnss3 \
      # dbus — VS Code uses it for secret storage / portal
      dbus \
      dbus-x11 \
      xdg-utils \
      # MIT-SHM / shared memory helpers for X11
      libxshmfence1 \
      inetutils-telnet \
      net-tools \
      && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    # Enable Norwegian and US locales
    sed -Ei 's/^.*(nb_NO.UTF-8 .*)$/\1/g' /etc/locale.gen && \
    sed -Ei 's/^.*(en_US.UTF-8 .*)$/\1/g' /etc/locale.gen && \
    locale-gen && \
    # Create the opencode home directory
    mkdir -p /home/opencode && \
    chmod 777 /home/opencode && \
    # System-wide shell niceties
    echo "if [ -f /etc/bash_completion ]; then . /etc/bash_completion; fi" >> /etc/bash.bashrc && \
    echo "alias ls='ls --color=auto'" >> /etc/bash.bashrc && \
    echo "alias grep='grep --color=auto'" >> /etc/bash.bashrc

# Install VS Code via official Microsoft apt repository
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
      > /etc/apt/sources.list.d/vscode.list && \
    apt-get update && \
    apt-get -y install --no-install-recommends code && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Init script
ADD container-init2.sh /
RUN chmod +x /container-init2.sh

# Default opencode config (copied to ~/.config/opencode/ at runtime by init script)
RUN mkdir -p /etc/opencode
COPY opencode.json /etc/opencode/config.json

# Default opencode config (copied to ~/.config/opencode/ at runtime by init script)

# Working directory and volumes exposed by the image
WORKDIR /work
RUN ls -l /home/opencode
VOLUME ["/work", "/home/opencode"]

# Execute shell as default
ENTRYPOINT ["/usr/bin/tini", "--", "/container-init2.sh"]

# Launch both VS Code and opencode side by side.
# container-init.sh should interpret this CMD and start both processes,
# e.g. by launching "code --no-sandbox /work" in the background and
# then exec-ing "opencode" in the foreground.
CMD ["both"]
