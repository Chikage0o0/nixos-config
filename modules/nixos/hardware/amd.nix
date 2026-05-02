{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.platform.machine.gpu.amd.enable {
    hardware.amdgpu.initrd.enable = true;
  };
}
