{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
in
{
  options.hardware.nvidia.enable = lib.mkOption {
    type = lib.types.bool;
    default = (!cfg.isWSL) && cfg.isNvidia;
    description = "是否启用 NVIDIA 显卡支持";
  };

  config = lib.mkIf config.hardware.nvidia.enable {
    services.xserver = {
      enable = false;
      videoDrivers = [ "nvidia" ];
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.nvidia-container-toolkit.enable = true;

    hardware.nvidia = {
      open = false;
      nvidiaSettings = false;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      nvidiaPersistenced = false;
      powerManagement = {
        enable = true;
        finegrained = false;
      };
    };

    environment.systemPackages = with pkgs; [
      cudatoolkit
      linuxPackages.nvidia_x11
    ];
  };
}
