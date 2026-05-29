{
  description = "My NixOS Private Configuration";

  inputs.nixos-config-public.url = "github:Chikage0o0/nixos-config";

  outputs =
    { nixos-config-public, ... }:
    let
      public = nixos-config-public;
      commonUser = {
        name = "your_username";
        fullName = "Your Name";
        email = "your@email.com";
        sshPublicKey = "ssh-ed25519 AAAA... user@host";
      };
    in
    {
      nixosConfigurations = {
        wsl-dev = public.lib.mkHost {
          # WSL 开发环境：适合从 Windows 侧导入 NixOS-WSL 后作为日常终端使用。
          hostname = "wsl-dev";
          system = "x86_64-linux";
          user = commonUser;
          profiles = [ "wsl-base" ];
          roles = [
            "development"
            "fullstack-development"
            "ai-tooling"
            "container-host"
          ];
          machine.wsl.enable = true;
          home.opencode.enable = true;
          secrets.sops = {
            enable = true;
            defaultFile = ./hosts/wsl-dev/secrets.yaml;
            # build-wsl.sh 会把 host age key 注入到这个路径；导入后也可手动放置。
            ageKeyFile = "/var/lib/sops-nix/age/keys.txt";
            secrets = {
              "user/hashedPassword".neededForUsers = true;
              "opencode/apiKey" = { };
              "ssh_private_key" = {
                owner = commonUser.name;
                mode = "0400";
              };
            };
          };
          extraModules = [ ./hosts/wsl-dev ];
        };

        server = public.lib.mkHost {
          # 服务器示例：保留最小图形无关配置，适合 VPS/家用服务器继续扩展。
          hostname = "server";
          system = "x86_64-linux";
          user = commonUser;
          profiles = [ "server-base" ];
          roles = [
            "remote-admin"
            "container-host"
          ];
          machine.boot.mode = "uefi";
          secrets.sops = {
            enable = true;
            defaultFile = ./hosts/server/secrets.yaml;
            ageKeyFile = "/home/${commonUser.name}/.config/sops/age/keys.txt";
            secrets."user/hashedPassword".neededForUsers = true;
          };
          hardwareModules = [ ./hosts/server/hardware-configuration.nix ];
          extraModules = [ ./hosts/server ];
        };

        workstation = public.lib.mkHost {
          # 物理工作站示例：展示桌面、开发工具、OpenCode、SSH 私钥与 NVIDIA/CUDA 组合。
          hostname = "workstation";
          system = "x86_64-linux";
          user = commonUser;
          profiles = [ "workstation-base" ];
          roles = [
            "development"
            "fullstack-development"
            "ai-tooling"
            "container-host"
            "gpu-nvidia"
            "ai-accelerated"
          ];
          machine = {
            boot.mode = "uefi";
          };
          home.opencode.enable = true;
          secrets.sops = {
            enable = true;
            defaultFile = ./hosts/workstation/secrets.yaml;
            ageKeyFile = "/home/${commonUser.name}/.config/sops/age/keys.txt";
            secrets = {
              "user/hashedPassword".neededForUsers = true;
              "opencode/apiKey" = { };
              "ssh_private_key" = {
                owner = commonUser.name;
                mode = "0400";
              };
            };
          };
          hardwareModules = [ ./hosts/workstation/hardware-configuration.nix ];
          extraModules = [ ./hosts/workstation ];
        };
      };
    };
}
