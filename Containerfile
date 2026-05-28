FROM docker.io/library/debian:stable-slim

# Maintainer and image description
LABEL maintainer="Arnulf Heimsbakk <arnulf.heimsbakk@gmail.com>" \
      description="Secure working environment for opencode with developer tools"

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
    EDITOR=vim

# Install required packages 
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
      bash-completion \
      bc \
      ca-certificates \
      curl \
      git \
      golang \
      gnupg \
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

# Init script
ADD container-init.sh /

# Working directory and volumes exposed by the image
WORKDIR /work
RUN ls -l /home/opencode
VOLUME ["/work", "/home/opencode"]

# Execute shell as default
ENTRYPOINT ["/usr/bin/tini", "--", "/container-init.sh"]
CMD ["opencode"]
