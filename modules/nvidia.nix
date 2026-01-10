{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.hardware.nvidia.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "是否启用 NVIDIA 显卡支持";
  };

  config = lib.mkIf config.hardware.nvidia.enable {
    # 允许安装闭源软件(NVIDIA 驱动、CUDA 等)
    nixpkgs.config.allowUnfree = true;

    # X Server 配置(无桌面环境,仅加载 NVIDIA 驱动)
    services.xserver = {
      enable = false;
      videoDrivers = [ "nvidia" ];
    };

    # 图形硬件加速支持
    hardware.graphics = {
      enable = true;
      enable32Bit = true; # 启用 32 位图形库支持
    };

    # NVIDIA 驱动配置
    hardware.nvidia = {
      open = false; # 使用闭源驱动(开源驱动功能有限)
      nvidiaSettings = false; # 禁用 nvidia-settings GUI 工具
      package = config.boot.kernelPackages.nvidiaPackages.production; # 使用生产版驱动

      nvidiaPersistenced = false; # 禁用持久化守护进程
      powerManagement = {
        enable = true; # 启用电源管理
        finegrained = false; # 单 GPU 系统使用粗粒度电源管理
      };
    };

    # NVIDIA 与 CUDA 相关软件包
    environment.systemPackages = with pkgs; [
      cudatoolkit
      linuxPackages.nvidia_x11
    ];
  };
}
