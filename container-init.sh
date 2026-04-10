#!/bin/bash
set -e

# NVM verison to use for installing NPM latest
NVM_VERSION="v0.40.4"

# Python MCP server library
MCP_VERSION=1.26

# Enable by passing environment variable on start
#export OPENCODE_ENABLE_EXA=1

# Set editor for subprocesses
export EDITOR=vim

# Set home folder
export HOME=/home/opencode

# Set color hint
export TERM=xterm-256color

# Make light theme work again
#export OPENCODE_EXPERIMENTAL_MARKDOWN=0

# --- Helper functions ---

install_nvm() {
	echo "=== Downloading NVM ${NVM_VERSION}"
	curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | PROFILE="${HOME}/.profile" bash

	echo "=== Loading NVM"
	export NVM_DIR="$HOME/.nvm"
	[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
	[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

	echo "=== Install NPM LTS"
	nvm install --lts
	nvm use --lts
}

install_if_missing() {
	local check_path="$1"
	shift
	[[ -f "$check_path" ]] || "$@"
}

# --- Main ---

# Ensure HOME is writable; warn if it is not.
# This is a best-effort check and may fail if the container runs as a non-root user.
if [ ! -w "$HOME" ]; then
	echo "WARNING: $HOME is not writable. Exiting."
	exit 1
fi

# Copy default skel files into the user's home without overwriting newer files.
rsync -ur /etc/skel/. "$HOME"/

# Download and install NVM, and fetch NPM LTS
[[ -d "$HOME/.nvm" ]] || install_nvm

# Installer siste versjon av UV
install_if_missing "$HOME/.local/bin/uv" curl -LsSf https://astral.sh/uv/install.sh | sh

# Instal Python MCP library if we find .mcp
test -f .mcp && PIPENV_VENV_IN_PROJECT=1 pipenv install mcp~=${MCP_VERSION}

# Default TMUX config
test -f $HOME/.tmux.conf || cat <<'EOF' >$HOME/.tmux.conf
set-option -g default-shell /bin/bash
set -g mouse on
bind -n C-s set-window-option synchronize-panes
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",*:Tc"
set -ga terminal-overrides ",*:RGB"
EOF

# Create a minimal .gitconfig with a safe.directory entry if it doesn't already exist.
if [ ! -f "$HOME/.gitconfig" ]; then
	cat <<'EOF' >"$HOME/.gitconfig"
[safe]
    directory = /work
EOF
fi

# Execute the supplied command via a login shell so that profile/rc files are sourced.
# tini (PID 1) forwards SIGINT/SIGTERM to this process so CTRL+C works in both
# interactive TUI mode and headless web-server mode without a manual trap/wait loop.
if [ $# -eq 0 ]; then
	exec bash -l
else
	exec bash -l -c "$*"
fi
