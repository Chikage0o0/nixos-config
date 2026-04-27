{ ... }:
{
  imports = [
    # 共享 options 定义（先临时接入，后续逐步迁移旧模块）
    ../shared/options.nix
    # 导入旧 options 定义
    ../../lib/options.nix
    # 功能模块
    ./base.nix
    ./network.nix
    ./users.nix
    ./virtualisation.nix
    ./packages.nix
    ./services/cockpit.nix
    ./services/dae.nix
    ./services/openssh.nix
    ./hardware/nvidia.nix
  ];
}
