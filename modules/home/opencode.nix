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
  rtk = pkgs.rustPlatform.buildRustPackage rec {
    pname = "rtk";
    version = "0.31.0";

    src = pkgs.fetchFromGitHub {
      owner = "rtk-ai";
      repo = "rtk";
      rev = "v${version}";
      hash = "sha256-p4OX3SSDGKlHVLIWhgKpcme449wOHbfWbc3mxlCkaMI=";
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
    package = pkgs.opencode;
  }
  // lib.optionalAttrs (cfg.opencodeConfigFile == null) {
    settings = pkgs.lib.recursiveUpdate (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json")) cfg.opencodeSettings;
  };
}
