{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.orca-server;
  user = config.users.users.${cfg.user} or null;
  home = if user != null then user.home else "";
in
{
  options.services.orca-server = {
    enable = lib.mkEnableOption "Orca 常驻服务";

    package = lib.mkOption {
      type = lib.types.package;
      description = "提供 bin/orca 的完整 Orca 包，由调用方注入。";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.platform.user.name;
      defaultText = lib.literalExpression "config.platform.user.name";
      description = "运行 Orca 的已声明非 root 用户，复用其 home 和配置。";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6768;
      description = "Orca 服务监听端口；模块不开放防火墙。";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    assertions = [
      {
        assertion = cfg.user != "root" && user != null && user.uid != 0 && home != "" && home != "/";
        message = "services.orca-server.user 必须是已声明、有独立 home 的非 root 用户。";
      }
    ];

    systemd.services.orca-server = {
      description = "Orca server";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      unitConfig.RequiresMountsFor = [ home ];
      startLimitIntervalSec = 60;
      startLimitBurst = 5;
      # 系统单元不读取交互 shell；仅加入静态路径，不复制登录环境或机密。
      path = [
        cfg.package
        pkgs.git
        pkgs.openssh
        "${home}/.nix-profile"
        "/etc/profiles/per-user/${cfg.user}"
        "/run/current-system/sw"
        "${home}/.local"
      ];

      environment = {
        HOME = home;
        ORCA_USER_DATA_PATH = "${home}/.orca";
      };

      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = home;
        # 官方推荐 supervisor；禁用自动配对输出，避免含 token 的链接进入 journal。
        ExecStart = "${cfg.package}/bin/orca serve --supervise --no-pairing --port ${toString cfg.port}";
        KillMode = "mixed";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # 不自动开放防火墙，也不改变 Orca 的认证或沙箱行为。
  };
}
