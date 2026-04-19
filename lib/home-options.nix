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

    sshSopsSecrets = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "要加载的 sops secret 名称列表，会自动从 /run/secrets/<name> 加载";
      example = [
        "ssh_private_key"
        "github_deploy_key"
      ];
    };

    # Opencode 配置
    opencodeSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Opencode 自定义配置";
    };

    opencodeConfigFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "运行时生成的 Opencode 配置文件路径；设置后优先使用该文件，避免将机密写入 Nix store";
    };

    # SSH Agent 配置
    enableSshAgent = mkOption {
      type = types.bool;
      default = true;
      description = "是否自动启动 ssh-agent 并加载私钥";
    };
  };
}
