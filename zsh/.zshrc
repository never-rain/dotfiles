# ~/.zshrc
typeset -U path PATH

source "$HOME/.zshrc.d/all.zsh"

() {
  # Domainanteil entfernen, z. B. neverrain.example.org -> neverrain.
  local machine_name="${HOST%%.*}"

  # Nur einfache Dateinamen zulassen; all.zsh wurde bereits geladen.
  [[ -n "$machine_name" && "$machine_name" != *[^a-zA-Z0-9_-]* ]] || return 0
  [[ "$machine_name" != all ]] || return 0

  local machine_config="$HOME/.zshrc.d/$machine_name.zsh"
  if [[ -r "$machine_config" ]]; then
    source "$machine_config"
  fi
}
