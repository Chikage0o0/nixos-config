{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myConfig;
  opencodeConfigPath = ".config/opencode/config.json";
in
{
  home.file = {
    ".config/opencode/skills/".source = "${inputs.opencode-config}/skills";
    ".config/opencode/AGENTS.md".source = "${inputs.opencode-config}/AGENTS.md";
    ".config/opencode/plugins/".source = "${inputs.opencode-config}/plugins";
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
