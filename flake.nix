{
  description = "NixOS Config Library - Reusable modules for CUDA/TensorRT Dev";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };

  inputs = {
    self.submodules = true;

    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # 上游保留配置 Interface，Numtide 提供双架构缓存的源码构建包。
    omp.url = "github:can1357/oh-my-pi/v18.2.10";
    # 不覆写该输入的 nixpkgs，避免改变已缓存的 derivation。
    llm-agents.url = "github:numtide/llm-agents.nix/e28ea84e78517e5d05ae0c399da00e848e207261";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.8.18";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      defaultOverlay = final: prev: {
        tabby = final.callPackage ./pkgs/tabby { };
      };
      platformLib = import ./lib { inherit inputs self; };
    in
    {
      overlays.default = defaultOverlay;

      # 导出 NixOS 模块
      nixosModules = {
        default = self.nixosModules.platform;
        platform =
          { lib, pkgs, ... }:
          {
            imports = [
              inputs.omp.nixosModules.default
              ./modules/nixos
            ];
            programs.omp.package =
              lib.mkDefault
                inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
            nixpkgs.overlays = [ self.overlays.default ];
          };
        profiles = import ./profiles;
        roles = import ./roles;
        orangepi-zero3 = ./modules/nixos/hardware/orangepi-zero3.nix;
        orangepi-zero3-image = ./modules/nixos/image/orangepi-zero3.nix;
      };

      # 导出 Home Manager 模块
      homeModules = {
        default = self.homeModules.platform;
        platform =
          { lib, pkgs, ... }:
          {
            imports = [
              inputs.omp.homeManagerModules.default
              ./modules/home
            ];
            programs.omp.package =
              lib.mkDefault
                inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
          };
      };

      # 导出自定义包
      packages =
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
          ]
          (
            system:
            let
              pkgs = import nixpkgs {
                inherit system;
                overlays = [ self.overlays.default ];
              };
            in
            {
              inherit (pkgs) tabby;
            }
          );

      # 导出格式化工具
      formatter = nixpkgs.lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ] (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      # 导出 eval 正确性 checks
      checks = import ./lib/platform/checks.nix { inherit inputs self; };

      # 导出 lib 函数
      lib = platformLib;
    };
}
