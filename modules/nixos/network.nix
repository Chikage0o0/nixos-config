{
  lib,
  varsExt,
  ...
}:
let
  netbirdActive = (!varsExt.isWSL) && varsExt.enableNetbird;
in
{
  networking.networkmanager.enable = !varsExt.isWSL;
  networking.hosts = varsExt.extraHosts;
  time.timeZone = "Asia/Shanghai";

  services.netbird.enable = netbirdActive;

  networking.firewall = {
    enable = !varsExt.isWSL;
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
