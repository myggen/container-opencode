#!/bin/bash
set -e

# Allow upgrade
if [[ "${1,,}" == "upgrade" ]]
then
        UPGRADE=true
else
        UPGRADE=false
fi

# Install skeleton
rsync -ur /etc/skel/ /home/opencode/

# Install default opencode config if not already present
if [[ ! -f "$HOME/.config/opencode/config.json" ]]; then
        mkdir -p "$HOME/.config/opencode"
        cp /etc/opencode/config.json "$HOME/.config/opencode/config.json"
fi

# Create runtime dir for VS Code socket
mkdir -p /run/user/$(id -u)
chmod 700 /run/user/$(id -u)
export XDG_RUNTIME_DIR=/run/user/$(id -u)

# Install NVM
if [[ ! -d "$NVM_DIR" ]]
then
        mkdir -p "$NVM_DIR"
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | PROFILE=$HOME/.profile bash
fi

# Source NVM
source "$NVM_DIR/nvm.sh"

# Install Node
which node &> /dev/null || nvm install --lts

# Install node packages
( ! $UPGRADE && npm list -g opencode-ai )    &> /dev/null || npm i -g "opencode-ai@$OPENCODE_VERSION"
( ! $UPGRADE && npm list -g @biomejs/biome ) &> /dev/null || npm i -g "@biomejs/biome@$BIOME_VERSION"

# Install PIP packages
PATH=$PATH:$HOME/.local/bin
( ! $UPGRADE && which uv )     &> /dev/null || pipx install --force -qq uv~=$UV_VERSION
( ! $UPGRADE && which pipenv ) &> /dev/null || pipx install --force -qq pipenv~=$PIPENV_VERSION
( ! $UPGRADE && which ruff )   &> /dev/null || pipx install --force -qq ruff~=$RUFF_VERSION

if [[ "${1,,}" == "upgrade" ]]
then
        exit 0
fi

# Start
if [ $# -eq 0 ]; then
        exec bash -l
elif [[ "${1,,}" == "both" ]]; then
        source "$NVM_DIR/nvm.sh"
        export PATH="$PATH:$HOME/.local/bin"
        # Launch VS Code after a short delay, fully detached from the TTY
        ( sleep 2 && code --no-sandbox --user-data-dir /home/opencode/.vscode --unity-launch /work ) </dev/null &>/dev/null &
        exec opencode
else
        exec bash -l -c "$*"
fi
