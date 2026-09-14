#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

mapfile -t packages < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' packages.txt)

sudo apt update
sudo apt install "${packages[@]}"

# Get Starship
# curl -sS https://starship.rs/install.sh | sh

# Get Zap for zsh
# zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1
