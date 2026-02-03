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
      url = "github:anomalyco/opencode/v1.1.48";
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

      # vars.nix 被 .gitignore 忽略时，Flake 的源码快照里是“看不见”的。
      # 这里从真实文件系统读取：默认推导为 /home/<真实用户>/nixos-config/vars.nix。
      # 如需自定义路径，仍可用环境变量覆盖：NIXOS_CONFIG_DIR=/some/dir。
      varsPath =
        let
          # sudo 执行时 HOME/USER 往往会变成 root，这里优先用 SUDO_USER 还原真实用户。
          sudoUser = builtins.getEnv "SUDO_USER";
          homeFromEnv = builtins.getEnv "HOME";
          userHome =
            if sudoUser != "" then
              "/home/${sudoUser}"
            else if homeFromEnv != "" then
              homeFromEnv
            else
              "/home/${builtins.getEnv "USER"}";

          configDirStr =
            let
              v = builtins.getEnv "NIXOS_CONFIG_DIR";
            in
            if v != "" then v else "${userHome}/nixos-config";
        in
        /. + "${configDirStr}/vars.nix";

      vars =
        if builtins.pathExists varsPath then
          import varsPath
        else
          throw "未找到 vars.nix：${toString varsPath}（请创建该文件或检查 NIXOS_CONFIG_DIR）";

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
