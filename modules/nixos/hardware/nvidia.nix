{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.platform.machine.gpu.nvidia.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

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

    environment.systemPackages = [ pkgs.linuxPackages.nvidia_x11 ];
  };
}
