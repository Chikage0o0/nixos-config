{
  config,
  lib,
  ...
}:
let
  cfg = config.platform;
  isUEFI = cfg.machine.boot.mode == "uefi";
  isBIOS = cfg.machine.boot.mode == "bios";
in
{
  # 默认改用 GRUB，避免 systemd-boot 将多代内核直接写进 EFI 分区。
  # 传统 BIOS 的安装目标必须由主机显式声明，公共模块不猜测磁盘路径。
  boot.loader.grub = lib.mkMerge [
    {
      enable = !cfg.machine.wsl.enable;
    }
    (lib.mkIf (!cfg.machine.wsl.enable) {
      configurationLimit = 6;
    })
    (lib.mkIf (!cfg.machine.wsl.enable && isUEFI) {
      efiSupport = true;
      device = "nodev";
    })
    (lib.mkIf (!cfg.machine.wsl.enable && isBIOS && cfg.machine.boot.grubDevice != null) {
      devices = lib.mkForce [ cfg.machine.boot.grubDevice ];
    })
  ];

  boot.loader.efi.canTouchEfiVariables = !cfg.machine.wsl.enable && isUEFI;
}
