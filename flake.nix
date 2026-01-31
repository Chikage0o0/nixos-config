{
  description = "NixOS Config for CUDA/TensorRT Dev";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode-config = {
      url = "github:Chikage0o0/opencode";
      flake = false;
    };

    opencode = {
      url = "github:anomalyco/opencode/v1.1.47";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      baseVars = import ./vars.nix.example;

      # ⚠️ 注意：如果使用 Flakes，必须运行 `git add -N vars.nix` 才能让 Nix 看见此文件
      localVars = if builtins.pathExists ./vars.nix then import ./vars.nix else { };

      vars = baseVars // localVars;

    in
    {
      nixosConfigurations.dev-machine = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = { inherit inputs vars; };

        modules = [
          ./configuration.nix

          # 针对 CUDA 开发环境的建议：在 Flake 层级允许非自由软件
          { nixpkgs.config.allowUnfree = true; }

          # Home Manager 模块
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit inputs vars; };
            home-manager.users.${vars.username} = import ./home.nix;
          }
        ];
      };
    };
}
