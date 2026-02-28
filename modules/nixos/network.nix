{
  lib,
  vars,
  ...
}:
let
  netbirdActive = (!vars.isWSL) && vars.enableNetbird;
in
{
  networking.networkmanager.enable = !vars.isWSL;
  networking.hosts = vars.extraHosts or { };
  time.timeZone = "Asia/Shanghai";

  services.netbird.enable = netbirdActive;

  networking.firewall = {
    enable = !vars.isWSL;
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
