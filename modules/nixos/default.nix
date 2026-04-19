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
    ./services/dae.nix
    ./services/openssh.nix
    ./hardware/nvidia.nix
  ];

  # 自动注册 overlay（rtk、opencode、v2ray-rules-dat）
  nixpkgs.overlays = [
    (final: prev: {
      v2ray-rules-dat = final.callPackage ../../pkgs/v2ray-rules-dat { };
      opencode = final.callPackage ../../pkgs/opencode { };
      rtk = final.callPackage ../../pkgs/rtk { };
    })
  ];
}
