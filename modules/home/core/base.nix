{ config, ... }:
let
  cfg = config.platform;
in
{
  home.username = cfg.user.name;
  home.homeDirectory = "/home/${cfg.user.name}";
  home.stateVersion = cfg.stateVersion;
}
