{ config, lib, ... }:
{
  platform.services.openssh.enable = lib.mkDefault true;
  platform.services.cockpit.enable = lib.mkDefault (!config.platform.machine.wsl.enable);
}
