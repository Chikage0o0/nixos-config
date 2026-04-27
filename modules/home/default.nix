{ ... }:
{
  imports = [
    # 共享 options 定义（先临时接入，后续逐步迁移旧模块）
    ../shared/options.nix
    # 导入旧 options 定义
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
