# phone-connect: when Sami's Pixel is plugged into the Mac, the VM pulls its texts and
# call log at once (assistant repo bin/phone-pull.clj, wiki/phone-archive.md). Sami,
# 9.10.2026: "make a trigger that when the android is connected backup the messages and
# log data ... triggered automatically each time the phone is hooked to the laptop", and
# 21:46 the same evening: "the phone we always interact through the host mac". So the
# phone stays on the Mac's USB, adb runs here (android-tools in darwin-configuration.nix),
# and the pull itself runs in the VM, which reads the phone with `ssh mac adb ...`.
#
# A launchd user agent with an IOKit LaunchEvent: launchd starts it whenever a USB
# device with Google's vendor id (0x18D1 = 6353) appears, also once at load if the
# phone is already attached. Vendor only, not the product id: the Pixel's product id
# changes with its USB mode (charging, file transfer, debugging), and the VM side checks
# `adb devices` anyway. The job takes the event (usb-event.swift says why it must), then
# asks the VM to start phone-pull-connect.service (utm-home.nix) and returns; the pull
# runs there, waits up to 60 s for adb to see the phone, and pulls without the hourly
# throttle. If the VM is off or asleep the ssh fails and is logged; the VM's 15 minute
# phone-pull.timer catches up later.
#
# The ssh uses the Mac's key for the VM (~/.ssh/utm_ed25519, the macbridge tunnel's
# key, not in Nix), BatchMode, and the pinned host key in ~/.ssh/known_hosts.
# Log: ~/Library/Logs/phone-connect.log. Test without a replug:
#   launchctl kickstart gui/$(id -u)/org.nixos.phone-connect
# Off switch: `launchctl bootout gui/$(id -u)/org.nixos.phone-connect` until the next
# login or switch; removing this module from flake.nix and switching removes it for good.
{ config, pkgs, ... }:

let
  home = "/Users/${config.system.primaryUser}";
  vmHost = import ../vm-address.nix;
  usb-event = pkgs.runCommandCC "phone-usb-event" {
    nativeBuildInputs = [ pkgs.swift ];
  } ''
    mkdir -p $out/bin
    swiftc -O ${./usb-event.swift} -o $out/bin/phone-usb-event
  '';
  job = pkgs.writeShellScript "phone-connect" ''
    echo "$(/bin/date '+%F %T') start"
    ${usb-event}/bin/phone-usb-event
    /usr/bin/ssh -F /dev/null -i ${home}/.ssh/utm_ed25519 -o IdentitiesOnly=yes \
      -o IdentityAgent=none -o BatchMode=yes -o StrictHostKeyChecking=yes \
      -o UserKnownHostsFile=${home}/.ssh/known_hosts -o ConnectTimeout=10 \
      -o LogLevel=ERROR sakalli@${vmHost} \
      'systemctl --user start --no-block phone-pull-connect.service' \
      && echo "$(/bin/date '+%F %T') asked the VM to pull" \
      || echo "$(/bin/date '+%F %T') VM not reached; its 15 minute timer will pull"
  '';
in
{
  launchd.user.agents.phone-connect.serviceConfig = {
    ProgramArguments = [ "${job}" ];
    LaunchEvents."com.apple.iokit.matching"."google-usb-device" = {
      IOProviderClass = "IOUSBHostDevice";
      idVendor = 6353;
      IOMatchLaunchStream = true;
    };
    ThrottleInterval = 10;
    StandardOutPath = "${home}/Library/Logs/phone-connect.log";
    StandardErrorPath = "${home}/Library/Logs/phone-connect.log";
  };
}
