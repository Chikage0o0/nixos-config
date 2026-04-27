{
  config,
  pkgs,
  ...
}:
let
  cfg = config.platform;
in
{
  environment.systemPackages =
    with pkgs;
    [
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
    ]
    ++ cfg.packages.system.extra;
}
