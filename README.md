# Dotfiles

My personal dotfiles for **Ubuntu 26.04 LTS**, **Hyprland** and **Zsh**, with **Catppuccin Mocha** as the main theme. Feel free to browse and reuse individual settings.

The configuration is organised into GNU Stow packages. Each package mirrors its destination under `$HOME`: for example, `ghostty/.config/ghostty/config` becomes `~/.config/ghostty/config`.

## Installation

Clone the repository and install Stow:

```sh
sudo apt install git stow
git clone https://github.com/never-rain/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
```

[`packages.txt`](packages.txt) lists the APT packages to install, one per line. Blank lines and lines starting with `#` are ignored. Review the list and your configured APT sources before running `bash install.sh`; package availability depends on those sources. [`install.sh`](install.sh) refreshes the APT package indexes and installs the listed packages. It does not link dotfiles. The Starship and Zap installation commands in the script are commented out.
