#!/usr/bin/env bash
set -euo pipefail

notify() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "$@"
  fi
}

if ! command -v bluetoothctl >/dev/null 2>&1; then
  notify "Bluetooth" "bluetoothctl ist nicht installiert."
  exit 1
fi

if ! LC_ALL=C bluetoothctl show >/dev/null 2>&1; then
  notify "Bluetooth" "Kein Bluetooth-Adapter gefunden."
  exit 1
fi

if [[ "${1:-scan}" == "off" ]]; then
  if bluetoothctl power off >/dev/null; then
    notify "Bluetooth" "Bluetooth wurde ausgeschaltet."
  else
    notify "Bluetooth" "Der Bluetooth-Adapter konnte nicht ausgeschaltet werden."
    exit 1
  fi
  exit 0
fi

adapter_info="$(LC_ALL=C bluetoothctl show)"
if ! grep -q $'Powered: yes' <<< "$adapter_info"; then
  if ! bluetoothctl power on >/dev/null; then
    notify "Bluetooth" "Der Bluetooth-Adapter konnte nicht eingeschaltet werden."
    exit 1
  fi
fi

notify -t 2500 "Bluetooth" "Suche nach Geräten ..."
timeout 5 env LC_ALL=C bluetoothctl scan on >/dev/null 2>&1 || true

device_rows="$(
  LC_ALL=C bluetoothctl devices |
    awk '/^Device ([[:xdigit:]]{2}:){5}[[:xdigit:]]{2} / && !seen[$2]++ { print $2 }' |
    while IFS= read -r address; do
      info="$(LC_ALL=C bluetoothctl info "$address" 2>/dev/null || true)"
      name="$(sed -n 's/^[[:space:]]*Name: //p' <<< "$info" | head -n 1)"
      [[ -n "$name" ]] || name="$address"

      paired="Nein"
      connected="Nein"
      grep -q $'Paired: yes' <<< "$info" && paired="Ja"
      grep -q $'Connected: yes' <<< "$info" && connected="Ja"

      printf '%s\n%s\n%s\n%s\n' "$address" "$name" "$paired" "$connected"
    done
)"

if [[ -z "$device_rows" ]]; then
  notify "Bluetooth" "Keine Bluetooth-Geräte gefunden."
  exit 0
fi

address="$(
  zenity --list \
    --title="Bluetooth-Geräte" \
    --text="Gerät zum Verbinden oder Trennen auswählen" \
    --column="Adresse" \
    --column="Gerät" \
    --column="Gekoppelt" \
    --column="Verbunden" \
    --hide-column=1 \
    --print-column=1 \
    --width=600 \
    --height=400 \
    <<< "$device_rows"
)" || exit 0

[[ -n "$address" ]] || exit 0

info="$(LC_ALL=C bluetoothctl info "$address" 2>/dev/null || true)"
name="$(sed -n 's/^[[:space:]]*Name: //p' <<< "$info" | head -n 1)"
[[ -n "$name" ]] || name="$address"

if grep -q $'Connected: yes' <<< "$info"; then
  if bluetoothctl disconnect "$address" >/dev/null; then
    notify "Bluetooth" "Verbindung zu $name getrennt."
  else
    notify "Bluetooth" "Verbindung zu $name konnte nicht getrennt werden."
    exit 1
  fi
  exit 0
fi

if ! grep -q $'Paired: yes' <<< "$info"; then
  if ! bluetoothctl --agent NoInputNoOutput pair "$address" >/dev/null; then
    notify "Bluetooth" "Kopplung mit $name fehlgeschlagen."
    exit 1
  fi
fi

bluetoothctl trust "$address" >/dev/null || true

if bluetoothctl connect "$address" >/dev/null; then
  notify "Bluetooth" "Mit $name verbunden."
else
  notify "Bluetooth" "Verbindung zu $name fehlgeschlagen."
  exit 1
fi
