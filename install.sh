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
# Global, damit die am Paket-Schritt übersprungenen Namen am Ende verfügbar sind.
missing_packages=()

cleanup_downloads() {
  if [[ -n "$temp_dir" ]]; then
    rm -rf -- "$temp_dir"
    temp_dir=''
  fi
}
trap cleanup_downloads EXIT

prepare_downloads() {
  if [[ -z "$temp_dir" ]]; then
    # Der feste /tmp-Pfad verhindert, dass ein TMPDIR im Checkout temporäre
    # Zugangsdaten ins Git-Verzeichnis lenkt. mktemp vergibt die Rechte 0700.
    temp_dir=$(mktemp -d /tmp/dotfiles-install.XXXXXXXXXX)
  fi
}

confirm() {
  # local begrenzt die Variable auf diese Funktion. $1 ist ihr erstes Argument.
  local answer
  while true; do
    printf '\n%s [J/n] ' "$1"
    # -r liest Backslashes unverändert; IFS= erhält die Eingabe unverändert.
    # Ein geschlossenes Eingabegerät (EOF) beendet das Script kontrolliert.
    if ! IFS= read -r answer; then
      printf '\nEingabe beendet; Installation abgebrochen.\n' >&2
      exit 1
    fi
    # ${answer,,} wandelt in Kleinbuchstaben um; Enter bedeutet Ja.
    case "${answer,,}" in
    j | ja | y | yes | '') return 0 ;;
    n | nein | no) return 1 ;;
    *) printf 'Bitte j oder n eingeben. Enter bestätigt den Schritt.\n' ;;
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
  # HTTPS-Downloads benötigen ausserdem die vertrauenswürdigen CA-Zertifikate.
  if [[ " $* " == *' curl '* ]] &&
    [[ $(dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null || true) != 'install ok installed' ]]; then
    missing+=(ca-certificates)
  fi
  if ((${#missing[@]} == 0)); then
    return 0
  fi

  printf 'Für diesen Schritt fehlen: %s\n' "${missing[*]}"
  if ! confirm 'Diese Abhängigkeiten zuerst über apt installieren?'; then
    printf 'Schritt wegen fehlender Abhängigkeiten übersprungen.\n'
    return 1
  fi
  # Diese Funktion wird in einer if-Bedingung aufgerufen. Dort greift Bashs
  # set -e nicht wie sonst: Deshalb behandeln wir Fehler hier ausdrücklich.
  # Auch vorübergehend unerreichbare Quellen sollen den Ablauf stoppen.
  sudo apt-get update --error-on=any || exit 1
  sudo apt-get install -- "${missing[@]}" || exit 1
}

repo_exists() {
  local pattern=$1 source_file
  # Nur APT-Dateien prüfen, keine .bak- oder .disabled-Dateien.
  for source_file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [[ -f "$source_file" ]] || continue
    if [[ "$source_file" == *.sources ]]; then
      # Deb822 trennt Einträge durch Leerzeilen. Eingerückte Zeilen setzen das
      # vorherige Feld fort; Feldnamen sind unabhängig von Gross-/Kleinschreibung.
      if awk -v pattern="$pattern" '
        function check_stanza(    key) {
          if (tolower(fields["enabled"]) !~ /^[[:space:]]*no[[:space:]]*$/ &&
              fields["types"] ~ /(^|[[:space:]])deb([[:space:]]|$)/ &&
              fields["uris"] ~ pattern) matched=1
          for (key in fields) delete fields[key]
          field=""
        }
        { sub(/\r$/, "") }
        /^[[:space:]]*#/ { next }
        /^[[:space:]]*$/ { check_stanza(); next }
        /^[[:space:]]/ {
          if (field != "") fields[field]=fields[field] " " $0
          next
        }
        {
          separator=index($0, ":")
          field=separator ? tolower(substr($0, 1, separator-1)) : ""
          if (field != "") fields[field]=substr($0, separator+1)
        }
        END { check_stanza(); exit !matched }
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

configure_griffo_auth() (
  # Runde Klammern starten eine Subshell: Variablen und umask gelten nur hier.
  # Auch bei bash -x dürfen Zugangsdaten nicht im Debug-Protokoll erscheinen.
  set +x
  umask 077
  local auth_file=/etc/apt/auth.conf.d/deb.griffo.io.conf
  local griffo_username griffo_password

  if sudo test -s "$auth_file"; then
    if confirm 'Vorhandene Griffo-Zugangsdaten beibehalten?'; then
      sudo chown root:root "$auth_file"
      sudo chmod 0600 "$auth_file"
      return
    fi
  fi

  # APT trennt Felder durch Leerzeichen. Anführungszeichen und Backslashes
  # wären ebenfalls Formatzeichen; solche Eingaben nicht still verfälschen.
  while true; do
    printf 'Griffo-Benutzername: '
    if ! IFS= read -r griffo_username; then
      printf '\nEingabe beendet; Installation abgebrochen.\n' >&2
      exit 1
    fi
    if [[ -n "$griffo_username" && "$griffo_username" != *[[:space:]\"\\]* ]]; then
      break
    fi
    printf 'Bitte einen nicht leeren Benutzernamen ohne Leerraum, " oder Backslash eingeben.\n'
  done
  while true; do
    printf 'Griffo-Passwort (Eingabe unsichtbar): '
    # -s unterdrückt die Anzeige, -r liest Backslashes unverändert.
    if ! IFS= read -r -s griffo_password; then
      printf '\nEingabe beendet; Installation abgebrochen.\n' >&2
      exit 1
    fi
    printf '\n'
    if [[ -n "$griffo_password" && "$griffo_password" != *[[:space:]\"\\]* ]]; then
      break
    fi
    printf 'Bitte ein nicht leeres Passwort ohne Leerraum, " oder Backslash eingeben.\n'
  done

  # Das private mktemp-Verzeichnis liegt ausserhalb des Checkouts. printf ist
  # ein Bash-Builtin: Die Werte werden nicht als externe Prozessargumente sichtbar.
  printf 'machine deb.griffo.io\nlogin %s\npassword %s\n' \
    "$griffo_username" "$griffo_password" >"$temp_dir/griffo-auth.conf"
  sudo install -d -m 0755 /etc/apt/auth.conf.d
  sudo install -o root -g root -m 0600 "$temp_dir/griffo-auth.conf" "$auth_file"
  rm -f -- "$temp_dir/griffo-auth.conf"
  printf 'Griffo-Zugangsdaten für APT gespeichert (nur root lesbar).\n'
)

migrate_griffo_sources() {
  local griffo_host=$1 source_file
  for source_file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    [[ -f "$source_file" ]] || continue
    # Nur bekannte Griffo-URLs ersetzen. Suite, Signed-By und fremde Quellen
    # bleiben erhalten, auch bei gemischten Dateien und mehrzeiligen Deb822-Feldern.
    sed -E "s#https?://(debian|deb-free|deb)\.griffo\.io/apt([/[:space:]]|$)#https://$griffo_host/apt\2#g" \
      "$source_file" >"$temp_dir/griffo-source"
    if cmp -s "$source_file" "$temp_dir/griffo-source"; then continue; fi
    printf 'Griffo-Quelle umstellen: %s\n' "$source_file"
    # Die erste Sicherung behalten. APT liest die Endung .griffo-backup nicht.
    if ! sudo test -e "$source_file.griffo-backup"; then
      sudo cp -p -- "$source_file" "$source_file.griffo-backup"
    fi
    sudo install -o root -g root -m 0644 "$temp_dir/griffo-source" "$source_file"
  done
}

add_griffo_repo() {
  local griffo_host=deb-free.griffo.io codename
  prepare_downloads
  # Zugangsdaten vor jedem möglichen APT-Aufruf einrichten, auch wenn das
  # Repository schon existiert oder Abhängigkeiten nachinstalliert werden müssen.
  if confirm 'Griffo-Zugangsdaten vorhanden (kostenpflichtiges Repository verwenden)?'; then
    griffo_host=deb.griffo.io
    configure_griffo_auth
  else
    printf 'Öffentliches Griffo-Repository gewählt; es enthält weniger Pakete.\n'
  fi
  migrate_griffo_sources "$griffo_host"
  if repo_exists "https://${griffo_host//./[.]}/apt([/[:space:]]|$)"; then
    printf 'Gewähltes Griffo-Repository bereits eingetragen: %s\n' "$griffo_host"
    return
  fi
  if ! ensure_tools curl gpg; then return; fi
  # os-release liefert den Distributions-Codenamen ohne zusätzliches lsb-release.
  # shellcheck source=/etc/os-release
  source /etc/os-release
  codename=${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}
  if [[ -z "$codename" ]]; then
    printf 'Kein Distro-Codename gefunden; Griffo übersprungen.\n' >&2
    return
  fi
  prepare_downloads

  # Beide Griffo-Repositories verwenden denselben Signaturschlüssel. Deshalb
  # bleibt beim Wechsel auch ein vorhandener Signed-By-Pfad gültig.
  curl -fsSL "https://$griffo_host/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc" \
    -o "$temp_dir/griffo.asc"
  # --dearmor wandelt den textuellen Schlüssel in einen binären Keyring um.
  gpg --batch --yes --dearmor -o "$temp_dir/griffo.gpg" "$temp_dir/griffo.asc"
  sudo install -d -m 0755 /etc/apt/keyrings /etc/apt/sources.list.d
  sudo install -m 0644 "$temp_dir/griffo.gpg" /etc/apt/keyrings/deb.griffo.io.gpg
  # signed-by beschränkt diesen Schlüssel auf das zugehörige Repository.
  printf 'deb [signed-by=/etc/apt/keyrings/deb.griffo.io.gpg] https://%s/apt %s main\n' \
    "$griffo_host" "$codename" >"$temp_dir/deb.griffo.io.list"
  sudo install -m 0644 "$temp_dir/deb.griffo.io.list" /etc/apt/sources.list.d/deb.griffo.io.list
}

install_packages() {
  local package policy candidate
  local -a packages=() available_packages=()
  missing_packages=()
  # Zeilen einzeln lesen, Kommentare und Leerzeilen auslassen. Das Array erhält
  # jeden Paketnamen als separates Argument. Auch die letzte Zeile ohne \n zählt.
  while IFS= read -r package || [[ -n "$package" ]]; do
    # # und % entfernen passende Muster am Anfang bzw. Ende. So verschwinden
    # äussere Leerzeichen, Tabs und das zusätzliche CR von Windows-Zeilenenden.
    package=${package#"${package%%[![:space:]]*}"}
    package=${package%"${package##*[![:space:]]}"}
    [[ "$package" == \#* || -z "$package" ]] && continue
    packages+=("$package")
  done <packages.txt
  if ((${#packages[@]} == 0)); then
    printf 'packages.txt enthält keine Pakete.\n'
    return
  fi
  printf '\nPakete aus packages.txt:\n'
  printf '  %s\n' "${packages[@]}"
  if confirm 'Paketlisten aktualisieren und diese Pakete installieren?'; then
    sudo apt-get update --error-on=any
    for package in "${packages[@]}"; do
      # policy berücksichtigt die aktivierten Quellen und APT-Prioritäten.
      # LC_ALL=C hält den Feldnamen Candidate unabhängig von der Systemsprache.
      policy=$(LC_ALL=C apt-cache policy -- "$package")
      candidate=$(awk '$1 == "Candidate:" { print $2; exit }' <<<"$policy")
      if [[ -n "$candidate" && "$candidate" != '(none)' ]]; then
        available_packages+=("$package")
      elif [[ $(dpkg-query -W -f='${Status}' -- "$package" 2>/dev/null || true) != 'install ok installed' ]]; then
        # Ein fehlender Kandidat soll die übrigen Pakete nicht blockieren.
        # Bereits installierte Pakete gelten auch ohne Quelle nicht als fehlend.
        missing_packages+=("$package")
        printf 'Kein APT-Installationskandidat; übersprungen: %s\n' "$package"
      fi
    done
    if ((${#available_packages[@]} > 0)); then
      # Ohne -y: APT zeigt seinen Plan. Echte Installationsfehler brechen weiter
      # ab; nur Pakete ohne Kandidat werden vor diesem Aufruf aussortiert.
      sudo apt-get install -- "${available_packages[@]}"
    fi
  fi
}

report_missing_packages() {
  local package
  local -a still_missing=()
  for package in "${missing_packages[@]}"; do
    # Ein späterer Schritt könnte ein Paket als Abhängigkeit installiert haben.
    if [[ $(dpkg-query -W -f='${Status}' -- "$package" 2>/dev/null || true) != 'install ok installed' ]]; then
      still_missing+=("$package")
    fi
  done
  if ((${#still_missing[@]} > 0)); then
    printf '\nNoch nicht installierte Pakete aus packages.txt (kein APT-Kandidat):\n'
    printf '  %s\n' "${still_missing[@]}"
    printf 'Nach dem Einrichten weiterer Quellen das Script erneut starten und den Paket-Schritt wählen.\n'
  fi
}

set_zsh_as_login_shell() {
  local zsh_path username passwd_entry current_shell
  if ! zsh_path=$(command -v zsh); then
    printf '\nzsh ist nicht installiert; Änderung der Login-Shell übersprungen.\n'
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
    printf '\nzsh ist bereits die Login-Shell für %s.\n' "$username"
    return
  fi
  if ! command -v chsh >/dev/null; then
    printf '\nchsh fehlt. Änderung der Login-Shell übersprungen.\n' >&2
    return
  fi
  # chsh erlaubt normalen Benutzern nur Shells aus /etc/shells.
  # -F sucht festen Text, -x eine ganze Zeile und -q unterdrückt die Ausgabe.
  if ! grep -Fxq -- "$zsh_path" /etc/shells; then
    printf '\n%s ist nicht in /etc/shells freigegeben; Shell-Wechsel übersprungen.\n' "$zsh_path" >&2
    return
  fi

  printf '\nLogin-Shell für %s: %s → %s\n' "$username" "$current_shell" "$zsh_path"
  if confirm 'zsh als Standard-Shell für diesen Benutzer eintragen?'; then
    # Ohne sudo: chsh ändert nur dein Konto und kann dein Passwort abfragen.
    chsh --shell "$zsh_path" "$username"
    passwd_entry=$(getent passwd "$username")
    if [[ ! "${passwd_entry##*:}" -ef "$zsh_path" ]]; then
      printf 'Die neue Login-Shell konnte nicht bestätigt werden.\n' >&2
      exit 1
    fi
    printf 'zsh ist eingetragen. Die Änderung gilt nach vollständigem Ab- und Anmelden.\n'
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

prepare_pnpm_environment() {
  local pnpm_path
  # Derselbe Pfad steht in zsh/.zshrc.d/all.zsh. export gibt die Werte an
  # Unterprozesse weiter; die aufrufende Terminal-Sitzung wird nicht verändert.
  export PNPM_HOME="$HOME/.local/share/pnpm"
  # Ab pnpm 11 liegen die Programme unter bin/, ältere Versionen direkt im Home.
  # So sind pnpm und globale Programme schon in diesem Script erreichbar.
  # Die Doppelpunkte begrenzen ganze PATH-Einträge. Wiederholte Aufrufe fügen
  # dieselben Verzeichnisse dadurch nicht erneut hinzu.
  for pnpm_path in "$PNPM_HOME" "$PNPM_HOME/bin"; do
    case ":$PATH:" in
    *":$pnpm_path:"*) ;;
    *) PATH="$pnpm_path:$PATH" ;;
    esac
  done
  export PATH
}

install_pnpm() {
  prepare_pnpm_environment
  if command -v pnpm >/dev/null; then
    printf 'pnpm ist bereits installiert; übersprungen.\n'
    return
  fi
  if ! ensure_tools curl tar gzip openssl; then return; fi
  prepare_downloads
  curl -fsSL https://get.pnpm.io/install.sh -o "$temp_dir/pnpm-install.sh"

  # Der offizielle Installer ruft pnpm setup auf und schreibt dabei Shell-Code.
  # Für sh bestimmt ENV die Zieldatei: Wir verwenden eine temporäre Datei, da
  # unsere Dotfiles PNPM_HOME und PATH bereits setzen. Nichts davon wird geladen.
  # env -u entfernt nur für diesen Aufruf Variablen, die die Shell-Erkennung
  # sonst auf Bash, Zsh, Fish oder Nushell umleiten könnten.
  env -u BASH_VERSION -u ZSH_VERSION -u FISH_VERSION -u NU_VERSION \
    SHELL=/bin/sh ENV="$temp_dir/pnpm-shellrc" sh "$temp_dir/pnpm-install.sh"
  pnpm --version
}

ensure_node_for_codex() {
  # Ein vorhandenes, ausführbares Node genügt, auch wenn es nicht von fnm stammt.
  if command -v node >/dev/null && node --version >/dev/null 2>&1; then
    return 0
  fi

  local fnm_executable fnm_environment node_version
  fnm_executable=$(command -v fnm || true)
  if [[ -z "$fnm_executable" && -x "$HOME/.local/share/fnm/fnm" ]]; then
    fnm_executable="$HOME/.local/share/fnm/fnm"
  fi
  if [[ -z "$fnm_executable" ]]; then
    printf 'Node.js und fnm fehlen; Codex-Schritt übersprungen. Bitte zuerst fnm installieren.\n' >&2
    return 1
  fi

  # Das Install-Script läuft in Bash und liest keine .zshrc. fnm env erzeugt
  # passende export-Befehle, die eval in DIESEM Prozess ausführt. Nur fnm zu
  # installieren oder chsh aufzurufen macht Node hier noch nicht verfügbar.
  # Zuweisung und eval getrennt halten, damit ein Fehler von fnm erkannt wird.
  # Wie bei ensure_tools gilt: In if-Bedingungen müssen Fehler explizit stoppen.
  fnm_environment=$("$fnm_executable" env --shell bash) || exit 1
  eval "$fnm_environment" || exit 1

  if "$fnm_executable" use default >/dev/null 2>&1 && node --version >/dev/null 2>&1; then
    printf 'Vorhandene fnm-Standardversion von Node.js aktiviert.\n'
    return 0
  fi
  if ! confirm 'Node.js LTS mit fnm installieren, aktivieren und als fnm-Standard setzen?'; then
    printf 'Codex-Schritt wegen fehlendem Node.js übersprungen.\n'
    return 1
  fi

  # --use aktiviert die installierte Version sofort. default sorgt dafür, dass
  # sie auch in neuen Terminals mit unserer fnm-Konfiguration verfügbar ist.
  "$fnm_executable" install --lts --use || exit 1
  node_version=$(node --version) || exit 1
  "$fnm_executable" default "$node_version" || exit 1
  printf 'Node.js %s ist für Codex verfügbar.\n' "$node_version"
}

install_codex() {
  prepare_pnpm_environment
  if ! command -v pnpm >/dev/null; then
    printf 'pnpm fehlt; Codex-Installation übersprungen. Bitte zuerst pnpm installieren.\n' >&2
    return
  fi
  if ! ensure_node_for_codex; then return; fi
  # Auch bei einem erneuten Durchlauf Node vorbereiten und Codex prüfen:
  # Ein vorhandener Launcher allein beweist keine funktionsfähige Installation.
  if command -v codex >/dev/null; then
    codex --version
    printf 'Codex CLI ist bereits installiert; Neuinstallation übersprungen.\n'
    return
  fi

  # --global installiert für den Benutzer statt in das Dotfiles-Projekt.
  # Kein sudo: pnpm verwaltet die Installation unter PNPM_HOME.
  pnpm add --global @openai/codex
  # Den tatsächlichen globalen Bin-Pfad abfragen, statt ein Layout anzunehmen.
  local global_bin
  global_bin=$(pnpm bin --global)
  "$global_bin/codex" --version
}

install_zap() {
  local zap_dir=${XDG_DATA_HOME:-$HOME/.local/share}/zap
  if [[ -e "$zap_dir" || -L "$zap_dir" ]]; then
    printf 'zap-Pfad existiert bereits: %s; übersprungen.\n' "$zap_dir"
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
  # */ findet nur Verzeichnisse; versteckte Ordner wie .git bleiben aussen vor.
  for package_dir in */; do
    [[ -d "$package_dir" ]] || continue
    # %/ entfernt den abschliessenden Slash aus dem Paketnamen.
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
  # Stow verlinkt standardmässig nach Möglichkeit ganze Verzeichnisse.
  # Alle Pakete gemeinsam prüfen: Auch Konflikte zwischen Paketen werden erkannt.
  # --simulate zeigt den Plan, ohne etwas zu ändern; --verbose erklärt die Links.
  if ! stow --dir="$PWD" --target="$HOME" --simulate --verbose \
    --stow -- "${stow_packages[@]}"; then
    printf '\nStow-Probelauf fehlgeschlagen; keine Verknüpfungen erstellt.\n' >&2
    printf 'Bei Dateikonflikten die angezeigten Zieldateien prüfen und bei Bedarf\n' >&2
    printf 'manuell sichern/verschieben. Danach das Script erneut starten.\n' >&2
    exit 1
  fi

  # Ohne --adopt: Vorhandene fremde Dateien werden nicht ins Repository übernommen.
  # Kein sudo: Die Links gehören dem Benutzer. Korrekte Links bleiben bestehen,
  # deshalb kann dieser Schritt auch später erneut ausgeführt werden.
  stow --dir="$PWD" --target="$HOME" --verbose \
    --stow -- "${stow_packages[@]}"
}

finish_installation() {
  if ! confirm 'Jetzt mit exec zsh eine zsh mit den neuen Einstellungen starten?'; then
    return
  fi
  if ! command -v zsh >/dev/null; then
    printf 'zsh ist nicht installiert; Shell-Start übersprungen.\n' >&2
    return
  fi

  # Bei erfolgreichem exec läuft der EXIT-Trap nicht. Deshalb temporäre
  # Downloads vor dem Prozesswechsel entfernen und den Pfad zurücksetzen.
  cleanup_downloads
  # exec ersetzt den Bash-Prozess dieses Scripts durch Zsh. Im interaktiven
  # Terminal liest Zsh die .zshrc neu. Die grafische Sitzung bleibt bestehen.
  # Bei Start mit bash install.sh führt exit später zur aufrufenden Shell zurück.
  exec zsh
}

# Der Hauptablauf liest sich wie eine Checkliste. Funktionen werden hier normal
# aufgerufen (nicht als if-Test), damit Fehler den Ablauf mit set -e stoppen.
printf 'Dotfiles-Installation: Jeder Schritt ist optional. Enter bedeutet Ja; n überspringt.\n'

if confirm 'GitHub-CLI-Repository hinzufügen?'; then
  add_github_repo
fi

if confirm 'Griffo-Repository einrichten (öffentlich oder mit Abo)?'; then
  add_griffo_repo
fi

install_packages

set_zsh_as_login_shell

if confirm 'fnm installieren?'; then
  install_fnm
fi

if confirm 'pnpm installieren?'; then
  install_pnpm
fi

if confirm 'Codex CLI (@openai/codex) global mit pnpm installieren?'; then
  install_codex
fi

if confirm 'zap für Zsh installieren (bestehende .zshrc behalten)?'; then
  install_zap
fi

stow_dotfiles

printf '\nAusgewählte Schritte abgeschlossen.\n'
report_missing_packages
finish_installation
