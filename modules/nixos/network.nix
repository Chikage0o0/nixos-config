{
  config,
  lib,
  ...
}:
let
  cfg = config.myConfig;
in
{
  networking.networkmanager.enable = !cfg.isWSL;
  networking.hosts = cfg.extraHosts;
  time.timeZone = "Asia/Shanghai";

  networking.firewall = {
    enable = !cfg.isWSL;
  };

  boot.kernel.sysctl = lib.optionalAttrs (!cfg.isWSL) {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
