{
  pkgs,
  varsExt,
  ...
}:
{
  services.dae = {
    enable = (!varsExt.isWSL) && varsExt.enableDae;
    configFile = pkgs.writeText "config.dae" (
      import ../../../dae/config.nix {
        nodes = varsExt.daeNodes;
        subscriptions = varsExt.daeSubscriptions;
      }
    );
    assets = [
      (pkgs.callPackage ../../../pkgs/v2ray-rules-dat/v2ray-rules-dat.nix { })
    ];
  };
}
