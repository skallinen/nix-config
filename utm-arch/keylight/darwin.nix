# keylight: a 14 px square in the top left corner of every screen that shows where the
# keystrokes go (utm-arch wiki/utm-input-and-keyboard.md, "Keylight"). Green: UTM is
# frontmost and has captured input, keys go to the VM. Blue: anything else, keys go to
# the Mac. The ErgoDox EZ leaving or returning gives a notification (and a sound when it
# leaves), no colour. Imported only for the Air (flake.nix), where the VM runs.
#
# Needs no permission grant: it reads the IORegistry and NSWorkspace only.
# Off switch: `launchctl bootout gui/$(id -u)/org.nixos.keylight` until the next login
# or switch; removing this module from flake.nix and switching removes it for good.
# Log: ~/Library/Logs/keylight.log, one line per state change.
{ config, pkgs, ... }:

let
  home = "/Users/${config.system.primaryUser}";
  keylight = pkgs.runCommandCC "keylight" {
    nativeBuildInputs = [ pkgs.swift ];
  } ''
    mkdir -p $out/bin
    swiftc -O ${./keylight.swift} -o $out/bin/keylight
  '';
in
{
  launchd.user.agents.keylight.serviceConfig = {
    ProgramArguments = [ "${keylight}/bin/keylight" ];
    RunAtLoad = true;
    KeepAlive = true;
    ThrottleInterval = 10;
    ProcessType = "Interactive";
    LimitLoadToSessionType = "Aqua";
    StandardOutPath = "${home}/Library/Logs/keylight.log";
    StandardErrorPath = "${home}/Library/Logs/keylight.log";
  };
}
