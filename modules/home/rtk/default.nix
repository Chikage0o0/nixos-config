{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
  rtkPackage = if cfg.home.rtk.package != null then cfg.home.rtk.package else pkgs.rtk;
in
{
  config = lib.mkIf cfg.home.rtk.enable {
    home.packages = [ rtkPackage ];
  };
}
