#!/usr/bin/env bash

# -e: Bei einem fehlgeschlagenen Befehl abbrechen.
# -u: Nicht gesetzte Variablen als Fehler behandeln.
# pipefail: Auch Fehler am Anfang einer Pipeline erkennen.
set -euo pipefail

# BASH_SOURCE[0] ist der Pfad dieses Scripts. So finden wir packages.txt
# unabhängig davon, aus welchem Verzeichnis das Script gestartet wurde.
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

if ((EUID == 0)); then
  printf 'Bitte als normaler Benutzer starten: bash install.sh\n' >&2
  printf 'Nur die Systemschritte verwenden sudo. Zap gehört deinem Benutzer.\n' >&2
  exit 1
fi

if ! command -v apt-get >/dev/null || ! command -v sudo >/dev/null; then
  printf 'Dieses Script benötigt ein Debian-/Ubuntu-System mit apt-get und sudo.\n' >&2
  exit 1
fi

# Temporäre Downloads werden auch bei einem Fehler wieder entfernt.
# Das Verzeichnis wird erst angelegt, wenn tatsächlich ein Download nötig ist.
temp_dir=''
trap 'if [[ -n "$temp_dir" ]]; then rm -rf -- "$temp_dir"; fi' EXIT

prepare_downloads() {
  if [[ -z "$temp_dir" ]]; then
    temp_dir=$(mktemp -d)
  fi
}

confirm() {
  # local begrenzt die Variable auf diese Funktion. $1 ist ihr erstes Argument.
  local answer
  while true; do
    printf '\n%s [j/N] ' "$1"
    # -r liest Backslashes unverändert; IFS= erhält die Eingabe unverändert.
    # Ein geschlossenes Eingabegerät (EOF) beendet das Script kontrolliert.
    if ! IFS= read -r answer; then
      printf '\nEingabe beendet; Installation abgebrochen.\n' >&2
      exit 1
    fi
    # ${answer,,} wandelt in Kleinbuchstaben um; Enter bedeutet Nein.
    case "${answer,,}" in
    j | ja | y | yes) return 0 ;;
    n | nein | no | '') return 1 ;;
    *) printf 'Bitte j oder n eingeben. Enter überspringt den Schritt.\n' ;;
    esac
  done
}

ensure_tools() {
  local tool
  local -a missing=()
  # "$@" enthält alle Funktionsargumente, jeweils als eigenes Wort.
  # Bei diesen Werkzeugen stimmen Befehlsname und APT-Paketname überein.
  for tool in "$@"; do
    if ! command -v "$tool" >/dev/null; then
      missing+=("$tool")
    fi
  done
  # HTTPS-Downloads benötigen außerdem die vertrauenswürdigen CA-Zertifikate.
  if [[ " $* " == *' curl '* ]] &&
    [[ $(dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null || true) != 'install ok installed' ]]; then
    missing+=(ca-certificates)
  fi
  if ((${#missing[@]} == 0)); then
    return 0
  fi

  printf 'Für diesen Schritt fehlen: %s\n' "${missing[*]}"
  if ! confirm 'Diese Voraussetzungen zuerst über APT installieren?'; then
    printf 'Schritt wegen fehlender Voraussetzungen übersprungen.\n'
    return 1
  fi
  # Diese Funktion wird in einer if-Bedingung aufgerufen. Dort greift Bashs
  # set -e nicht wie sonst: Deshalb behandeln wir Fehler hier ausdrücklich.
  sudo apt-get update || exit 1
  sudo apt-get install -- "${missing[@]}" || exit 1
}

repo_exists() {
  local pattern=$1 source_file
  # Nur APT-Dateien prüfen, keine .bak- oder .disabled-Dateien.
  for source_file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [[ -f "$source_file" ]] || continue
    if [[ "$source_file" == *.sources ]]; then
      # Deb822 besteht aus Absätzen (RS=""). Deaktivierte Absätze zählen nicht.
      if awk -v pattern="$pattern" '
        BEGIN { RS=""; FS="\n" }
        {
          enabled=1; binary=0; found=0
          for (i=1; i<=NF; i++) {
            if ($i ~ /^[[:space:]]*#/) continue
            if (tolower($i) ~ /^enabled:[[:space:]]*no[[:space:]]*$/) enabled=0
            if ($i ~ /^Types:/ && $i ~ /[[:space:]]deb([[:space:]]|$)/) binary=1
            if ($i ~ /^URIs:/ && $i ~ pattern) found=1
          }
          if (enabled && binary && found) matched=1
        }
        END { exit !matched }
      ' "$source_file"; then
        return 0
      fi
    elif awk -v pattern="$pattern" '
      /^[[:space:]]*deb[[:space:]]/ {
        sub(/#.*/, "")
        if ($0 ~ pattern) matched=1
      }
      END { exit !matched }
    ' "$source_file"; then
      return 0
    fi
  done
  return 1
}

add_github_repo() {
  if repo_exists 'https?://cli[.]github[.]com/packages([/[:space:]]|$)'; then
    printf 'GitHub-CLI-Repository bereits eingetragen; übersprungen.\n'
    return
  fi
  if ! ensure_tools curl; then return; fi
  prepare_downloads

  # Erst vollständig herunterladen, dann mit lesbaren Rechten installieren.
  # Anleitung: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    -o "$temp_dir/githubcli.gpg"
  sudo install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d
  sudo install -m 0644 "$temp_dir/githubcli.gpg" /etc/apt/keyrings/githubcli-archive-keyring.gpg
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' \
    "$(dpkg --print-architecture)" >"$temp_dir/github-cli.list"
  sudo install -m 0644 "$temp_dir/github-cli.list" /etc/apt/sources.list.d/github-cli.list
}

add_griffo_repo() {
  # Auch den früheren Hostnamen erkennen, damit kein zweiter Eintrag entsteht.
  if repo_exists 'https?://(deb|debian)[.]griffo[.]io/apt([/[:space:]]|$)'; then
    printf 'Griffo-Repository bereits eingetragen; übersprungen.\n'
    return
  fi
  if ! ensure_tools curl gpg; then return; fi
  local codename
  # os-release liefert den Distributions-Codenamen ohne zusätzliches lsb-release.
  # shellcheck source=/etc/os-release
  source /etc/os-release
  codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}
  if [[ -z "$codename" ]]; then
    printf 'Kein Distributions-Codename gefunden; Griffo übersprungen.\n' >&2
    return
  fi
  prepare_downloads

  # Anleitung: https://deb.griffo.io/
  curl -fsSL https://deb.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc \
    -o "$temp_dir/griffo.asc"
  # --dearmor wandelt den textuellen Schlüssel in einen binären Keyring um.
  gpg --batch --yes --dearmor -o "$temp_dir/griffo.gpg" "$temp_dir/griffo.asc"
  sudo install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d
  sudo install -m 0644 "$temp_dir/griffo.gpg" /etc/apt/keyrings/deb.griffo.io.gpg
  # signed-by beschränkt diesen Schlüssel auf das zugehörige Repository.
  printf 'deb [signed-by=/etc/apt/keyrings/deb.griffo.io.gpg] https://deb.griffo.io/apt %s main\n' \
    "$codename" >"$temp_dir/deb.griffo.io.list"
  sudo install -m 0644 "$temp_dir/deb.griffo.io.list" /etc/apt/sources.list.d/deb.griffo.io.list
}

install_packages() {
  local package
  local -a packages=()
  # Zeilen einzeln lesen, Kommentare und Leerzeilen auslassen. Das Array erhält
  # jeden Paketnamen als separates Argument. Auch die letzte Zeile ohne \n zählt.
  while IFS= read -r package || [[ -n "$package" ]]; do
    [[ "$package" =~ ^[[:space:]]*(#|$) ]] && continue
    packages+=("$package")
  done <packages.txt
  if ((${#packages[@]} == 0)); then
    printf 'packages.txt enthält keine Pakete.\n'
    return
  fi
  printf '\nPakete aus packages.txt:\n'
  printf '  %s\n' "${packages[@]}"
  if confirm 'Paketlisten aktualisieren und diese Pakete installieren?'; then
    sudo apt-get update
    # Ohne -y: APT zeigt seinen Installationsplan und fragt gegebenenfalls nach.
    sudo apt-get install -- "${packages[@]}"
  fi
}

set_zsh_as_login_shell() {
  local zsh_path username passwd_entry current_shell
  if ! zsh_path=$(command -v zsh); then
    printf '\nZsh ist nicht installiert; Änderung der Login-Shell übersprungen.\n'
    return
  fi

  username=$(id -un)
  # getent liest den Kontoeintrag. $SHELL kann nach einer früheren Änderung noch
  # den alten Wert der laufenden Sitzung enthalten und ist dafür ungeeignet.
  passwd_entry=$(getent passwd "$username")
  # ##*: entfernt alles bis zum letzten Doppelpunkt: Übrig bleibt die Shell.
  current_shell=${passwd_entry##*:}
  # -ef erkennt auch /bin/zsh und /usr/bin/zsh als gleich, wenn sie auf dieselbe
  # Datei zeigen. Dann ist keine erneute Änderung nötig.
  if [[ "$current_shell" -ef "$zsh_path" ]]; then
    printf '\nZsh ist bereits die Login-Shell für %s.\n' "$username"
    return
  fi
  if ! command -v chsh >/dev/null; then
    printf '\nchsh fehlt (Paket passwd); Änderung der Login-Shell übersprungen.\n' >&2
    return
  fi
  # chsh erlaubt normalen Benutzern nur Shells aus /etc/shells.
  # -F sucht festen Text, -x eine ganze Zeile und -q unterdrückt die Ausgabe.
  if ! grep -Fxq -- "$zsh_path" /etc/shells; then
    printf '\n%s ist nicht in /etc/shells freigegeben; Shell-Wechsel übersprungen.\n' "$zsh_path" >&2
    return
  fi

  printf '\nLogin-Shell für %s: %s → %s\n' "$username" "$current_shell" "$zsh_path"
  if confirm 'Zsh als Standard-Shell für diesen Benutzer eintragen?'; then
    # Ohne sudo: chsh ändert nur dein Konto und kann dein Passwort abfragen.
    chsh --shell "$zsh_path" "$username"
    passwd_entry=$(getent passwd "$username")
    if [[ ! "${passwd_entry##*:}" -ef "$zsh_path" ]]; then
      printf 'Die neue Login-Shell konnte nicht bestätigt werden.\n' >&2
      exit 1
    fi
    printf 'Zsh ist eingetragen. Die Änderung gilt nach vollständigem Ab- und Anmelden.\n'
  fi
}

install_fnm() {
  # Der feste Zielpfad passt zur fnm-Einbindung in zsh/.zshrc.d/all.zsh.
  local fnm_dir="$HOME/.local/share/fnm"
  # Nach einer Installation ist fnm in dieser Sitzung eventuell noch nicht im
  # PATH. Deshalb zusätzlich die Programmdatei im Zielverzeichnis prüfen.
  if command -v fnm >/dev/null || [[ -x "$fnm_dir/fnm" ]]; then
    printf 'fnm ist bereits installiert; übersprungen.\n'
    return
  fi
  if ! ensure_tools curl unzip; then return; fi
  prepare_downloads

  # Erst vollständig herunterladen, dann ausführen. Bei einem Downloadfehler
  # stoppt set -e den Ablauf, bevor ein unvollständiges Script gestartet wird.
  curl -fsSL https://fnm.vercel.app/install -o "$temp_dir/fnm-install.sh"
  # --skip-shell verhindert Änderungen an .bashrc/.zshrc: Die Initialisierung
  # steht schon in unseren Dotfiles und wird durch den Stow-Schritt eingebunden.
  # --install-dir überschreibt auch einen eventuell abweichenden XDG-Standard.
  bash "$temp_dir/fnm-install.sh" --skip-shell --install-dir "$fnm_dir"
  "$fnm_dir/fnm" --version
}

install_zap() {
  local zap_dir=${XDG_DATA_HOME:-$HOME/.local/share}/zap
  if [[ -e "$zap_dir" || -L "$zap_dir" ]]; then
    printf 'Zap-Pfad existiert bereits: %s; übersprungen.\n' "$zap_dir"
    return
  fi
  if ! ensure_tools git zsh; then return; fi
  # Der Upstream-Installer klont diesen Branch, lädt danach aber die .zshrc.
  # Auf einem frischen System kann diese vor dem Stow-Schritt noch fehlen.
  # Deshalb klonen wir direkt: Die Konfiguration wird weder geändert noch geladen.
  mkdir -p -- "$(dirname -- "$zap_dir")"
  git clone --branch release-v1 https://github.com/zap-zsh/zap.git "$zap_dir"
}

stow_dotfiles() {
  local package_dir
  local -a stow_packages=()
  # In diesem Repository ist jedes sichtbare Unterverzeichnis ein Stow-Paket.
  # */ findet nur Verzeichnisse; versteckte Ordner wie .git bleiben außen vor.
  for package_dir in */; do
    [[ -d "$package_dir" ]] || continue
    # %/ entfernt den abschließenden Slash aus dem Paketnamen.
    stow_packages+=("${package_dir%/}")
  done
  if ((${#stow_packages[@]} == 0)); then
    printf 'Keine Stow-Pakete gefunden.\n'
    return
  fi

  printf '\nStow-Pakete für %s:\n' "$HOME"
  printf '  %s\n' "${stow_packages[@]}"
  if ! confirm 'Alle diese Dotfiles mit Stow verknüpfen?'; then
    return
  fi
  if ! ensure_tools stow; then return; fi

  # --dir ist das Repository, --target immer das Home-Verzeichnis. Dadurch
  # funktioniert Stow auch, wenn der Checkout z.B. unter ~/Downloads liegt.
  # --no-folding erstellt echte Zielverzeichnisse und verlinkt einzelne Dateien.
  # Alle Pakete gemeinsam prüfen: Auch Konflikte zwischen Paketen werden erkannt.
  # --simulate zeigt den Plan, ohne etwas zu ändern; --verbose erklärt die Links.
  if ! stow --dir="$PWD" --target="$HOME" --no-folding --simulate --verbose \
    --stow -- "${stow_packages[@]}"; then
    printf '\nStow-Probelauf fehlgeschlagen; keine Verknüpfungen erstellt.\n' >&2
    printf 'Bei Dateikonflikten die angezeigten Zieldateien prüfen und bei Bedarf\n' >&2
    printf 'manuell sichern/verschieben. Danach das Script erneut starten.\n' >&2
    exit 1
  fi

  # Ohne --adopt: Vorhandene fremde Dateien werden nicht ins Repository übernommen.
  # Kein sudo: Die Links gehören dem Benutzer. Korrekte Links bleiben bestehen,
  # deshalb kann dieser Schritt auch später erneut ausgeführt werden.
  stow --dir="$PWD" --target="$HOME" --no-folding --verbose \
    --stow -- "${stow_packages[@]}"
}

# Der Hauptablauf liest sich wie eine Checkliste. Funktionen werden hier normal
# aufgerufen (nicht als if-Test), damit Fehler den Ablauf mit set -e stoppen.
printf 'Dotfiles-Installation: Jeder Schritt ist optional. Enter bedeutet Nein.\n'

if confirm 'GitHub-CLI-Repository hinzufügen?'; then
  add_github_repo
fi

printf '\nGriffo: Laut Anbieter benötigen Paketdownloads ab 01.10.2026 ein Abo.\n'
printf 'Details: https://deb.griffo.io/\n'
if confirm 'Griffo-Repository (deb.griffo.io) hinzufügen?'; then
  add_griffo_repo
fi

install_packages

set_zsh_as_login_shell

if confirm 'fnm installieren?'; then
  install_fnm
fi

if confirm 'Zap für Zsh installieren (bestehende .zshrc behalten)?'; then
  install_zap
fi

stow_dotfiles

printf '\nAusgewählte Schritte abgeschlossen.\n'
