{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform.networking.transparentProxy;
in
{
  services.dae = lib.mkIf (!config.platform.machine.wsl.enable && cfg.enable) {
    enable = true;
    # dae 配置包含节点机密，必须直接读取运行时文件，避免写入 nix store。
    configFile = cfg.configFile;
    assets = [ pkgs.v2ray-rules-dat ];
  };
}
