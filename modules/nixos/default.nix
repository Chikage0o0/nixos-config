{ ... }:
{
  imports = [
    # 导入 options 定义
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
