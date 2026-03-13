{
  config,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
in
{
  services.dae = {
    enable = (!cfg.isWSL) && cfg.enableDae;
    configFile = pkgs.writeText "config.dae" (
      import ../../../dae/config.nix {
        nodes = cfg.daeNodes;
        subscriptions = cfg.daeSubscriptions;
      }
    );
    assets = [
      (pkgs.callPackage ../../../pkgs/v2ray-rules-dat/v2ray-rules-dat.nix { })
    ];
  };
}
