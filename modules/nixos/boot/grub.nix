{
  config,
  lib,
  ...
}:
let
  cfg = config.platform;
  isUEFI = cfg.machine.boot.mode == "uefi";
  isBIOS = cfg.machine.boot.mode == "bios";
  useGrub = !cfg.machine.wsl.enable && (isUEFI || isBIOS);
  useExtlinux = !cfg.machine.wsl.enable && cfg.machine.boot.mode == "extlinux";
in
{
  # UEFI/BIOS 使用 GRUB，避免 systemd-boot 将多代内核直接写进 EFI 分区。
  # 传统 BIOS 的安装目标必须由主机显式声明，公共模块不猜测磁盘路径。
  boot.loader.grub = lib.mkMerge [
    {
      enable = useGrub;
    }
    (lib.mkIf useGrub {
      configurationLimit = 6;
    })
    (lib.mkIf (useGrub && isUEFI) {
      efiSupport = true;
      device = "nodev";
    })
    (lib.mkIf (useGrub && isBIOS && cfg.machine.boot.grubDevice != null) {
      devices = lib.mkForce [ cfg.machine.boot.grubDevice ];
    })
  ];

  boot.loader.generic-extlinux-compatible.enable = useExtlinux;
  boot.loader.systemd-boot.enable = lib.mkIf useExtlinux false;
  boot.loader.efi.canTouchEfiVariables = !cfg.machine.wsl.enable && isUEFI;
}
