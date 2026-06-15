#!/usr/bin/env bash
set -euo pipefail

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  fi
}

wifi_rows="$(
  nmcli -t -f IN-USE,SSID,SECURITY,SIGNAL dev wifi list --rescan yes |
    awk -F: '
      $2 != "" && !seen[$2]++ {
        active = ($1 == "*") ? "yes" : "no"
        security = ($3 == "") ? "open" : $3
        printf "%s\n%s\n%s\n%s\n", $2, security, $4, active
      }
    '
)"

if [[ -z "$wifi_rows" ]]; then
  notify "Wi-Fi" "Keine WLAN-Netze gefunden."
  exit 0
fi

selection="$(
  zenity --list \
    --title="Wireless Networks" \
    --text="Select Network" \
    --column="SSID" \
    --column="Security" \
    --column="Signal" \
    --column="Active" \
    --print-column=1 \
    <<< "$wifi_rows"
)"

[[ -n "${selection:-}" ]] || exit 0

if nmcli device wifi connect "$selection"; then
  notify "Connected Wireless Network" "$selection"
  exit 0
fi

password="$(
  zenity --password \
    --title="Password" \
    --text="Password for $selection"
)"

[[ -n "${password:-}" ]] || exit 1

if nmcli device wifi connect "$selection" password "$password"; then
  notify "Wireless Network connected" "$selection"
else
  notify "Error" "Connection to $selection has failed."
  exit 1
fi
