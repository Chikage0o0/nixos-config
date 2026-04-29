{
  config,
  lib,
  pkgsUnstable,
  ...
}:
let
  cfg = config.platform.services.cockpit;
  cockpitPort = toString config.services.cockpit.port;
  cockpitHostOrigin = "https://${config.networking.hostName}:${cockpitPort}";
  cockpitExtraOrigins = lib.unique (
    lib.optional (
      config.networking.hostName != "" && config.networking.hostName != "localhost"
    ) cockpitHostOrigin
    ++ cfg.extraOrigins
  );
in
{
  # Stable 25.11 的 Cockpit 模块尚未提供 plugins 选项；
  # 为了保留原有配置结构并确保真实 NixOS eval 通过，
  # 我们在本模块显式声明该选项，再将其包列表同步到
  # environment.systemPackages，使 Cockpit 能通过
  # /run/current-system/sw/share/cockpit 发现插件。
  options.services.cockpit.plugins = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "List of cockpit plugins.";
  };

  config = lib.mkIf cfg.enable {
    services.cockpit = {
      enable = true;
      openFirewall = true;
      package = pkgsUnstable.cockpit;
      plugins = [
        pkgsUnstable."cockpit-files"
        pkgsUnstable."cockpit-podman"
      ];

      # NixOS 上游默认只允许 localhost，会让用主机名或额外域名直连 9090 的浏览器握手失败。
      allowed-origins = cockpitExtraOrigins;
    };

    environment.systemPackages = config.services.cockpit.plugins;

    # 长期开着页面时，真正涨内存的是 HTTPS worker，对应上游的 system-cockpithttps.slice。
    systemd.slices."system-cockpithttps".sliceConfig = {
      MemoryHigh = "192M";
      MemoryMax = "256M";
    };
  };
}
