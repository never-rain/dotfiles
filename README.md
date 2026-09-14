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

Run `bash install.sh` as your normal user. The script asks about each step separately; press Enter to skip, or answer `j`/`ja` (also `y`/`yes`) to proceed:

1. Add the GitHub CLI APT repository.
2. Add the Griffo APT repository.
3. Refresh the APT package indexes and install the packages from [`packages.txt`](packages.txt), including `gh` and `starship`.
4. Install Zap for Zsh using its upstream installer with `--keep`, preserving your `.zshrc`. An existing Zap directory is skipped. The upstream installer still sources `.zshrc` at the end.

Missing prerequisites are offered as a separate, confirmed APT installation before the step that needs them. Declining skips that step. APT may also ask for confirmation. Errors stop the script; completed changes are not rolled back.

[`packages.txt`](packages.txt) contains one package name per line. Blank lines and lines starting with `#` are ignored. The entire list is selected as one step; edit it beforehand to choose individual packages. Package availability depends on your distribution and enabled sources, including when you skip adding a repository. Repository setup alone does not refresh APT indexes; that happens in the package step.

Existing GitHub CLI and Griffo entries in standard APT `.list` and `.sources` files are detected and left in place. This does not verify their signing keys or repair an existing setup. The script uses `sudo` for system changes and does not link dotfiles or change your login shell.

The script retains `deb.griffo.io` from the original setup. [Griffo](https://deb.griffo.io/) announces that package downloads require a subscription from 1 October 2026; its free mirror has a smaller package selection. Existing entries using `debian.griffo.io` are also recognised.
