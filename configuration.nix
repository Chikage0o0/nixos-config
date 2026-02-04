{
  config,
  pkgs,
  vars,
  ...
}:

{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./modules/nvidia.nix
  ];

  # ============================================================
  # 硬件特性开关
  # ============================================================
  # 是否启用 NVIDIA 显卡支持
  hardware.nvidia.enable = vars.isNvidia;

  # ============================================================
  # 1. 引导与内核配置
  # ============================================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 3; # 限制 EFI 分区中保留的引导条目数量
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_18; # 使用较新内核以获得更好的硬件支持

  # ============================================================
  # 2. 网络与时区配置
  # ============================================================
  networking.hostName = "dev-machine";
  networking.networkmanager.enable = true;
  # 添加自定义 Hosts 映射
  networking.hosts = vars.extraHosts or { };
  time.timeZone = "Asia/Shanghai";

  # NetBird VPN 配置
  services.netbird.enable = vars.enableNetbird;

  # 防火墙配置
  networking.firewall = {
    enable = true;
    # NetBird 所需端口
    allowedUDPPorts = [
      3478 # STUN 端口(用于 NAT 穿透)
      51820 # WireGuard 端口(NetBird 使用的 VPN 协议)
    ];
    # 如需开放其他 TCP 端口，可在此添加
    # allowedTCPPorts = [ ];

    # 信任 NetBird VPN 网卡，允许 VPN 内部流量
    trustedInterfaces = [ "wt0" ];
  };

  # ============================================================
  # 3. Nix 包管理器配置
  # ============================================================
  nix.settings = {
    # 启用实验性功能:Nix 命令和 Flakes 支持
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # 配置国内镜像源以加速下载
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
    trusted-users = [
      "root"
      vars.username
    ];
  };

  # ============================================================
  # 4. 用户账户配置
  # ============================================================
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.userFullName;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    initialPassword = vars.initialPassword; # ⚠️ 首次部署后请使用 `passwd` 命令修改密码
    openssh.authorizedKeys.keys = [
      vars.sshPublicKey
    ];
  };

  # ============================================================
  # 5. Sudo 权限配置
  # ============================================================
  security.sudo.extraRules = [
    {
      users = [ vars.username ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ]; # 允许该用户执行 sudo 命令时无需密码
        }
      ];
    }
  ];

  # ============================================================
  # 6. 虚拟化与容器化
  # ============================================================
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      # Docker 镜像源配置(如需配置国内镜像可在此添加)
    };
  };

  # ============================================================
  # 7. 开发环境配置
  # ============================================================
  # Nix-ld: 允许运行非 Nix 打包的二进制文件(如 VSCode Server、某些 pip 包)
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glib
    openssl
    curl
    icu
    libxml2
    libuuid
    ncurses
  ];

  # 启用 Zsh Shell
  programs.zsh.enable = true;

  # ============================================================
  # 8. 系统软件包
  # ============================================================
  environment.systemPackages = with pkgs; [
    # 基础工具
    vim
    wget
    curl
    git
    # Nix 生态工具
    nixfmt
    nixd
    cachix
    devenv
  ];

  # ============================================================
  # 9. 网络代理服务
  # ============================================================
  services.dae = {
    enable = true;
    configFile = pkgs.writeText "config.dae" (
      import ./dae/config.nix {
        nodes = vars.daeNodes;
        subscriptions = vars.daeSubscriptions;
      }
    );
    assets = [
      (pkgs.callPackage ./pkgs/v2ray-rules-dat/v2ray-rules-dat.nix { })
    ];
  };

  # ============================================================
  # 10. SSH 服务配置
  # ============================================================
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false; # 禁用密码认证
      KbdInteractiveAuthentication = false; # 禁用键盘交互认证
      PermitRootLogin = "no"; # 禁止 root 用户登录
      # 如需允许 root 使用密钥登录,可改为: PermitRootLogin = "prohibit-password";
    };
  };

  # ============================================================
  # 系统版本锁定
  # ============================================================
  system.stateVersion = "25.11"; # 请勿随意修改此值
}
