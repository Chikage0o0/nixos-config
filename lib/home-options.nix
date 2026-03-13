# lib/home-options.nix
# 定义 Home Manager 的 myConfig 选项模块
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

    # 路径配置
    configDir = mkOption {
      type = types.str;
      default = "~/nixos-config";
      description = "NixOS 配置目录路径";
    };

    sshKeysDir = mkOption {
      type = types.str;
      default = "~/nixos-config/ssh-keys";
      description = "SSH 私钥目录路径";
    };

    # Opencode 配置
    opencodeSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Opencode 自定义配置";
    };

    # 主机名 (用于 shell alias)
    hostName = mkOption {
      type = types.str;
      default = "dev-machine";
      description = "主机名";
    };
  };
}
