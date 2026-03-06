{
  pkgs,
  varsExt,
  ...
}:
{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.loader.systemd-boot.enable = !varsExt.isWSL;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.loader.efi.canTouchEfiVariables = !varsExt.isWSL;
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = varsExt.nixMaxJobs;
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
      varsExt.username
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
