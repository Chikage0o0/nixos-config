{
  config,
  pkgs,
  ...
}:
let
  cfg = config.platform;
  emulateArchs = builtins.filter (system: system != pkgs.stdenv.hostPlatform.system) [
    "aarch64-linux"
    "x86_64-linux"
  ];
in
{
  boot.binfmt.emulatedSystems = emulateArchs;
  boot.kernelPackages = pkgs.linuxPackages;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = cfg.nix.maxJobs;
    builders-use-substitutes = true;
    download-attempts = 2;
    connect-timeout = 5;
    substituters =
      if cfg.machine.overseas then
        [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://devenv.cachix.org"
        ]
      else
        [
          "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
          "https://devenv.cachix.org"
        ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
    trusted-users = [
      "root"
      cfg.user.name
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
  system.stateVersion = cfg.stateVersion;
}
