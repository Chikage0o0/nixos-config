{ lib, ... }:
{
  platform.machine.nvidia.enable = lib.mkDefault true;
}
