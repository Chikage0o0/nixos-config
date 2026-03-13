# lib/default.nix
# 导出库模块
{
  # NixOS options 模块
  optionsModule = ./options.nix;

  # Home Manager options 模块
  homeOptionsModule = ./home-options.nix;
}
