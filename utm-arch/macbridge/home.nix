# macbridge, the VM half for sakalli (utm-arch wiki/macbridge.md): an `op` that asks
# the Mac, and ssh using the Mac's 1Password SSH agent. Both sockets arrive through
# the Mac's macbridge-tunnel; the root half (sudo by Touch ID, sshd's
# StreamLocalBindUnlink) is utm-arch build/macbridge-vm.sh.
{ config, pkgs, lib, ... }:

{
  home.packages = [
    (pkgs.writeShellScriptBin "op" ''
      exec ${pkgs.babashka}/bin/bb ${./op-shim.clj} "$@"
    '')
  ];

  # Unset if the bridge is down: ssh then says it cannot reach the agent and goes
  # on with key files.
  home.sessionVariables.SSH_AUTH_SOCK = "${config.home.homeDirectory}/.1password/agent.sock";

  # The forwarded sockets live here; 700 so no other user (agent) can reach them.
  home.activation.macbridgeDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run install -d -m 700 "$HOME/.local/run" "$HOME/.1password"
  '';
}
