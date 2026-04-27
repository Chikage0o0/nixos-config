{ lib, ... }:
{
  platform.machine.class = lib.mkDefault "generic";
  platform.machine.wsl.enable = lib.mkDefault false;
}
