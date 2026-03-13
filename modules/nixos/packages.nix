{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    nixfmt
    nixd
    cachix
    devenv
    kmod
    usbutils
  ];
}
