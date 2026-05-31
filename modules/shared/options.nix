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
      default = "26.05";
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

      gpu = {
        intel.enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 Intel GPU 的基础图形/视频驱动能力。AI/计算运行时由 ai-accelerated 叠加。";
        };

        amd.enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 AMD GPU 的基础图形/视频驱动能力。AI/计算运行时由 ai-accelerated 叠加。";
        };

        nvidia.enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 NVIDIA GPU 的基础图形/视频驱动能力。CUDA 等 AI/计算运行时由 ai-accelerated 叠加。";
        };
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

        ohMyOpenCodeSlimSettings = mkOption {
          type = types.attrs;
          default = { };
          description = "私库/主机对 oh-my-opencode-slim.json 的非机密覆盖。";
        };

        configFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "运行时生成的 OpenCode 配置文件路径，优先于 settings。";
        };
      };

      hermes = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 Hermes Agent 用户态 CLI、依赖和用户服务。";
        };

        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "Hermes Agent package；为 null 时使用官方 flake 的默认包。";
        };

        homeDir = mkOption {
          type = types.str;
          default = "%h/.hermes";
          description = "Hermes Agent 运行时配置目录，传给用户服务的 HERMES_HOME；支持 systemd %h 等 specifier。";
        };

        workspace = mkOption {
          type = types.str;
          default = "%h";
          description = "Hermes Agent gateway 用户服务工作目录，传给 WorkingDirectory；支持 systemd %h 等 specifier。";
        };

        extraPackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "追加安装到 Hermes 用户环境的额外包；默认依赖集合由 Hermes Home 模块固定提供。";
        };

        extraPythonPackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = ''
            追加到 Hermes 运行时 PYTHONPATH 的 Python 包。用于补充插件或平台适配器在 Nix
            不可变环境中无法运行时安装的依赖；包应来自对应 Python package set。
          '';
        };

        extraDependencyGroups = mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "feishu" ];
          description = ''
            追加构建 Hermes sealed Python venv 时启用的 pyproject dependency group。
            适合启用上游已定义但默认 lazy-install 的平台适配器依赖，例如 Feishu。
          '';
        };

        service = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "是否声明用户级 hermes-agent gateway 服务。";
          };

          extraArgs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "追加传给 `hermes gateway` 的命令行参数。";
          };
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
