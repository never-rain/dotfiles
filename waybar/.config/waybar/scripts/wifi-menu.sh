#!/usr/bin/env bash
set -euo pipefail

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  fi
}

if [[ "${1:-scan}" == "off" ]]; then
  if nmcli radio wifi off; then
    notify "WLAN" "WLAN wurde ausgeschaltet."
  else
    notify "WLAN" "WLAN konnte nicht ausgeschaltet werden."
    exit 1
  fi
  exit 0
fi

if [[ "$(LC_ALL=C nmcli radio wifi)" != "enabled" ]]; then
  if ! nmcli radio wifi on; then
    notify "WLAN" "WLAN konnte nicht eingeschaltet werden."
    exit 1
  fi
fi

wifi_rows="$(
  LC_ALL=C nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list --rescan yes |
    awk -F: '
      $2 != "" && !seen[$2]++ {
        active = ($1 == "*") ? "Ja" : "Nein"
        security = ($3 == "") ? "Offen" : $3
        printf "%s\n%s\n%s\n%s\n", $2, security, $4, active
      }
    '
)"

if [[ -z "$wifi_rows" ]]; then
  notify "WLAN" "Keine WLAN-Netzwerke gefunden."
  exit 0
fi

selection="$(
  zenity --list \
    --title="WLAN-Netzwerke" \
    --text="Netzwerk auswählen" \
    --column="SSID" \
    --column="Sicherheit" \
    --column="Signal" \
    --column="Aktiv" \
    --print-column=1 \
    --width=600 \
    --height=400 \
    <<< "$wifi_rows"
)" || exit 0

[[ -n "$selection" ]] || exit 0

if nmcli device wifi connect "$selection"; then
  notify "Connected Wireless Network" "$selection"
  exit 0
fi

password="$(
  zenity --password \
    --title="Password" \
    --text="Password for $selection"
)" || exit 0

[[ -n "${password:-}" ]] || exit 1

if nmcli device wifi connect "$selection" password "$password"; then
  notify "Wireless Network connected" "$selection"
else
  notify "Error" "Connection to $selection has failed."
  exit 1
fi
