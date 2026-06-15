# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

plug "zap-zsh/supercharge"
plug "zsh-users/zsh-autosuggestions"
plug "zsh-users/zsh-syntax-highlighting"
plug "zap-zsh/completions"
plug "zap-zsh/sudo"
plug "wintermi/zsh-starship"
plug "zsh-users/zsh-history-substring-search"
plug "zap-zsh/fzf"
plug "Aloxaf/fzf-tab"
plug "chivalryq/git-alias"
plug "MichaelAquilina/zsh-you-should-use"

# OS-aware config loading
case "$OSTYPE" in
  darwin*) ZSH_OS="macos" ;;
  linux*) ZSH_OS="linux" ;;
  *) ZSH_OS="unknown" ;;
esac
ZSHRC_DIR="${${(%):-%N}:A:h}"
ZSHRC_D_DIR="$ZSHRC_DIR/.zshrc.d"
[ -r "$ZSHRC_D_DIR/common.zsh" ] && source "$ZSHRC_D_DIR/common.zsh"
[ -r "$ZSHRC_D_DIR/${ZSH_OS}.zsh" ] && source "$ZSHRC_D_DIR/${ZSH_OS}.zsh"

# ENV Variables
export VISUAL="code"
export EDITOR="code"

# Misc aliases
alias spider="telnet dx.da0bcc.de 7300"
alias c="clear"
alias lts="eza -1lga --icons=auto --git --total-size"
alias l="eza -1lga --icons=auto --git"
alias ff="c;hyfetch"
alias n="nano"
alias v="nvim"
alias vi="nvim"
alias vim="nvim"
alias t="tree -a"
alias y="yazi"
alias co="codex"
alias m="unimatrix --flashers --asynchronous --speed 97"
alias lg="lazygit"
alias cat="bat"

# Load and initialise completion system
autoload -Uz compinit
compinit

eval "$(starship init zsh)"
export PATH="$HOME/.platformio/penv/bin:$PATH"
