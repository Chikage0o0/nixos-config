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
    docker-compose
    age
    sops
    ssh-to-age
    gh
  ];
}
