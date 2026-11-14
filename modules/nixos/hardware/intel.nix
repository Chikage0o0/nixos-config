{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.platform.machine.gpu.intel.enable {
    hardware.graphics.enable =
      lib.mkIf (!config.platform.machine.wsl.enable) (lib.mkDefault true);
    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vpl-gpu-rt
    ];
  };
}
