{
  description = "NixOS Config Library - Reusable modules for CUDA/TensorRT Dev";

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

    opencode-config = {
      url = "path:./vendor/opencode";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hermes-agent = {
      url = "github:NousResearch/hermes-agent/v2026.5.29.2";
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
        opencode = final.callPackage ./pkgs/opencode { };
        tabby = final.callPackage ./pkgs/tabby { };
        agent-browser = final.callPackage ./pkgs/agent-browser { };
        wxwork = final.callPackage ./pkgs/wxwork { };
      };
      platformLib = import ./lib { inherit inputs self; };
    in
    {
      overlays.default = defaultOverlay;

      # 导出 NixOS 模块
      nixosModules = {
        default = self.nixosModules.platform;
        platform = {
          imports = [ ./modules/nixos ];
          nixpkgs.overlays = [ self.overlays.default ];
        };
        profiles = import ./profiles;
        roles = import ./roles;
      };

      # 导出 Home Manager 模块
      homeModules = {
        default = self.homeModules.platform;
        platform = ./modules/home;
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
                config.allowUnfreePredicate =
                  pkg:
                  builtins.elem (nixpkgs.lib.getName pkg) [
                    "wxwork"
                  ];
              };
            in
            {
              inherit (pkgs) opencode tabby agent-browser;
            }
            // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
              inherit (pkgs) wxwork;
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
