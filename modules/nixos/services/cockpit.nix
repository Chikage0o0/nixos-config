{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
in
{
  config = lib.mkIf cfg.enableCockpit {
    services.cockpit = {
      enable = true;
      openFirewall = true;
      package = pkgs.cockpit;
      plugins = [
        pkgs."cockpit-files"
        pkgs."cockpit-podman"
      ];
    };
  };
}
