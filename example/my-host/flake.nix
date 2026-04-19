# example/my-host/flake.nix
# 私有配置仓库的 flake 入口
# 用法：将此 example 目录复制为你的私有仓库根目录，然后按需修改
{
  description = "My NixOS Private Configuration";

  inputs = {
    # 引入公共模块库（nixpkgs 从此获取）
    nixos-config-public = {
      url = "github:Chikage0o0/nixos-config";
    };

    # Home Manager - 用户级别配置管理
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixos-config-public";
    };

    # NixOS-WSL - Windows Subsystem for Linux 支持
    # 物理机部署可以移除此 input
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixos-config-public";
    };

    # sops-nix - 通过 age/PGP 加密管理机密文件
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixos-config-public";
    };
  };

  outputs =
    {
      self,
      nixos-config-public,
      home-manager,
      nixos-wsl,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      nixpkgs = nixos-config-public.inputs.nixpkgs;

      # 主机配置映射表
      # 键为主机名（需与 `hosts/` 下的目录名一致），值为主机配置路径
      hostConfigs = {
        "my-host" = ./hosts/my-host;
      };

      # 通用主机构建函数
      # 为每台主机组装 NixOS 配置：公共模块 + sops + 主机配置 + Home Manager
      mkHost =
        hostname: hostPath:
        nixpkgs.lib.nixosSystem {
          inherit system;

          # 通过 specialArgs 将 hostname 和 inputs 传递给所有模块
          # 这样主机配置中可以直接使用 inputs.nixos-wsl 等
          specialArgs = {
            inherit hostname;
            inputs =
              nixos-config-public.inputs
              // inputs
              // {
                inherit nixos-config-public;
              };
          };

          modules = [
            # 允许安装非自由软件（如 NVIDIA 驱动）
            { nixpkgs.config.allowUnfree = true; }

            # 导入公共模块库（包含 myConfig 选项定义和所有系统模块）
            nixos-config-public.nixosModules.default

            # 导入 sops-nix（机密管理）
            sops-nix.nixosModules.sops

            # 导入主机特定配置
            hostPath

            # Home Manager 集成
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit hostname;
                inputs = nixos-config-public.inputs // inputs;
              };
            }
          ];
        };
    in
    {
      # 为 hostConfigs 中的每台主机生成 nixosConfigurations
      # 部署命令：sudo nixos-rebuild switch --flake .#my-host
      nixosConfigurations = builtins.mapAttrs mkHost hostConfigs;
    };
}
