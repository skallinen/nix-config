# walk-home: undo walk-go on arrival. Lid sleep back on, back to home Wi-Fi.
# walk-and-talk wiki/walk-server.md, "Laptop in a bag".
set -u
. @lib@

say "Turning lid sleep back on (sudo asks for your fingerprint)."
sudo pmset -a disablesleep 0
if sleep_disabled; then
  warn "lid sleep is still off."
else
  say "Lid sleep: on (normal)."
fi

# Home Wi-Fi. The Mac rejoins it by itself once the hotspot is gone; if it has not,
# switch Wi-Fi off and on so it picks the best known network.
dev=$(wifi_dev)
if [ "$(gateway)" != "$HOME_GW" ] && [ -n "$dev" ]; then
  say "Not on home Wi-Fi. Turn off the phone hotspot."
  read -r -p "Press Enter when it is off: " _
  networksetup -setairportpower "$dev" off
  sleep 2
  networksetup -setairportpower "$dev" on
  for i in $(seq 1 30); do
    [ "$(gateway)" = "$HOME_GW" ] && break
    sleep 1
  done
  vm systemctl --user restart walk-vault-tunnel
fi
if [ "$(gateway)" = "$HOME_GW" ]; then
  say "Network: home Wi-Fi."
else
  warn "not on home Wi-Fi. Pick it from the Wi-Fi menu."
fi

battery_report 20
if pgrep -xq caffeinate; then say "caffeinate: running (left on)."; fi
