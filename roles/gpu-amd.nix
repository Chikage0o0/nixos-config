{ lib, ... }:
{
  platform.machine.gpu.amd.enable = lib.mkDefault true;
}
