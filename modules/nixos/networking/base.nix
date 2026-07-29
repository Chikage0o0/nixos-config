{
  config,
  lib,
  ...
}:
let
  cfg = config.platform;
  commonSysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_mtu_probing" = 1;
  };
  domesticSysctl = {
    "net.ipv4.tcp_notsent_lowat" = 131072;
  };
  overseasSysctl = {
    # 32MiB 是高 BDP 场景的上限，并非预分配。
    "net.core.rmem_max" = 33554432;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.tcp_rmem" = "4096 131072 33554432";
    "net.ipv4.tcp_wmem" = "4096 16384 33554432";
  };
  isServer = cfg.machine.class == "server";
in
{
  networking.networkmanager.enable = lib.mkDefault (!cfg.machine.wsl.enable);
  networking.hosts = cfg.networking.extraHosts;
  time.timeZone = cfg.timezone;

  networking.firewall = {
    enable = lib.mkDefault (!cfg.machine.wsl.enable);
  };

  boot.kernel.sysctl = lib.optionalAttrs (!cfg.machine.wsl.enable) (
    commonSysctl
    // lib.optionalAttrs (isServer && !cfg.machine.overseas) domesticSysctl
    // lib.optionalAttrs (isServer && cfg.machine.overseas) overseasSysctl
  );
}
