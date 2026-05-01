{
  inputs,
  self,
}:
let
  systems = [ "x86_64-linux" ];
  lib = inputs.nixpkgs.lib;

  mkEvalCheck =
    system: name: host:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
    in
    pkgs.runCommand "${name}-eval"
      {
        # Force full system evaluation without making the check derivation depend
        # on the referenced .drv path being already valid in the local store.
        evaluatedSystem = builtins.unsafeDiscardStringContext config.config.system.build.toplevel.drvPath;
      }
      ''
        touch $out
      '';

  mkKsmserverLoginModeCheck =
    system: name: host:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
      homeCfg = config.config.home-manager.users.${host.user.name};
      activationData = homeCfg.home.activation.setKsmserverLoginMode.data or "";
      managesWholeFile = builtins.hasAttr "ksmserverrc" homeCfg.xdg.configFile;
      usesKwriteconfig = lib.hasInfix "kwriteconfig6" activationData;
      targetsKsmserver = lib.hasInfix "--file ksmserverrc" activationData;
      writesLoginMode =
        lib.hasInfix "--group General" activationData
        && lib.hasInfix "--key loginMode" activationData
        && lib.hasInfix "emptySession" activationData;
      passes = !managesWholeFile && usesKwriteconfig && targetsKsmserver && writesLoginMode;
    in
    pkgs.runCommand "${name}-ksmserver-login-mode"
      {
        inherit activationData;
        pass = if passes then "1" else "0";
        staticKsmserverFile = if managesWholeFile then "1" else "0";
      }
      ''
        if [[ "$pass" != 1 ]]; then
          echo "Expected Plasma session restore policy to be written via kwriteconfig6 activation." >&2
          echo "staticKsmserverFile=$staticKsmserverFile" >&2
          echo "$activationData" >&2
          exit 1
        fi
        touch $out
      '';

  user = {
    name = "example";
    fullName = "Example User";
    email = "example@example.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
  };

  base = {
    inherit user;
    stateVersion = "25.11";
    secrets.sops.enable = false;
    # NixOS 强制要求定义根文件系统；eval-only check 使用最小 mock
    extraModules = [
      {
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      }
    ];
  };

  hosts = {
    example-wsl = base // {
      hostname = "example-wsl";
      profiles = [ "wsl-base" ];
      roles = [ ];
      machine.wsl.enable = true;
    };

    example-wsl-dev-container = base // {
      hostname = "example-wsl-dev-container";
      profiles = [ "wsl-base" ];
      roles = [
        "development"
        "fullstack-development"
        "ai-tooling"
        "container-host"
      ];
      machine.wsl.enable = true;
      home.opencode.enable = true;
    };

    example-server = base // {
      hostname = "example-server";
      profiles = [ "server-base" ];
      roles = [ "remote-admin" ];
      machine.boot.mode = "uefi";
    };

    example-server-dev-container = base // {
      hostname = "example-server-dev-container";
      profiles = [ "server-base" ];
      roles = [
        "development"
        "container-host"
      ];
      machine.boot.mode = "uefi";
    };

    example-workstation = base // {
      hostname = "example-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "development" ];
      machine.boot.mode = "uefi";
    };

    example-gpu-workstation = base // {
      hostname = "example-gpu-workstation";
      profiles = [ "workstation-base" ];
      roles = [
        "development"
        "fullstack-development"
        "ai-tooling"
        "container-host"
        "ai-accelerated"
      ];
      machine.boot.mode = "uefi";
      machine.nvidia.enable = true;
      home.opencode.enable = true;
    };
  };
in
lib.genAttrs systems (
  system:
  lib.mapAttrs' (name: host: lib.nameValuePair name (mkEvalCheck system name host)) hosts
  // {
    example-workstation-ksmserver-login-mode =
      mkKsmserverLoginModeCheck system "example-workstation"
        hosts.example-workstation;
  }
)
