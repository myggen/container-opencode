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
	exit 1
fi

# Start
if [ $# -eq 0 ]; then
	exec bash -l
else
	exec bash -l -c "$*"
fi
