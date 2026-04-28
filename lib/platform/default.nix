{
  inputs,
  self,
}:
let
  lib = inputs.nixpkgs.lib;
  moduleSets = import ./modules.nix;

  resolveNamedModules =
    kind: available: names:
    map (
      name:
      if builtins.hasAttr name available then
        available.${name}
      else
        throw "Unknown ${kind} '${name}'. Available ${kind}s: ${lib.concatStringsSep ", " (builtins.attrNames available)}"
    ) names;

  requireAttrs =
    attrPath: value: names:
    if names == [ ] then
      true
    else
      let
        name = builtins.head names;
      in
      if builtins.hasAttr name value then
        requireAttrs attrPath value (builtins.tail names)
      else
        throw "mkHost requires ${attrPath}.${name}";

  compactNulls = attrs: lib.filterAttrs (_: value: value != null) attrs;

  normalizeHost =
    host:
    let
      _requiredTop = requireAttrs "host" host [
        "hostname"
        "user"
      ];
      _requiredUser = requireAttrs "host.user" host.user [
        "name"
        "fullName"
        "email"
        "sshPublicKey"
      ];
    in
    builtins.seq _requiredTop (
      builtins.seq _requiredUser (
        host
        // {
          system = host.system or "x86_64-linux";
          profiles = host.profiles or [ "generic-linux" ];
          roles = host.roles or [ ];
          machine = host.machine or { };
          desktop = host.desktop or { };
          networking = host.networking or { };
          services = host.services or { };
          home = host.home or { };
          secrets = host.secrets or { };
          extraModules = host.extraModules or [ ];
          hardwareModules = host.hardwareModules or [ ];
        }
      )
    );

  platformHostModule =
    host:
    { lib, ... }:
    {
      networking.hostName = host.hostname;
      platform = lib.mkMerge [
        {
          profiles = host.profiles;
          roles = host.roles;
          user = host.user;
        }
        (compactNulls {
          stateVersion = host.stateVersion or null;
          machine = host.machine or null;
          desktop = host.desktop or null;
          nix = host.nix or null;
          networking = host.networking or null;
          services = host.services or null;
          containers = host.containers or null;
          home = host.home or null;
          development = host.development or null;
          packages = host.packages or null;
        })
      ];
    };

  sopsModule =
    host:
    { lib, ... }:
    let
      sops = host.secrets.sops or { enable = false; };
    in
    lib.mkIf (sops.enable or false) {
      sops.defaultSopsFile =
        sops.defaultFile
          or (throw "mkHost requires host.secrets.sops.defaultFile when secrets.sops.enable = true");
      sops.age.keyFile =
        sops.ageKeyFile
          or (throw "mkHost requires host.secrets.sops.ageKeyFile when secrets.sops.enable = true");
      sops.secrets = sops.secrets or { };
      sops.templates = sops.templates or { };
    };

  homeManagerBridgeModule =
    host:
    { config, ... }:
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        inherit inputs;
        hostname = host.hostname;
      };
      home-manager.users.${config.platform.user.name} = {
        imports = [ self.homeModules.default ];
        platform = config.platform;
      };
    };
in
rec {
  inherit normalizeHost;

  profileNames = builtins.attrNames moduleSets.profiles;
  roleNames = builtins.attrNames moduleSets.roles;

  resolveProfiles = names: resolveNamedModules "profile" moduleSets.profiles names;
  resolveRoles = names: resolveNamedModules "role" moduleSets.roles names;

  mkHost =
    hostInput:
    let
      host = normalizeHost hostInput;
      profileModules = resolveProfiles host.profiles;
      roleModules = resolveRoles host.roles;
      wslModules = lib.optionals (host.machine.wsl.enable or false) [
        inputs.nixos-wsl.nixosModules.default
      ];
    in
    inputs.nixpkgs.lib.nixosSystem {
      system = host.system;
      specialArgs = {
        inherit inputs;
        hostname = host.hostname;
      };
      modules = [
        { nixpkgs.overlays = [ self.overlays.default ]; }
        { nixpkgs.config.allowUnfree = true; }
        # 前向引用：由平台化重写任务 3/5 创建 nixosModules.platform 后生效
        # 骨架阶段此引用在 mkHost 被调用时才会实际求值，profileNames/roleNames 不受影响
        self.nixosModules.platform
        inputs.sops-nix.nixosModules.sops
        inputs.home-manager.nixosModules.home-manager
        (platformHostModule host)
        (sopsModule host)
      ]
      ++ wslModules
      ++ profileModules
      ++ roleModules
      ++ host.hardwareModules
      ++ host.extraModules
      ++ [ (homeManagerBridgeModule host) ];
    };

  mkSystem = mkHost;

  mkHome = args: inputs.home-manager.lib.homeManagerConfiguration args;
}
