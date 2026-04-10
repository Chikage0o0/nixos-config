{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myConfig;
  opencodeConfigPath = ".config/opencode/opencode.json";
  opencodeVersion = "1.4.3";
  opencodeRelease =
    {
      x86_64-linux = {
        asset = "opencode-linux-x64.tar.gz";
        hash = "sha256-NNUD67AphTKTvm/U1EG7stuwORm/pFJeiLHKVdaPPhc=";
      };
      aarch64-linux = {
        asset = "opencode-linux-arm64.tar.gz";
        hash = "sha256-TL8y9MMdp9rhRxK2Wq285qz6GnqFvumGos5Oqu1Otcg=";
      };
      x86_64-darwin = {
        asset = "opencode-darwin-x64.zip";
        hash = "sha256-FDECjjJNzdIyLlqnEERKUsbedNGjgvgIKkrRL9rgdo8=";
      };
      aarch64-darwin = {
        asset = "opencode-darwin-arm64.zip";
        hash = "sha256-0IXAcgh/oc8HYFiuKHhaMak2jg88QpheqMVYA2/Lmww=";
      };
    }
    .${pkgs.stdenv.hostPlatform.system}
      or (throw "Unsupported system for opencode release binary: ${pkgs.stdenv.hostPlatform.system}");

  opencode = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode";
    version = opencodeVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v${opencodeVersion}/${opencodeRelease.asset}";
      hash = opencodeRelease.hash;
    };

    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [
      pkgs.makeWrapper
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.unzip ];

    unpackPhase =
      if pkgs.stdenv.hostPlatform.isLinux then
        ''
          tar -xzf "$src"
        ''
      else
        ''
          unzip -q "$src"
        '';

    installPhase = ''
      runHook preInstall

      install -Dm755 opencode $out/libexec/opencode

      makeWrapper $out/libexec/opencode $out/bin/opencode \
        --prefix PATH : "${
          lib.makeBinPath (
            [ pkgs.ripgrep ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.sysctl ]
          )
        }"

      runHook postInstall
    '';

    meta = with lib; {
      description = "AI coding agent built for the terminal";
      homepage = "https://github.com/anomalyco/opencode";
      license = licenses.mit;
      mainProgram = "opencode";
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    };
  };

  rtk = pkgs.rustPlatform.buildRustPackage rec {
    pname = "rtk";
    version = "0.35.0";

    src = pkgs.fetchFromGitHub {
      owner = "rtk-ai";
      repo = "rtk";
      rev = "v${version}";
      hash = "sha256-7DAL4dsnq2ZWmkyoI+BeN21ouK0VyLvSxOCt5hPWCl4=";
    };

    cargoLock.lockFile = "${src}/Cargo.lock";
    doCheck = false;

    meta = with lib; {
      description = "CLI proxy that reduces LLM token consumption on common dev commands";
      homepage = "https://github.com/rtk-ai/rtk";
      license = licenses.mit;
      mainProgram = "rtk";
      platforms = platforms.unix;
    };
  };
in
{
  home.packages = [ rtk ];

  home.file = {
    ".config/opencode/skills/".source = "${inputs.opencode-config}/skills";
    ".config/opencode/AGENTS.md".source = "${inputs.opencode-config}/AGENTS.md";
    ".config/opencode/plugins/".source = "${inputs.opencode-config}/plugins";
    ".config/opencode/tui.json".source = "${inputs.opencode-config}/tui.json";
  }
  // lib.optionalAttrs (cfg.opencodeConfigFile != null) {
    "${opencodeConfigPath}" = {
      source = config.lib.file.mkOutOfStoreSymlink cfg.opencodeConfigFile;
      force = true;
    };
  };

  programs.opencode = {
    enable = true;
    package = opencode;
  }
  // lib.optionalAttrs (cfg.opencodeConfigFile == null) {
    settings = pkgs.lib.recursiveUpdate (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json")) cfg.opencodeSettings;
  };
}
