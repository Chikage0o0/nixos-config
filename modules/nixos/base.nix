{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
  emulateArchs = builtins.filter (system: system != pkgs.stdenv.hostPlatform.system) [
    "aarch64-linux"
    "x86_64-linux"
  ];
  isUEFI = cfg.bootMode == "uefi";
  isBIOS = cfg.bootMode == "bios";
in
{
  boot.binfmt.emulatedSystems = emulateArchs;

  # 默认改用 GRUB，避免 systemd-boot 将多代内核直接写进 EFI 分区。
  # 传统 BIOS 的安装目标必须由主机显式声明，公共模块不猜测磁盘路径。
  boot.loader.grub = lib.mkMerge [
    {
      enable = !cfg.isWSL;
    }
    (lib.mkIf (!cfg.isWSL) {
      configurationLimit = 6;
    })
    (lib.mkIf (!cfg.isWSL && isUEFI) {
      efiSupport = true;
      device = "nodev";
    })
    (lib.mkIf (!cfg.isWSL && isBIOS && cfg.grubDevice != null) {
      devices = lib.mkForce [ cfg.grubDevice ];
    })
  ];
  boot.loader.efi.canTouchEfiVariables = !cfg.isWSL && isUEFI;

  assertions = lib.optionals (!cfg.isWSL) [
    {
      assertion = cfg.bootMode != "uefi" || cfg.grubDevice == null;
      message = "使用 UEFI 启动时不要设置 myConfig.grubDevice；GRUB 会以 EFI 方式安装并使用 device = \"nodev\"。";
    }
    {
      assertion = cfg.bootMode != "bios" || cfg.grubDevice != null;
      message = "使用传统 BIOS 启动时必须设置 myConfig.grubDevice，例如 /dev/disk/by-id/...。";
    }
  ];

  # OpenZFS 等内核外模块通常滞后最新内核；默认使用 nixpkgs 支持最完整的内核线。
  boot.kernelPackages = pkgs.linuxPackages;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = cfg.nixMaxJobs;
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
    trusted-users = [
      "root"
      cfg.username
    ];
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glib
    openssl
    curl
    icu
    libxml2
    libuuid
    ncurses
  ];

  programs.zsh.enable = true;
  system.stateVersion = "25.11";
}
