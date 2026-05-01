{
  config,
  lib,
  ...
}:
let
  cfg = config.platform;
in
{
  networking.networkmanager.enable = lib.mkDefault (!cfg.machine.wsl.enable);
  networking.hosts = cfg.networking.extraHosts;
  time.timeZone = cfg.timezone;

  networking.firewall = {
    enable = lib.mkDefault (!cfg.machine.wsl.enable);
  };

  boot.kernel.sysctl = lib.optionalAttrs (!cfg.machine.wsl.enable) {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
