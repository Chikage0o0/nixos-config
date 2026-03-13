{ config, ... }:
let
  cfg = config.myConfig;
in
{
  home.username = cfg.username;
  home.homeDirectory = "/home/${cfg.username}";
  home.stateVersion = "25.11";
}
