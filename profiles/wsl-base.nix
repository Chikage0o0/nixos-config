{ lib, ... }:
{
  platform.machine.class = lib.mkDefault "wsl";
  platform.machine.wsl.enable = lib.mkDefault true;
  platform.services.openssh.enable = lib.mkDefault false;
  platform.services.cockpit.enable = lib.mkDefault false;
}
