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

  mkMpvDesktopExecCheck =
    system: name: host:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
      homeCfg = config.config.home-manager.users.${host.user.name};
      hasDesktopOverride = builtins.hasAttr "applications/mpv.desktop" homeCfg.xdg.dataFile;
      desktopSource =
        if hasDesktopOverride then homeCfg.xdg.dataFile."applications/mpv.desktop".source else "MISSING";
    in
    pkgs.runCommand "${name}-mpv-desktop-exec"
      {
        pass = if hasDesktopOverride then "1" else "0";
        inherit desktopSource;
      }
      ''
        if [[ "$pass" != 1 ]]; then
          echo "Expected Home Manager to override applications/mpv.desktop for ${name}." >&2
          exit 1
        fi

        if ! grep -Fxq 'Exec=mpv --player-operation-mode=pseudo-gui -- %F' "$desktopSource"; then
          echo "Expected overridden mpv.desktop to use %F so Dolphin remote files resolve through kio-fuse." >&2
          echo "desktopSource=$desktopSource" >&2
          echo "Actual Exec lines:" >&2
          grep '^Exec=' "$desktopSource" >&2 || true
          exit 1
        fi

        if grep -Fxq 'Exec=mpv --player-operation-mode=pseudo-gui -- %U' "$desktopSource"; then
          echo "Unexpected %U Exec remains in overridden mpv.desktop." >&2
          echo "desktopSource=$desktopSource" >&2
          grep '^Exec=' "$desktopSource" >&2 || true
          exit 1
        fi

        touch $out
      '';

  packageNames = packages: map lib.getName packages;

  mkWorkstationGraphicsBaseCheck =
    system: name: host:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
      cfg = config.config;
      passes =
        cfg.hardware.enableRedistributableFirmware
        && cfg.hardware.graphics.enable
        && cfg.hardware.graphics.enable32Bit;
    in
    pkgs.runCommand "${name}-workstation-graphics-base"
      {
        pass = if passes then "1" else "0";
        firmware = if cfg.hardware.enableRedistributableFirmware then "1" else "0";
        graphics = if cfg.hardware.graphics.enable then "1" else "0";
        graphics32 = if cfg.hardware.graphics.enable32Bit then "1" else "0";
      }
      ''
        if [[ "$pass" != 1 ]]; then
          echo "Expected workstation graphics base for ${name}." >&2
          echo "firmware=$firmware" >&2
          echo "graphics=$graphics" >&2
          echo "graphics32=$graphics32" >&2
          exit 1
        fi
        touch $out
      '';

  mkGpuLayeringCheck =
    system: name: host: expected:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
      cfg = config.config;
      gpuCfg = cfg.platform.machine.gpu;
      graphicsPkgNames = packageNames (cfg.hardware.graphics.extraPackages or [ ]);
      systemPkgNames = packageNames (cfg.environment.systemPackages or [ ]);
      videoDrivers = cfg.services.xserver.videoDrivers or [ ];
      passes =
        gpuCfg.intel.enable == expected.intel
        && gpuCfg.amd.enable == expected.amd
        && gpuCfg.nvidia.enable == expected.nvidia
        && cfg.hardware.graphics.enable == expected.graphics
        && cfg.hardware.graphics.enable32Bit == expected.graphics32
        && (cfg.hardware.amdgpu.initrd.enable or false) == expected.amdgpuInitrd
        && (cfg.hardware.amdgpu.opencl.enable or false) == expected.amdgpuOpencl
        && (cfg.hardware.nvidia-container-toolkit.enable or false) == expected.nvidiaToolkit
        && lib.all (pkg: lib.elem pkg graphicsPkgNames) expected.graphicsPackages
        && lib.all (pkg: lib.elem pkg systemPkgNames) expected.systemPackages
        && lib.all (driver: lib.elem driver videoDrivers) expected.videoDrivers;
    in
    pkgs.runCommand "${name}-gpu-layering"
      {
        pass = if passes then "1" else "0";
        graphicsPackages = lib.concatStringsSep "," graphicsPkgNames;
        systemPackages = lib.concatStringsSep "," systemPkgNames;
        drivers = lib.concatStringsSep "," videoDrivers;
        intel = if gpuCfg.intel.enable then "1" else "0";
        amd = if gpuCfg.amd.enable then "1" else "0";
        nvidia = if gpuCfg.nvidia.enable then "1" else "0";
        graphics = if cfg.hardware.graphics.enable then "1" else "0";
        graphics32 = if cfg.hardware.graphics.enable32Bit then "1" else "0";
        amdgpuInitrd = if (cfg.hardware.amdgpu.initrd.enable or false) then "1" else "0";
        amdgpuOpencl = if (cfg.hardware.amdgpu.opencl.enable or false) then "1" else "0";
        nvidiaToolkit = if (cfg.hardware.nvidia-container-toolkit.enable or false) then "1" else "0";
      }
      ''
        if [[ "$pass" != 1 ]]; then
          echo "Expected GPU layering for ${name}." >&2
          echo "intel=$intel amd=$amd nvidia=$nvidia" >&2
          echo "graphics=$graphics graphics32=$graphics32" >&2
          echo "amdgpuInitrd=$amdgpuInitrd amdgpuOpencl=$amdgpuOpencl nvidiaToolkit=$nvidiaToolkit" >&2
          echo "graphicsPackages=$graphicsPackages" >&2
          echo "systemPackages=$systemPackages" >&2
          echo "drivers=$drivers" >&2
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

    example-intel-workstation = base // {
      hostname = "example-intel-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "gpu-intel" ];
      machine.boot.mode = "uefi";
    };

    example-amd-workstation = base // {
      hostname = "example-amd-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "gpu-amd" ];
      machine.boot.mode = "uefi";
    };

    example-intel-ai-workstation = base // {
      hostname = "example-intel-ai-workstation";
      profiles = [ "workstation-base" ];
      roles = [
        "gpu-intel"
        "ai-accelerated"
      ];
      machine.boot.mode = "uefi";
    };

    example-amd-ai-workstation = base // {
      hostname = "example-amd-ai-workstation";
      profiles = [ "workstation-base" ];
      roles = [
        "gpu-amd"
        "ai-accelerated"
      ];
      machine.boot.mode = "uefi";
    };

    example-gpu-workstation = base // {
      hostname = "example-gpu-workstation";
      roles = [
        "gpu-nvidia"
        "ai-accelerated"
      ];
      profiles = [ "workstation-base" ];
      machine.boot.mode = "uefi";
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

    example-workstation-mpv-desktop-exec =
      mkMpvDesktopExecCheck system "example-workstation"
        hosts.example-workstation;

    example-workstation-graphics-base =
      mkWorkstationGraphicsBaseCheck system "example-workstation"
        hosts.example-workstation;

    example-intel-workstation-gpu =
      mkGpuLayeringCheck system "example-intel-workstation" hosts.example-intel-workstation
        {
          intel = true;
          amd = false;
          nvidia = false;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = false;
          amdgpuOpencl = false;
          nvidiaToolkit = false;
          graphicsPackages = [
            "intel-media-driver"
            "intel-vaapi-driver"
            "vpl-gpu-rt"
          ];
          systemPackages = [ ];
          videoDrivers = [ ];
        };

    example-amd-workstation-gpu =
      mkGpuLayeringCheck system "example-amd-workstation" hosts.example-amd-workstation
        {
          intel = false;
          amd = true;
          nvidia = false;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = true;
          amdgpuOpencl = false;
          nvidiaToolkit = false;
          graphicsPackages = [ ];
          systemPackages = [ ];
          videoDrivers = [ ];
        };

    example-intel-ai-workstation-gpu =
      mkGpuLayeringCheck system "example-intel-ai-workstation" hosts.example-intel-ai-workstation
        {
          intel = true;
          amd = false;
          nvidia = false;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = false;
          amdgpuOpencl = false;
          nvidiaToolkit = false;
          graphicsPackages = [
            "intel-media-driver"
            "intel-vaapi-driver"
            "vpl-gpu-rt"
          ];
          systemPackages = [
            "openvino"
            "intel-compute-runtime"
          ];
          videoDrivers = [ ];
        };

    example-amd-ai-workstation-gpu =
      mkGpuLayeringCheck system "example-amd-ai-workstation" hosts.example-amd-ai-workstation
        {
          intel = false;
          amd = true;
          nvidia = false;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = true;
          amdgpuOpencl = true;
          nvidiaToolkit = false;
          graphicsPackages = [ ];
          systemPackages = [ "rocminfo" ];
          videoDrivers = [ ];
        };

    example-gpu-workstation-ai-layering =
      mkGpuLayeringCheck system "example-gpu-workstation" hosts.example-gpu-workstation
        {
          intel = false;
          amd = false;
          nvidia = true;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = false;
          amdgpuOpencl = false;
          nvidiaToolkit = true;
          graphicsPackages = [ ];
          systemPackages = [ "cuda-merged" ];
          videoDrivers = [ "nvidia" ];
        };
  }
)
