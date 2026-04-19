{
  config,
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
}
