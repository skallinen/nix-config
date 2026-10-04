# Shared helpers for walk-go and walk-home (sourced, not run).
# walk-and-talk wiki/walk-server.md, "Laptop in a bag".

VAULT=2.29.9.207          # assistant-vault, the away rendezvous
HOME_GW=192.168.10.1      # the home router; a default route through it means home Wi-Fi
CONF_DIR="$HOME/.config/walk"

say()  { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*"; }

# The Wi-Fi device (en0 on the Air), found by name rather than assumed.
wifi_dev() {
  networksetup -listallhardwareports |
    awk '/^Hardware Port: (Wi-Fi|AirPort)$/ { getline; print $2; exit }'
}

gateway() { route -n get default 2>/dev/null | awk '/gateway:/ { print $2 }'; }

sleep_disabled() { pmset -g | awk '/SleepDisabled/ { print $2 }' | grep -qx 1; }

battery_report() {
  local line pct
  line=$(pmset -g batt)
  pct=$(printf '%s\n' "$line" | grep -Eo '[0-9]+%' | head -n1 | tr -d %)
  if printf '%s\n' "$line" | grep -q "AC Power"; then
    say "Battery: ${pct:-?} %, on charger."
  else
    say "Battery: ${pct:-?} %, on battery."
  fi
  if [ -n "$pct" ] && [ "$pct" -lt "${1:-0}" ]; then
    warn "battery below ${1} %. Charge first or keep the walk short."
  fi
}

vault_reachable() { nc -z -G 5 "$VAULT" 22 >/dev/null 2>&1; }

# The VM's reverse tunnel to the vault (systemd user unit in utm-home.nix).
vm() { ssh -o BatchMode=yes -o ConnectTimeout=5 utm "$@" 2>/dev/null; }
tunnel_state() { vm systemctl --user is-active walk-vault-tunnel || echo "unknown (VM not reachable)"; }

# Wait up to $1 seconds for a default route whose gateway is not empty.
wait_for_route() {
  local i
  for i in $(seq 1 "$1"); do
    [ -n "$(gateway)" ] && return 0
    sleep 1
  done
  return 1
}
