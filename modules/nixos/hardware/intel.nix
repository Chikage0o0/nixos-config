{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.platform.machine.gpu.intel.enable {
    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vpl-gpu-rt
    ];
  };
}
