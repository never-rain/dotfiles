[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# ENV Variables
export VISUAL="code --wait"
export EDITOR="code --wait"

[[ -d "$HOME/.platformio/penv/bin" ]] && path=("$HOME/.platformio/penv/bin" $path)

alias backupinit="borgmatic init"
alias backupcreate="borgmatic create --progress --stats"
alias backupmount="borgmatic mount --archive latest --mount-point ~/Backup"
