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

  mkSshAgentSessionCheck =
    system: name: host:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
      homeCfg = config.config.home-manager.users.${host.user.name};
      socket = homeCfg.services.ssh-agent.socket;
      addKeysService = homeCfg.systemd.user.services.ssh-add-sops-keys or { };
      after = addKeysService.Unit.After or [ ];
      envLines = addKeysService.Service.Environment or [ ];
      execStart = addKeysService.Service.ExecStart or "MISSING";
      gtk2ConfigPath = "${homeCfg.home.homeDirectory}/.gtkrc-2.0";
      gtk2Force = (homeCfg.home.file.${gtk2ConfigPath}.force or false);
      wantedBy = addKeysService.Install.WantedBy or [ ];
      zshInit = homeCfg.programs.zsh.initContent or "";
      passes =
        homeCfg.services.ssh-agent.enable
        && (homeCfg.systemd.user.sessionVariables.SSH_AUTH_SOCK or null) == "$XDG_RUNTIME_DIR/${socket}"
        && builtins.hasAttr "ssh-add-sops-keys" homeCfg.systemd.user.services
        && lib.elem "ssh-agent.service" after
        && lib.elem "default.target" wantedBy
        && lib.any (line: lib.hasInfix "SSH_AUTH_SOCK=%t/${socket}" line) envLines
        && !(lib.hasInfix "ssh-agent -s" zshInit)
        && !(lib.hasInfix "ssh-add" zshInit)
        && !(lib.hasInfix "/run/secrets/" zshInit)
        && gtk2Force;
    in
    pkgs.runCommand "${name}-ssh-agent-session"
      {
        pass = if passes then "1" else "0";
        sessionSock = homeCfg.systemd.user.sessionVariables.SSH_AUTH_SOCK or "MISSING";
        sshAgentEnabled = if homeCfg.services.ssh-agent.enable then "1" else "0";
        gtk2ForceText = if gtk2Force then "1" else "0";
        inherit socket;
        afterText = lib.concatStringsSep "," after;
        wantedByText = lib.concatStringsSep "," wantedBy;
        envText = lib.concatStringsSep " | " envLines;
        inherit execStart zshInit;
      }
      ''
        if [[ "$pass" != 1 ]]; then
          echo "Expected session-level ssh-agent wiring for ${name}." >&2
          echo "sshAgentEnabled=$sshAgentEnabled" >&2
          echo "socket=$socket" >&2
          echo "sessionSock=$sessionSock" >&2
          echo "gtk2Force=$gtk2ForceText" >&2
          echo "after=$afterText" >&2
          echo "wantedBy=$wantedByText" >&2
          echo "env=$envText" >&2
          echo "execStart=$execStart" >&2
          echo "zshInit=$zshInit" >&2
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

    example-workstation-ssh-agent = base // {
      hostname = "example-workstation-ssh-agent";
      profiles = [ "workstation-base" ];
      roles = [ "development" ];
      machine.boot.mode = "uefi";
      home.sshAgent.sopsSecrets = [ "ssh_private_key" ];
      secrets.sops = {
        enable = true;
        defaultFile = ../../example/my-host/hosts/workstation/secrets.yaml;
        ageKeyFile = "/tmp/example-age-key";
        secrets.ssh_private_key = {
          owner = user.name;
          mode = "0400";
        };
      };
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

    example-workstation-ssh-agent-session =
      mkSshAgentSessionCheck system "example-workstation-ssh-agent"
        hosts.example-workstation-ssh-agent;
  }
)
