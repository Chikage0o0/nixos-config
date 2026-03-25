{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    tree
    nixfmt
    nixd
    cachix
    devenv
    kmod
    usbutils
    openssl
  ];
}
