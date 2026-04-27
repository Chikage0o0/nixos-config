{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.platform;
  opencodeConfigPath = ".config/opencode/opencode.json";
in
{
  config = lib.mkIf cfg.home.opencode.enable {
    home.file = {
      ".config/opencode/agents/".source = "${inputs.opencode-config}/agents";
      ".config/opencode/skills/".source = "${inputs.opencode-config}/skills";
      ".config/opencode/AGENTS.md".source = "${inputs.opencode-config}/AGENTS.md";
      ".config/opencode/plugins/".source = "${inputs.opencode-config}/plugins";
      ".config/opencode/tui.json".source = "${inputs.opencode-config}/tui.json";
    }
    // lib.optionalAttrs (cfg.home.opencode.configFile != null) {
      "${opencodeConfigPath}" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.home.opencode.configFile;
        force = true;
      };
    };

    programs.opencode = {
      enable = true;
      package = pkgs.opencode;
    }
    // lib.optionalAttrs (cfg.home.opencode.configFile == null) {
      settings = pkgs.lib.recursiveUpdate (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json")) cfg.home.opencode.settings;
    };
  };
}
