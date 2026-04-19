{
  config,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
  emulateArchs = builtins.filter (system: system != pkgs.stdenv.hostPlatform.system) [
    "aarch64-linux"
    "x86_64-linux"
  ];
in
{
  boot.binfmt.emulatedSystems = emulateArchs;

  boot.loader.systemd-boot.enable = !cfg.isWSL;
  boot.loader.systemd-boot.configurationLimit = 6;
  boot.loader.efi.canTouchEfiVariables = !cfg.isWSL;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  zramSwap =
    if cfg.isWSL then
      {
        enable = false;
      }
    else
      {
        enable = true;
        memoryPercent = 50;
      };
  swapDevices =
    if cfg.isWSL then
      [ ]
    else
      [
        {
          device = "/var/lib/swapfile";
          size = 16 * 1024;
        }
      ];

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
