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
          extraModules = [ ./hosts/wsl-dev ];
        };

        server = public.lib.mkHost {
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
          hostname = "workstation";
          system = "x86_64-linux";
          user = commonUser;
          profiles = [ "workstation-base" ];
          roles = [
            "development"
            "fullstack-development"
            "ai-tooling"
            "container-host"
            "ai-accelerated"
          ];
          machine = {
            boot.mode = "uefi";
            nvidia.enable = true;
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
