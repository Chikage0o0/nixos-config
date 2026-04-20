{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
in
{
  config = lib.mkIf cfg.enableCockpit {
    # 当前主线系统仍锁在 stable，因此这里显式使用 flake 层替换后的 unstable Cockpit 模块与插件包。
    services.cockpit = {
      enable = true;
      openFirewall = true;
      package = pkgs.cockpit;
      plugins = [
        pkgs."cockpit-files"
        pkgs."cockpit-podman"
      ];
    };
  };
}
