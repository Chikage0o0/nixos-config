{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.platform.machine.gpu.amd.enable {
    hardware.graphics.enable =
      lib.mkIf (!config.platform.machine.wsl.enable) (lib.mkDefault true);
    hardware.amdgpu.initrd.enable = true;
  };
}
