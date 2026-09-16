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
4. If Zsh is installed, offer to make it the current user's login shell with `chsh`. An account already using Zsh is skipped. This may ask for your password and takes effect after fully logging out and back in.
5. Install fnm using its [official installer](https://fnm.vercel.app/install) into `~/.local/share/fnm`. An existing fnm in `PATH` or at that location is skipped. Missing `curl`/`unzip` prerequisites are offered separately. The installer runs with `--skip-shell` because the Zsh dotfiles already initialise fnm; it does not append to `.bashrc` or `.zshrc`.
6. Install pnpm using its [official standalone installer](https://pnpm.io/installation), with `PNPM_HOME=~/.local/share/pnpm`. An existing pnpm is skipped. Missing `curl`, `tar`, `gzip` and `openssl` are offered separately. The installer's shell configuration is directed into a temporary file because the Zsh dotfiles already set the pnpm paths.
7. Install [Codex CLI](https://learn.chatgpt.com/docs/codex/cli) with `pnpm add --global @openai/codex`, without `sudo`. pnpm is available immediately after step 6; no new terminal is needed. Before installing or checking Codex, the script ensures Node.js runs: it uses an existing Node or activates fnm's default version in the running Bash process. If no default is usable, it offers to install Node LTS with fnm and make it the default for future terminals. Declining, missing fnm when Node is unavailable, or missing pnpm skips the Codex step. An existing `codex` command is checked with `--version` rather than reinstalled. Sign in separately when you first run `codex`.
8. Install Zap for Zsh by cloning its `release-v1` branch into `${XDG_DATA_HOME:-$HOME/.local/share}/zap`. An existing Zap directory is skipped. This does not modify or source `.zshrc`, so installation also works before Stow has linked your shell configuration.
9. Link all Stow packages into your home directory. The script lists the packages and target before asking for confirmation, then checks for conflicts with a simulation before creating links.
10. Optionally start Zsh with `exec zsh` to load the shell settings in the current terminal. Enter skips this step. Temporary downloads are cleaned up before replacing the installer process. This does not log you out or restart the desktop session. When launched with `bash install.sh`, exiting the new Zsh returns to the shell that started the installer.

Missing prerequisites are offered as a separate, confirmed APT installation before the step that needs them. Declining skips that step. APT may also ask for confirmation. Errors stop the script, including failed index downloads from temporarily unavailable APT sources; completed changes are not rolled back.

[`packages.txt`](packages.txt) contains one package name per line. Leading and trailing whitespace (including Windows line endings) is removed; blank lines and lines starting with `#` are ignored. The entire list is selected as one step; edit it beforehand to choose individual packages. Package availability depends on your distribution and enabled sources, including when you skip adding a repository. Repository setup alone does not refresh APT indexes; that happens in the package step.

Existing GitHub CLI and Griffo entries in standard APT `.list` and `.sources` files are detected and left in place. This does not verify their signing keys or repair an existing setup. The script uses `sudo` for package and repository changes; `chsh` and Stow run as your normal user. The shell step checks the account entry and `/etc/shells`, then verifies the new account entry after `chsh` succeeds.

Every non-hidden directory directly inside this repository is treated as a Stow package; keep unrelated directories outside the checkout. Stow always targets `$HOME`, regardless of where you cloned the repository, and uses its default behaviour of linking whole directories where possible. Existing correct links are kept. Conflicting files (for example an existing `~/.zshrc`) are reported without being overwritten or adopted into the repository. If the simulation fails, no links are created: inspect the reported files, back up/move them yourself if appropriate, then rerun the script. You can skip the installation steps and select only Stow.

The script retains `deb.griffo.io` from the original setup. [Griffo](https://deb.griffo.io/) announces that package downloads require a subscription from 1 October 2026; its free mirror has a smaller package selection. Existing entries using `debian.griffo.io` are also recognised.
