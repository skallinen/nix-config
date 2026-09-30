# The utm-arch VM's address on UTM's Shared network, from UTM's DHCP and stable across
# reboots (checked 2026-09-26). A new VM on a new Mac may get another one: change it
# here only. Read by shared-home.nix (`Host utm`) and utm-arch/macbridge/darwin.nix
# (the tunnel); utm-arch build/vm-settings.md says what else to run after a change.
"192.168.64.7"
