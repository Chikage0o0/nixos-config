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
      assertion = !(cfg.machine.wsl.enable && cfg.machine.gpu.nvidia.enable);
      message = "WSL profile 不能启用 platform.machine.gpu.nvidia.enable；GPU/CUDA 能力只能用于非 WSL Linux 主机。";
    }
    {
      assertion =
        !(lib.elem "ai-accelerated" cfg.roles)
        || cfg.machine.gpu.intel.enable
        || cfg.machine.gpu.amd.enable
        || cfg.machine.gpu.nvidia.enable;
      message = "ai-accelerated 需要至少一个 GPU 厂商 role；请同时启用 gpu-intel、gpu-amd 或 gpu-nvidia。";
    }
    {
      assertion = !(cfg.machine.wsl.enable && cfg.desktop.enable);
      message = "WSL 主机不能启用 platform.desktop.enable；请关闭桌面配置或改用非 WSL profile。";
    }
    {
      assertion = !cfg.desktop.enable || cfg.desktop.environment == "plasma";
      message = "platform.desktop.environment 第一版只支持 plasma；请设置为 \"plasma\" 或关闭 platform.desktop.enable。";
    }
    {
      assertion = !cfg.desktop.apps.enable || cfg.desktop.enable;
      message = "platform.desktop.apps.enable 需要 platform.desktop.enable = true；请同时设置 platform.desktop.enable = true 或关闭 platform.desktop.apps.enable。";
    }
  ];
}
