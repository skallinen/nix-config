# macbridge, the Mac half: lets the utm-arch VM ask this Mac for 1Password secrets
# and for Touch ID approval of sudo. Design and threat model:
# ~/common/projects/utm-arch/wiki/macbridge.md. Imported only for the Air (flake.nix),
# where the VM runs.
#
# Two launchd user agents:
#   macbridge         bb serving ~/.local/run/macbridge/bridge.sock (macbridge.clj)
#   macbridge-tunnel  ssh to the VM that forwards that socket to
#                     /home/sakalli/.local/run/macbridge.sock and 1Password's SSH
#                     agent to /home/sakalli/.1password/agent.sock
#
# Off switch: `launchctl bootout gui/$(id -u)/org.nixos.macbridge-tunnel` stops the
# VM reaching anything until the next login or switch; removing this module from
# flake.nix and switching removes it for good.
{ config, pkgs, lib, ... }:

let
  user = config.system.primaryUser;
  home = "/Users/${user}";
  vmHost = "192.168.64.7";     # same address as `Host utm` in shared-home.nix
  vmUser = "sakalli";
  bridgeSock = "${home}/.local/run/macbridge/bridge.sock";
  opAgentSock = "${home}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

  touchid-approve = pkgs.runCommandCC "touchid-approve" {
    nativeBuildInputs = [ pkgs.swift ];
  } ''
    mkdir -p $out/bin
    swiftc -O ${./touchid-approve.swift} -o $out/bin/touchid-approve
  '';

  # Vaults the VM may read, by name (matched without case). Only Sami's personal
  # vault ("Employee" in a 1Password Business account); the shared company vaults
  # are left out, and a client's vault is never listed. The file lives in the Nix
  # store so the VM cannot edit it through the shared home (D16).
  allow = pkgs.writeText "macbridge-allow.edn" ''
    {:vaults #{"Employee"}}
  '';

  tunnel = pkgs.writeShellScript "macbridge-tunnel" ''
    # Wait quietly while the VM is off, then hold one ssh connection. launchd
    # restarts this when ssh exits (VM reboot, Mac sleep, network change).
    until /usr/bin/nc -z -G 3 ${vmHost} 22 2>/dev/null; do sleep 15; done
    exec /usr/bin/ssh -N -F /dev/null \
      -i ${home}/.ssh/utm_ed25519 -o IdentitiesOnly=yes -o IdentityAgent=none \
      -o BatchMode=yes -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile=${home}/.ssh/known_hosts \
      -o ExitOnForwardFailure=yes -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
      -o ConnectTimeout=10 -o ForwardAgent=no -o ForwardX11=no -o LogLevel=ERROR \
      -R /home/${vmUser}/.local/run/macbridge.sock:${bridgeSock} \
      -R "/home/${vmUser}/.1password/agent.sock:${opAgentSock}" \
      ${vmUser}@${vmHost}
  '';
in
{
  launchd.user.agents.macbridge.serviceConfig = {
    ProgramArguments = [ "${pkgs.babashka}/bin/bb" "${./macbridge.clj}" ];
    EnvironmentVariables = {
      HOME = home;
      MACBRIDGE_SOCKET = bridgeSock;
      MACBRIDGE_OP = "${pkgs._1password-cli}/bin/op";
      MACBRIDGE_APPROVE = "${touchid-approve}/bin/touchid-approve";
      MACBRIDGE_ALLOW = "${allow}";
      MACBRIDGE_LOG = "${home}/Library/Logs/macbridge.log";
    };
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 10;
    ProcessType = "Interactive";
    StandardErrorPath = "${home}/Library/Logs/macbridge.err.log";
  };

  launchd.user.agents.macbridge-tunnel.serviceConfig = {
    ProgramArguments = [ "${tunnel}" ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 15;
    StandardErrorPath = "${home}/Library/Logs/macbridge-tunnel.log";
  };
}
