# walk-go: get the Air ready to ride closed in a bag during a walk-and-talk session,
# online through the phone's hotspot. Run it at home before leaving.
#   walk-go            uses the hotspot name saved in ~/.config/walk/hotspot-ssid
#   walk-go "NAME"     uses NAME and saves it for next time
# Undo with walk-home. walk-and-talk wiki/walk-server.md, "Laptop in a bag".
set -u
. @lib@

ssid_file="$CONF_DIR/hotspot-ssid"
ssid="${1:-}"
if [ -n "$ssid" ]; then
  mkdir -p "$CONF_DIR" && printf '%s\n' "$ssid" > "$ssid_file"
elif [ -r "$ssid_file" ]; then
  ssid=$(head -n1 "$ssid_file")
fi

# 1. Lid sleep off, so closing the lid does not freeze the VM. sudo asks for a
#    fingerprint through 1Password.
say "Turning lid sleep off (sudo asks for your fingerprint)."
sudo pmset -a disablesleep 1
if sleep_disabled; then
  say "Lid sleep: off. Closing the lid is safe."
else
  warn "lid sleep is still on. Do not close the lid."
fi

# 2. caffeinate stops idle sleep. Start one if none is running.
if pgrep -xq caffeinate; then
  say "caffeinate: running."
else
  nohup caffeinate -i >/dev/null 2>&1 &
  disown
  say "caffeinate: started."
fi

# 3. Battery.
battery_report 50

# 4. Hotspot.
dev=$(wifi_dev)
joined=no
if [ -z "$dev" ]; then
  warn "no Wi-Fi device found."
elif [ -z "$ssid" ]; then
  say "Turn on the phone hotspot."
  say "Hotspot name not saved. Next time run: walk-go \"HOTSPOT NAME\""
else
  say "Turn on the phone hotspot ($ssid)."
  if networksetup -listpreferredwirelessnetworks "$dev" | sed 's/^[[:space:]]*//' | grep -Fxq "$ssid"; then
    read -r -p "Press Enter when the hotspot is on (or type s to skip): " ans
    if [ "${ans:-}" != s ]; then
      for try in 1 2 3 4 5 6; do
        out=$(networksetup -setairportnetwork "$dev" "$ssid" 2>&1)
        if [ -z "$out" ]; then joined=yes; break; fi
        sleep 5
      done
      if [ "$joined" = yes ]; then
        say "Joined $ssid."
        wait_for_route 20 || warn "no network route yet."
      else
        warn "could not join $ssid: $out"
        say "Join it from the Wi-Fi menu, then run walk-go again."
      fi
    fi
  else
    say "$ssid is not a known network on this Mac."
    say "Join it once from the Wi-Fi menu, then run walk-go again."
  fi
fi

# 5. Does the away route work from here?
gw=$(gateway)
if [ "$gw" = "$HOME_GW" ]; then
  say "Network: home Wi-Fi."
elif [ -n "$gw" ]; then
  say "Network: not home Wi-Fi (gateway $gw)."
else
  say "Network: none."
fi

if [ "$joined" = yes ]; then
  # The tunnel's old connection died with the network switch; restart it now
  # instead of waiting up to two minutes for it to notice.
  vm systemctl --user restart walk-vault-tunnel
  sleep 5
fi

if vault_reachable; then vault=yes; say "Internet: vault reachable."
else vault=no; say "Internet: vault NOT reachable."; fi
tunnel=$(tunnel_state)
say "VM tunnel (walk-vault-tunnel): $tunnel"

if sleep_disabled && [ "$vault" = yes ] && [ "$tunnel" = active ]; then
  if [ "$gw" = "$HOME_GW" ]; then
    say "Ready, but still on home Wi-Fi. Leaving moves the Mac to the hotspot only if it auto-joins; join the hotspot before you go."
  else
    say "Ready. The walk route should work. Close the lid and go."
  fi
else
  say "Not ready. The walk route will probably fail; fix the lines above first."
fi
say "The Air is fanless: leave the bag open a little, out of the sun."
