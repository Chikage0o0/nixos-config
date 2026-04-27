{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
  basePackages = with pkgs; [
    ripgrep
    fd
    btop
    jq
    tldr
    curl
    wget
    zip
    unzip
    xz
    age
    sops
    ssh-to-age
    gh
    zellij
    bun
    nodejs
    python3
    python3Packages.pip
    uv
  ];
  fullstackPackages = with pkgs; [
    go
    rustc
    cargo
    sqlite
    postgresql
    just
    gnumake
  ];
  containerPackages = with pkgs; [
    podman-compose
    (writeShellScriptBin "docker-compose" ''
      exec ${podman-compose}/bin/podman-compose "$@"
    '')
  ];
in
{
  home.packages =
    basePackages
    ++ lib.optionals cfg.development.fullstack.enable fullstackPackages
    ++ lib.optionals cfg.containers.podman.enable containerPackages
    ++ cfg.packages.home.extra;
}
