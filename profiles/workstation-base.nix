{ lib, ... }:
let
  # 使用低于 role 默认值（lib.mkOverride 1000）的优先级，
  # 使 role 的 lib.mkDefault 能覆盖 profile 默认值。
  profileDefault = lib.mkOverride 1200;
in
{
  imports = [ ../modules/nixos/hardware/workstation.nix ];

  platform.machine.class = profileDefault "workstation";
  platform.machine.wsl.enable = profileDefault false;
  platform.desktop.enable = profileDefault true;
  platform.desktop.environment = profileDefault "plasma";
  platform.desktop.apps.enable = profileDefault true;
  platform.services.openssh.enable = profileDefault false;
  platform.services.cockpit.enable = profileDefault false;
  platform.machine.powerProfiles.enable = profileDefault true;
  platform.machine.brightness.enable = profileDefault true;
  time.hardwareClockInLocalTime = profileDefault true;
}
