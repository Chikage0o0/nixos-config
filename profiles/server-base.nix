{ lib, ... }:
let
  # 使用低于 role 默认值（lib.mkOverride 1000）的优先级，
  # 使 role 的 lib.mkDefault 能覆盖 profile 默认值。
  profileDefault = lib.mkOverride 1200;
in
{
  platform.machine.class = profileDefault "server";
  platform.machine.wsl.enable = profileDefault false;
  platform.services.openssh.enable = profileDefault true;
  platform.services.cockpit.enable = profileDefault false;
}
