{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform.machine;
in
{
  config = lib.mkMerge [
    (lib.mkIf cfg.powerProfiles.enable {
      services.power-profiles-daemon.enable = true;
    })

    (lib.mkIf cfg.brightness.enable {
      environment.systemPackages = [ pkgs.brightnessctl ];
    })
  ];
}
