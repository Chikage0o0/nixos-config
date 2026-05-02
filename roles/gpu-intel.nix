{ lib, ... }:
{
  platform.machine.gpu.intel.enable = lib.mkDefault true;
}
