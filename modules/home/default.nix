{ ... }:
{
  imports = [
    # 导入 options 定义
    ../../lib/home-options.nix
    # 功能模块
    ./base.nix
    ./git.nix
    ./shell.nix
    ./cli-tools.nix
    ./opencode.nix
    ./packages.nix
  ];
}
