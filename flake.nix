{
  description = "NixOS Config Library - Reusable modules for CUDA/TensorRT Dev";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode-config = {
      url = "github:Chikage0o0/opencode";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      defaultOverlay = final: prev: {
        v2ray-rules-dat = final.callPackage ./pkgs/v2ray-rules-dat { };
        opencode = final.callPackage ./pkgs/opencode { };
      };
    in
    {
      overlays.default = defaultOverlay;

      # 导出 NixOS 模块
      nixosModules = {
        default = {
          imports = [ ./modules/nixos ];
          nixpkgs.overlays = [ self.overlays.default ];
        };
        base = ./modules/nixos/base.nix;
        network = ./modules/nixos/network.nix;
        users = ./modules/nixos/users.nix;
        virtualisation = ./modules/nixos/virtualisation.nix;
        packages = ./modules/nixos/packages.nix;
        dae = ./modules/nixos/services/dae.nix;
        openssh = ./modules/nixos/services/openssh.nix;
        nvidia = ./modules/nixos/hardware/nvidia.nix;
      };

      # 导出 Home Manager 模块
      homeModules = {
        default = ./modules/home;
      };

      # 导出 lib 函数
      lib = import ./lib;
    };
}
