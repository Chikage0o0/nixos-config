{ lib, ... }:
{
  platform.machine.class = lib.mkDefault "server";
  platform.machine.wsl.enable = lib.mkDefault false;
  platform.services.openssh.enable = lib.mkDefault true;
  platform.services.cockpit.enable = lib.mkDefault false;
}
