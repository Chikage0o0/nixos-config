{ lib, ... }:
{
  platform.machine.gpu.nvidia.enable = lib.mkDefault true;
}
