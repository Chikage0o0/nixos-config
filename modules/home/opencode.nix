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
  opencodeVersion = "1.3.3";
  opencodeRelease =
    {
      x86_64-linux = {
        asset = "opencode-linux-x64.tar.gz";
        hash = "sha256-krs2sW7R37CGl/0rfY99Cf38us1eW/amf00Ven9TOxM=";
      };
      aarch64-linux = {
        asset = "opencode-linux-arm64.tar.gz";
        hash = "sha256-ocVx/JBB4fHbF0rF7sT/B48curk5J9he2pgvG8k5NKQ=";
      };
      x86_64-darwin = {
        asset = "opencode-darwin-x64.zip";
        hash = "sha256-hjAdFXtsFhvQvCZq1eKEWOAeTEyVRKc/6Z+XqtvDV5M=";
      };
      aarch64-darwin = {
        asset = "opencode-darwin-arm64.zip";
        hash = "sha256-5wg/AWIU3ZXBRCug8WjlbC46aOZyHQT6B55myoXbF6U=";
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
    version = "0.34.0";

    src = pkgs.fetchFromGitHub {
      owner = "rtk-ai";
      repo = "rtk";
      rev = "v${version}";
      hash = "sha256-jPV0/rROaZdVn8gLhhZIhI0ZqMfSvRnNxplYYuboJeE=";
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
