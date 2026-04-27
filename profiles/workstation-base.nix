{ lib, ... }:
{
  platform.machine.class = lib.mkDefault "workstation";
  platform.machine.wsl.enable = lib.mkDefault false;
  platform.services.openssh.enable = lib.mkDefault false;
  platform.services.cockpit.enable = lib.mkDefault false;
}
