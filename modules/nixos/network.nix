{
  config,
  lib,
  ...
}:
let
  cfg = config.myConfig;
  netbirdActive = (!cfg.isWSL) && cfg.enableNetbird;
in
{
  networking.networkmanager.enable = !cfg.isWSL;
  networking.hosts = cfg.extraHosts;
  time.timeZone = "Asia/Shanghai";

  services.netbird.enable = netbirdActive;

  networking.firewall = {
    enable = !cfg.isWSL;
    allowedUDPPorts =
      if netbirdActive then
        [
          3478
          51820
        ]
      else
        [ ];
    trustedInterfaces = if netbirdActive then [ "wt0" ] else [ ];
  };
}
