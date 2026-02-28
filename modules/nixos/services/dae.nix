{
  pkgs,
  vars,
  ...
}:
{
  services.dae = {
    enable = (!vars.isWSL) && vars.enableDae;
    configFile = pkgs.writeText "config.dae" (
      import ../../../dae/config.nix {
        nodes = vars.daeNodes;
        subscriptions = vars.daeSubscriptions;
      }
    );
    assets = [
      (pkgs.callPackage ../../../pkgs/v2ray-rules-dat/v2ray-rules-dat.nix { })
    ];
  };
}
