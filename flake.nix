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
      url = "github:anomalyco/opencode/v1.1.59";
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
      # 因此这里从真实文件系统读取（需要 `--impure`）。
      # 查找优先级：
      # 1) NIXOS_CONFIG_DIR=/some/dir
      # 2) 当前工作目录(PWD)下的 vars.nix（便于 root 直接在仓库目录里执行）
      # 3) sudo 场景用 SUDO_USER 还原真实用户：/home/<SUDO_USER>/nixos-config/vars.nix
      # 4) 普通用户用 HOME：$HOME/nixos-config/vars.nix
      varsPath =
        let
          env = builtins.getEnv;
          mkPath = p: /. + p;
          opt = cond: p: if cond then [ (mkPath p) ] else [ ];

          nixosConfigDir = env "NIXOS_CONFIG_DIR";
          pwd = env "PWD";
          sudoUser = env "SUDO_USER";
          homeFromEnv = env "HOME";
          userFromEnv = env "USER";

          candidates =
            (opt (nixosConfigDir != "") "${nixosConfigDir}/vars.nix")
            ++ (opt (pwd != "") "${pwd}/vars.nix")
            ++ (opt (sudoUser != "") "/home/${sudoUser}/nixos-config/vars.nix")
            ++ (opt (homeFromEnv != "" && homeFromEnv != "/root") "${homeFromEnv}/nixos-config/vars.nix")
            ++ (opt (userFromEnv != "" && userFromEnv != "root") "/home/${userFromEnv}/nixos-config/vars.nix");

          existing = builtins.filter builtins.pathExists candidates;
        in
        if existing != [ ] then
          builtins.head existing
        else
          throw "未找到 vars.nix（需要 `--impure`）：请在仓库目录放置 vars.nix，或设置 NIXOS_CONFIG_DIR=/path/to/nixos-config";

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
