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
    gopls
    gofumpt
    golangci-lint
    rustc
    cargo
    rust-analyzer
    rustfmt
    clippy
    gcc
    pkg-config
    # wayland-sys 等 Rust crate 通过 pkg-config 查找 wayland-client.pc。
    wayland
    nil
    nixfmt
    typescript
    eslint
    prettier
    # 当前 nixpkgs 输入未提供 vitest 包；用 Bun 保留项目本地优先的 vitest 命令入口。
    (writeShellScriptBin "vitest" ''
      exec ${bun}/bin/bun x vitest "$@"
    '')
    pyrefly
    sqlite
    postgresql
    just
    gnumake
    tokei
  ];
  fullstackPkgConfigPackages = with pkgs; [
    wayland
  ];
  fullstackDesktopPackages = with pkgs; [
    dbgate
    vscode
  ];
  containerPackages = with pkgs; [
    podman-compose
    (writeShellScriptBin "docker-compose" ''
      exec ${podman-compose}/bin/podman-compose "$@"
    '')
  ];
in
{
  home.sessionPath = lib.optionals cfg.development.fullstack.enable [
    "$HOME/.bun/bin"
    "$HOME/.local/bin"
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
  ];

  home.sessionVariables = lib.mkIf cfg.development.fullstack.enable {
    PKG_CONFIG_PATH = lib.makeSearchPathOutput "dev" "lib/pkgconfig" fullstackPkgConfigPackages;
  };

  home.packages =
    basePackages
    ++ lib.optionals cfg.development.fullstack.enable fullstackPackages
    ++ lib.optionals (
      cfg.development.fullstack.enable && cfg.desktop.enable && cfg.desktop.apps.enable
    ) fullstackDesktopPackages
    ++ lib.optionals cfg.containers.podman.enable containerPackages
    ++ cfg.packages.home.extra;
}
