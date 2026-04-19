{ pkgs, ... }:
{
  home.packages = with pkgs; [
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
    bun
    nodejs
    python3
    python3Packages.pip
    uv
    podman-compose
    # 保留旧脚本里的 docker-compose 入口，实际委托给 podman-compose。
    (writeShellScriptBin "docker-compose" ''
      exec ${podman-compose}/bin/podman-compose "$@"
    '')
    age
    sops
    ssh-to-age
    gh
    zellij
  ];
}
