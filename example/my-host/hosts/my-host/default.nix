# example/my-host/hosts/my-host/default.nix
# my-host 主机配置
# 这是一个 WSL 环境的示例配置，物理机配置请参考 README 中的高级用法
{
  config,
  lib,
  inputs,
  hostname,
  ...
}:
let
  # 在 let 中定义功能开关，避免在 imports 中引用 config（会导致无限递归）
  isWSL = true;
  isNvidia = false;
in
{
  # ─── 模块导入 ───
  # 根据 isWSL 条件导入 WSL 模块或硬件配置
  imports =
    [ ]
    ++ lib.optionals isWSL [ inputs.nixos-wsl.nixosModules.default ]
    ++ (if isWSL then [ ] else [ ./hardware-configuration.nix ]);

  # ─── 主机标识 ───
  networking.hostName = hostname;

  # ─── 用户与功能配置 ───
  # myConfig 由公共模块库定义，所有选项见 README 配置参考
  myConfig = {
    # 必填：用户基础信息
    username = "your_username";
    userFullName = "Your Name";
    userEmail = "your@email.com";
    sshPublicKey = "ssh-ed25519 AAAA... user@host";

    # Nix 构建并行度，"auto" 或具体数字
    nixMaxJobs = 4;

    # 功能开关（需与上方 let 变量保持一致）
    isWSL = isWSL;
    # WSL 会忽略启动器设置；物理机默认按 UEFI + GRUB 处理
    bootMode = "uefi";
    # 仅传统 BIOS 主机需要填写，建议使用 /dev/disk/by-id/... 这类稳定路径
    grubDevice = null;
    isNvidia = isNvidia;
    enableDae = false;

    # 额外的 /etc/hosts 映射，按需填写
    extraHosts = { };
  };

  # ─── WSL 特定配置 ───
  # 仅 WSL 环境生效
  wsl = lib.mkIf isWSL {
    enable = true;
    defaultUser = config.myConfig.username;
    interop.register = true;
  };

  # ─── sops 机密管理 ───
  # 机密文件使用 age 加密，明文永远不进入 git 或 nix store
  sops = {
    # 每台主机的 secrets.yaml 存放在对应主机目录下
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/home/${config.myConfig.username}/.config/sops/age/keys.txt";

    secrets = {
      # 用户登录密码（hashed password，用 mkpasswd 生成）
      "user/hashedPassword" = {
        neededForUsers = true;
      };

      # OpenCode API 密钥
      "opencode/apiKey" = { };

      # SSH 私钥（权限设为仅用户可读）
      "ssh_private_key" = {
        owner = config.myConfig.username;
        mode = "0400";
      };
    };
  };

  # 将 sops 解密后的密码文件设为用户密码
  users.users.${config.myConfig.username}.hashedPasswordFile =
    config.sops.secrets."user/hashedPassword".path;

  # ─── OpenCode 配置模板 ───
  # 将 opencode-config.template.json 中的 __OPENCODE_API_KEY__ 占位符
  # 替换为 sops 解密后的真实 API 密钥，生成运行时配置文件
  sops.templates."opencode-config.json" = {
    owner = config.myConfig.username;
    mode = "0400";
    content = builtins.toJSON (
      lib.recursiveUpdate
        (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json"))
        (
          builtins.fromJSON (
            builtins.replaceStrings [ "__OPENCODE_API_KEY__" ] [ config.sops.placeholder."opencode/apiKey" ] (
              builtins.readFile ../opencode-config.template.json
            )
          )
        )
    );
  };

  # ─── Home Manager 配置 ───
  # 导入公共模块库的 Home Manager 模块，并传递用户配置
  home-manager.users.${config.myConfig.username} = {
    imports = [ inputs.nixos-config-public.homeModules.default ];

    myConfig = {
      inherit (config.myConfig)
        username
        userFullName
        userEmail
        sshPublicKey
        ;
      # 指向 sops 生成的 OpenCode 配置文件
      opencodeConfigFile = config.sops.templates."opencode-config.json".path;
      # 要自动加载到 ssh-agent 的 sops secret 名称
      sshSopsSecrets = [ "ssh_private_key" ];
    };
  };
}
