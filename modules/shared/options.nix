{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.platform = {
    profiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "当前 host 启用的 profile 名称列表。";
    };

    roles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "当前 host 启用的 role 名称列表。";
    };

    stateVersion = mkOption {
      type = types.str;
      default = "25.11";
      description = "NixOS 与 Home Manager 的 stateVersion。";
    };

    timezone = mkOption {
      type = types.str;
      default = "Asia/Shanghai";
      description = "系统时区。";
    };

    locale = mkOption {
      type = types.str;
      default = "zh_CN.UTF-8";
      description = "系统语言/区域设置。";
    };

    user = {
      name = mkOption {
        type = types.str;
        description = "主用户名。";
        example = "chikage";
      };

      fullName = mkOption {
        type = types.str;
        description = "用户全名，用于 Git 等用户态工具。";
        example = "Chikage";
      };

      email = mkOption {
        type = types.str;
        description = "用户邮箱，用于 Git 等用户态工具。";
        example = "user@example.com";
      };

      sshPublicKey = mkOption {
        type = types.str;
        description = "主用户 SSH 公钥。";
        example = "ssh-ed25519 AAAA... user@host";
      };
    };

    machine = {
      overseas = mkOption {
        type = types.bool;
        default = false;
        description = "是否为境外机器。启用后 nix 源与各语言包管理器均使用境外源。";
      };

      class = mkOption {
        type = types.enum [
          "wsl"
          "workstation"
          "server"
          "generic"
        ];
        default = "generic";
        description = "机器形态，不表达工具能力。";
      };

      wsl.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 WSL 机器形态约束。";
      };

      boot = {
        mode = mkOption {
          type = types.enum [
            "uefi"
            "bios"
          ];
          default = "uefi";
          description = "非 WSL 主机的 GRUB 启动模式。";
        };

        grubDevice = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "传统 BIOS 模式下 GRUB 的安装目标磁盘路径。";
          example = "/dev/disk/by-id/wwn-0x500001234567890a";
        };
      };

      nvidia.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 NVIDIA/CUDA 机器能力。";
      };

      powerProfiles.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用通用电源/性能档位切换。";
      };

      brightness.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否安装内置屏幕与标准背光设备亮度控制工具。";
      };
    };

    desktop = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用图形桌面环境。";
      };

      environment = mkOption {
        type = types.enum [ "plasma" ];
        default = "plasma";
        description = "桌面环境。第一版只支持 KDE Plasma。";
      };

      apps.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用日常完整桌面应用集、字体、输入法、应用分发工具，以及 Kitty/mpv Home Manager 配置。";
      };
    };

    nix.maxJobs = mkOption {
      type = types.either types.int (types.enum [ "auto" ]);
      default = "auto";
      description = "Nix 最大并行构建数。";
    };

    networking = {
      extraHosts = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "额外的 /etc/hosts 映射。";
      };

    };

    services = {
      openssh.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 OpenSSH。";
      };

      cockpit = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 Cockpit。";
        };

        extraOrigins = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "额外允许的 Cockpit Web origin。";
        };
      };
    };

    containers.podman.enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Podman 与 Docker CLI 兼容层。";
    };

    home = {
      git.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 Git 用户配置。";
      };

      shell.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 zsh、starship、direnv 与 SSH 用户配置。";
      };

      cliTools.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用现代 CLI 工具。";
      };

      sshAgent = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否启用会话级 OpenSSH agent 集成。";
        };

        sopsSecrets = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "登录后自动加载到 ssh-agent 的 sops secret 名称列表。";
        };
      };

      opencode = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 OpenCode 用户态配置。";
        };

        settings = mkOption {
          type = types.attrs;
          default = { };
          description = "OpenCode 非机密 settings 覆盖。";
        };

        configFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "运行时生成的 OpenCode 配置文件路径，优先于 settings。";
        };
      };
    };

    development = {
      fullstack.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用全栈开发工具包。";
      };
    };

    packages = {
      system.extra = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "额外系统包。";
      };

      home.extra = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "额外 Home Manager 用户包。";
      };
    };
  };
}
