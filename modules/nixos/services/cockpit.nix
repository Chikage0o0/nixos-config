{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
  cockpitPort = toString config.services.cockpit.port;
  cockpitHostOrigin = "https://${config.networking.hostName}:${cockpitPort}";
  cockpitExtraOrigins = lib.unique (
    lib.optional (config.networking.hostName != "" && config.networking.hostName != "localhost") cockpitHostOrigin
    ++ cfg.cockpitExtraOrigins
  );
in
{
  config = lib.mkIf cfg.enableCockpit {
    services.cockpit = {
      enable = true;
      openFirewall = true;
      package = pkgs.cockpit;
      plugins = [
        pkgs."cockpit-files"
        pkgs."cockpit-podman"
      ];

      # NixOS 上游默认只允许 localhost，会让用主机名或额外域名直连 9090 的浏览器握手失败。
      allowed-origins = cockpitExtraOrigins;
    };

    # 长期开着页面时，真正涨内存的是 HTTPS worker，对应上游的 system-cockpithttps.slice。
    systemd.slices."system-cockpithttps".sliceConfig = {
      MemoryHigh = "192M";
      MemoryMax = "256M";
    };
  };
}
