{
  config,
  pkgs,
  vars,
  inputs,
  ...
}:

{
  # ============================================================
  # Home Manager 基础配置
  # ============================================================
  home.username = vars.username;
  home.homeDirectory = "/home/${vars.username}";

  # ============================================================
  # 1. Git 版本控制配置
  # ============================================================
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = vars.userFullName;
        email = vars.userEmail;
        signingKey = vars.sshPublicKey; # 使用 SSH 密钥进行 Git 提交签名
      };
      init = {
        defaultBranch = "main"; # 新仓库默认分支名
      };
      gpg = {
        format = "ssh"; # 使用 SSH 格式签名(而非传统 GPG)
      };
      "gpg \"ssh\"" = {
        program = "${pkgs.openssh}/bin/ssh-keygen"; # 指定 SSH 签名程序
      };
      commit = {
        gpgsign = true; # 自动签名所有提交
      };
    };
  };

  # ============================================================
  # 2. Shell 环境配置
  # ============================================================
  # Zsh Shell 配置
  programs.zsh = {
    enable = true;
    enableCompletion = true; # 启用命令补全
    autosuggestion.enable = true; # 启用历史命令自动建议
    syntaxHighlighting.enable = true; # 启用语法高亮

    shellAliases = {
      ll = "ls -l";
      # 更新 geoip 和 geosite 数据
      update-geoip = "bash ~/nixos-config/pkgs/v2ray-rules-dat/update-v2ray-rules-dat.sh";
      # 系统更新前先更新 geoip/geosite 数据
      update = "bash ~/nixos-config/pkgs/v2ray-rules-dat/update-v2ray-rules-dat.sh && nix flake update opencode-config --flake ~/nixos-config && nix flake update opencode --flake ~/nixos-config && sudo nixos-rebuild switch --flake ~/nixos-config#dev-machine --impure";
      # 清理 Nix 垃圾回收
      clean = "nix-collect-garbage -d";
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = fromTOML (builtins.readFile ./home/starship.toml);
  };

  # Direnv: 自动加载项目环境变量
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true; # 启用 nix-direnv 以加速 Nix 环境加载
    enableZshIntegration = true;
  };

  # ============================================================
  # 3. 现代化 CLI 工具替代品
  # ============================================================
  # Eza: 现代化的 ls 替代品(支持图标和 Git 状态)
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    icons = "auto"; # 自动显示文件图标(需要 Nerd Font 字体支持)
    git = true; # 显示 Git 状态
  };

  # Zoxide: 智能目录跳转工具(替代 cd)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ]; # 直接替换 cd 命令(也可使用 z 命令)
  };

  # FZF: 模糊搜索工具
  programs.fzf = {
    enable = true;
    enableZshIntegration = true; # 启用 Ctrl+R 历史搜索等快捷键
  };

  # Bat: 带语法高亮的 cat 替代品
  programs.bat = {
    enable = true;
    config = {
      theme = "TwoDark"; # 使用 TwoDark 主题
    };
  };

  # Lazygit: Git 终端 UI 工具
  programs.lazygit.enable = true;

  home.file = {
    ".config/opencode/skills/".source = "${inputs.opencode-config}/skills";
    ".config/opencode/AGENTS.md".source = "${inputs.opencode-config}/AGENTS.md";
  };

  programs.opencode = {
    enable = true;
    package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
    settings = builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json");
  };

  # ============================================================
  # 4. 用户软件包
  # ============================================================
  home.packages = with pkgs; [
    # 核心开发工具
    ripgrep # 快速代码搜索工具(替代 grep)
    fd # 快速文件查找工具(替代 find)
    btop # 现代化系统资源监控工具
    jq # JSON 数据处理工具
    tldr # 简化版 man 手册(示例: tldr tar)

    # 网络工具
    curl # HTTP 客户端
    wget # 文件下载工具

    # 压缩归档工具
    zip
    unzip
    xz

    # AI 工具 依赖
    bun
    nodejs
    python3
    python3Packages.pip
    uv

    # 容器化工具
    docker-compose # Docker 编排工具(Docker daemon 在系统级配置)
  ];

  # ============================================================
  # 版本锁定
  # ============================================================
  home.stateVersion = "25.11"; # 请勿随意修改此值
}
