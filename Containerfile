# Stage 1: Acquire the opencode .deb package
# Pass --build-arg INSTALL_SOURCE=local to copy the .deb from the build context
# instead of downloading from GitHub (avoids API rate limiting).

# Stage 0: Copy in a dummy file if we have no local version
FROM docker.io/library/debian:stable-backports AS file-check
WORKDIR /tmp
RUN --mount=target=/context [ -f /context/opencode-desktop-linux-amd64.deb ] && cp /context/opencode-desktop-linux-amd64.deb . || touch opencode-desktop-linux-amd64.deb
RUN --mount=target=/context [ -f /context/opencode-desktop-linux-arm64.deb ] && cp /context/opencode-desktop-linux-arm64.deb . || touch opencode-desktop-linux-arm64.deb

# Stage 1. Download binaries
FROM docker.io/library/debian:stable-backports AS downloader

ARG OPENCODE_VERSION="latest"
ARG INSTALL_SOURCE=""
ARG TARGETARCH

RUN echo "TARGETARCH=${TARGETARCH}"

COPY --from=file-check /tmp/opencode-desktop-linux-amd64.deb /tmp/opencode-desktop-linux-amd64.deb
COPY --from=file-check /tmp/opencode-desktop-linux-arm64.deb /tmp/opencode-desktop-linux-arm64.deb

RUN apt-get update && \
    apt-get -y install --no-install-recommends ca-certificates curl jq && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN if [ "${INSTALL_SOURCE}" = "local" ]; then \
        ARCH_SUFFIX=$(case "${TARGETARCH}" in amd64) echo "amd64";; arm64) echo "arm64";; *) echo "amd64";; esac) && \
        echo "Using local .deb for ${ARCH_SUFFIX}" && \
        cp "/tmp/opencode-desktop-linux-${ARCH_SUFFIX}.deb" /tmp/opencode.deb; \
    else \
        export VERSION="${OPENCODE_VERSION}" && \
        export REPO="anomalyco/opencode" && \
        if [ "${VERSION}" = "latest" ]; then \
            API_URL="https://api.github.com/repos/${REPO}/releases/latest"; \
        else \
            API_URL="https://api.github.com/repos/${REPO}/releases/tags/${VERSION}"; \
        fi && \
        echo "Fetching release metadata from $API_URL" && \
        ARCH_SUFFIX=$(case "${TARGETARCH}" in amd64) echo "amd64";; arm64) echo "arm64";; *) echo "amd64";; esac) && \
        DOWNLOAD_URL=$(curl -sSL "${API_URL}" | \
            jq -r ".assets[] | select(.name | endswith(\".deb\")) | select(.name | contains(\"${ARCH_SUFFIX}\")) | .browser_download_url" | head -n 1) && \
        if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then \
            echo "ERROR: No .deb package found for version ${VERSION}"; exit 1; \
        fi && \
        echo "Downloading: $DOWNLOAD_URL" && \
        curl -sSL "$DOWNLOAD_URL" -o /tmp/opencode.deb; \
    fi

# Stage 2: Final image
FROM docker.io/library/debian:stable-backports

ARG OPENCODE_VERSION="latest"

# Maintainer and image description
LABEL maintainer="Arnulf Heimsbakk <arnulf.heimsbakk@gmail.com>"
LABEL description="Sikkert arbeidsmiljø for opencode med utviklerverktøy"
LABEL version="${OPENCODE_VERSION}"

# Minimal environment variables for non-interactive builds and locales
ENV DEBIAN_FRONTEND="noninteractive"
ENV LANG=nb_NO.UTF-8
ENV HOME=/home/opencode
ENV PATH="/usr/local/bin:$PATH"

# Copy the pre-downloaded opencode .deb from the downloader stage
COPY --from=downloader /tmp/opencode.deb /tmp/opencode.deb

# Install required packages + opencode .deb, configure locales, create home dir,
# and set up shell niceties — all in one layer
RUN apt-get update && \
    apt-get -y install --no-install-recommends eatmydata && \
    eatmydata apt-get -y install --no-install-recommends \
      bash-completion \
      bc \
      ca-certificates \
      curl \
      gh \
      git \
      gnupg \
      iputils-ping \
      jq \
      less \
      locales \
      lsof \
      man-db \
      nano \
      openssh-client \
      pipx \
      procps \
      ripgrep \
      rsync \
      shfmt \
      tini \
      tmux \
      tree \
      unzip \
      vim \
      zip \
      /tmp/opencode.deb \
      && \
    rm /tmp/opencode.deb && \
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

# Copy and make the container entrypoint script executable
COPY --chmod=755 container-init.sh /usr/local/bin/container-init.sh

# Working directory and volumes exposed by the image
WORKDIR /work
VOLUME ["/work", "/home/opencode"]

# tini acts as PID 1 so SIGINT/SIGTERM (CTRL+C) are properly forwarded to
# container-init.sh and any child process it exec's (e.g. opencode-cli web).
# This makes CTRL+C work in both interactive TUI mode and headless web-server mode
# without needing a manual trap/wait loop inside the init script.
ENTRYPOINT ["/usr/bin/tini", "-s", "-g", "--", "/usr/local/bin/container-init.sh"]
CMD ["/usr/bin/opencode-cli"]
