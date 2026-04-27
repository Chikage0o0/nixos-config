{ config, lib, ... }:
let
  cfg = config.platform;
in
{
  assertions = [
    {
      assertion =
        cfg.machine.wsl.enable || cfg.machine.boot.mode != "uefi" || cfg.machine.boot.grubDevice == null;
      message = "使用 UEFI 启动时不要设置 platform.machine.boot.grubDevice；GRUB 会以 EFI 方式安装并使用 device = \"nodev\"。";
    }
    {
      assertion =
        cfg.machine.wsl.enable || cfg.machine.boot.mode != "bios" || cfg.machine.boot.grubDevice != null;
      message = "使用传统 BIOS 启动时必须设置 platform.machine.boot.grubDevice，例如 /dev/disk/by-id/...。";
    }
    {
      assertion =
        !cfg.networking.transparentProxy.enable || cfg.networking.transparentProxy.configFile != null;
      message = "启用本机透明代理时必须设置 platform.networking.transparentProxy.configFile。";
    }
    {
      assertion = cfg.networking.transparentProxy.backend == "dae";
      message = "platform.networking.transparentProxy.backend 第一版只支持 dae。";
    }
    {
      assertion = !(cfg.machine.wsl.enable && cfg.machine.nvidia.enable);
      message = "WSL profile 不能启用 platform.machine.nvidia.enable；GPU/CUDA 能力只能用于非 WSL Linux 主机。";
    }
  ];
}
