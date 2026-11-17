{
  config,
  lib,
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
    # Nix 按缓存的 priority 而非列表顺序选择；显式覆盖服务端声明的优先级。
    substituters =
      lib.optionals (!cfg.machine.overseas) [
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10"
      ]
      ++ [
        "https://cache.nixos.org?priority=40"
        "https://nix-community.cachix.org?priority=50"
        "https://devenv.cachix.org?priority=60"
        "https://mic92.cachix.org?priority=60"
        "https://cache.numtide.com?priority=70"
      ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      "mic92.cachix.org-1:gi8IhgiT3CYZnJsaW7fxznzTkMUOn1RY4GmXdT/nXYQ="
    ];
    trusted-users = [
      "root"
      cfg.user.name
    ];
  };

  environment.enableAllTerminfo = true;

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries =
    with pkgs;
    [
      stdenv.cc.cc.lib
      zlib
      glib
      openssl
      curl
      icu
      libxml2
      libuuid
      ncurses
    ]
    # Playwright 等工具下载的 Chromium 不带 Nix store 的运行库搜索路径。
    ++ lib.optionals cfg.development.fullstack.enable [
      nspr
      nss
      atk
      at-spi2-atk
      at-spi2-core
      dbus
      cups
      expat
      libxcb
      libxkbcommon
      alsa-lib
      libgbm
      libX11
      libXext
      cairo
      pango
      libXcomposite
      libXdamage
      libXfixes
      libXrandr
    ];

  programs.zsh.enable = true;
  system.stateVersion = cfg.stateVersion;
}
