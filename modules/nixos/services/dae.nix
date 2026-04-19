{
  config,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
in
{
  assertions = [
    {
      assertion = cfg.isWSL || (!cfg.enableDae) || (cfg.daeConfigFile != null);
      message = "启用 dae 时必须设置 myConfig.daeConfigFile。推荐将完整 dae 配置文件放入 sops secret，并把 /run/secrets 路径传给该选项。";
    }
  ];

  services.dae = {
    enable = (!cfg.isWSL) && cfg.enableDae;
    # dae 配置包含节点机密，必须直接读取运行时文件，避免写入 nix store。
    configFile = cfg.daeConfigFile;
    assets = [
      (pkgs.callPackage ../../../pkgs/v2ray-rules-dat { })
    ];
  };
}
