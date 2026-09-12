# Make locally installed tools available before loading plugins
[[ -d "$HOME/.local/bin" ]] && path=("$HOME/.local/bin" $path)
export PNPM_HOME="$HOME/.local/share/pnpm"
[[ -d "$PNPM_HOME/bin" ]] && path=("$PNPM_HOME/bin" $path)

# Load Zap when installed
if [[ -r "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ]]; then
  source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
fi

if (( $+functions[plug] )); then
  plug "zap-zsh/supercharge"
  plug "zap-zsh/completions"
fi

# Load and initialise completion system independently of Zap plugins
autoload -Uz compinit
compinit

if (( $+functions[plug] )); then
  plug "zap-zsh/sudo"
  plug "zsh-users/zsh-history-substring-search"
  plug "chivalryq/git-alias"
  plug "MichaelAquilina/zsh-you-should-use"

  # fzf-tab must precede plugins that wrap completion widgets
  if (( $+commands[fzf] )); then
    plug "zap-zsh/fzf"
    plug "Aloxaf/fzf-tab"
  fi
  plug "zsh-users/zsh-autosuggestions"
  plug "zsh-users/zsh-syntax-highlighting"
fi

# Tree alias with level argument
unalias t 2>/dev/null
function t {
  local level=1
  if [[ $1 == <-> ]]; then
    level=$1
    shift
  fi
  tree -ahC --du -L "$level" "$@"
}

# Misc aliases
alias spider="telnet dx.da0bcc.de 7300"
alias c="clear"
alias lts="eza -1lga --icons=auto --git --total-size"
alias l="eza -1lga --icons=auto --git"
alias ff="c;fastfetch"
alias n="nano"
alias v="vim"
alias nv="nvim"
alias y="yazi"
alias co="codex"
alias m="tmatrix -c default"
alias lg="lazygit"
if (( $+commands[batcat] )); then
  alias cat='batcat'
elif (( $+commands[bat] )); then
  alias cat='bat'
fi
alias e="exit"
alias q="exit"
alias w="w3m"
alias wee="weechat"
alias deploy-website="scp -r dist/* seventrees.io:/var/www/seventrees.io"
alias ctl="systemctl"
alias sctl="sudo systemctl"
alias jrnl="journalctl"
alias sjrnl="sudo journalctl"

# Useful Docker aliases
alias d="docker"
alias di="docker image"
alias dc="docker container"
alias dv="docker volume"
alias dps="docker ps"
alias dil="docker image list"
alias dcl="docker container list"
alias dvl="docker volume list"

# fnm
[[ -d "$HOME/.local/share/fnm" ]] && path=("$HOME/.local/share/fnm" $path)
if (( $+commands[fnm] )); then
  eval "$(fnm env --shell zsh)"
fi

if (( $+commands[starship] )); then
  eval "$(starship init zsh)"
fi
