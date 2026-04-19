# lib/options.nix
# 定义 myConfig 选项模块，用于替代原有的 varsExt
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.myConfig = {
    # 用户基础信息
    username = mkOption {
      type = types.str;
      description = "主用户名";
      example = "chikage";
    };

    userFullName = mkOption {
      type = types.str;
      description = "用户全名";
      example = "Chikage";
    };

    userEmail = mkOption {
      type = types.str;
      description = "用户邮箱";
      example = "user@example.com";
    };

    sshPublicKey = mkOption {
      type = types.str;
      description = "SSH 公钥";
      example = "ssh-ed25519 AAAA...";
    };

    # Nix 构建配置
    nixMaxJobs = mkOption {
      type = types.either types.int (types.enum [ "auto" ]);
      default = "auto";
      description = "Nix 最大并行构建数";
    };

    # 功能开关
    isWSL = mkOption {
      type = types.bool;
      default = false;
      description = "是否为 WSL 环境";
    };

    bootMode = mkOption {
      type = types.enum [
        "uefi"
        "bios"
      ];
      default = "uefi";
      description = "非 WSL 主机的 GRUB 启动模式";
      example = "bios";
    };

    grubDevice = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "传统 BIOS 模式下 GRUB 的安装目标磁盘路径";
      example = "/dev/disk/by-id/wwn-0x500001234567890a";
    };

    isNvidia = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 NVIDIA 显卡支持";
    };

    enableDae = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 dae 透明代理";
    };

    # 网络配置
    extraHosts = mkOption {
      type = types.attrsOf (types.listOf types.str);
      default = { };
      description = "额外的 hosts 映射";
      example = {
        "1.1.1.1" = [ "example.com" ];
      };
    };

    # dae 代理配置 (推荐通过 sops 提供完整配置文件)
    daeConfigFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "dae 完整配置文件路径";
      example = "/run/secrets/dae/config";
    };

    # Opencode 配置
    opencodeSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Opencode 自定义配置";
    };
  };
}
