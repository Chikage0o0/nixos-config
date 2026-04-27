# lib/default.nix
# 导出库模块
{
  inputs,
  self,
}:
let
  platform = import ./platform { inherit inputs self; };
in
platform
// {
  inherit platform;

  # NixOS options 模块
  optionsModule = ./options.nix;

  # Home Manager options 模块
  homeOptionsModule = ./home-options.nix;
}
