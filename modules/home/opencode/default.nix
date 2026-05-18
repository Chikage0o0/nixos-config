{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  inputs,
  ...
}:
let
  cfg = config.platform;
  opencodeConfigPath = ".config/opencode/opencode.json";
  ohMyOpenCodeSlimConfig = pkgs.lib.recursiveUpdate (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/oh-my-opencode-slim.json")) cfg.home.opencode.ohMyOpenCodeSlimSettings;
in
{
  config = lib.mkIf cfg.home.opencode.enable {
    home.packages = [ pkgsUnstable.openspec ];

    home.file = {
      ".config/opencode/skills/".source = "${inputs.opencode-config}/skills";
      ".config/opencode/agent/".source = "${inputs.opencode-config}/agent";
      ".config/opencode/commands/".source = "${inputs.opencode-config}/commands";
      ".config/opencode/AGENTS.md".source = "${inputs.opencode-config}/AGENTS.md";
      ".config/opencode/plugins/".source = "${inputs.opencode-config}/plugins";
      ".config/opencode/tui.json".source = "${inputs.opencode-config}/tui.json";
      ".config/opencode/oh-my-opencode-slim.json".text = builtins.toJSON ohMyOpenCodeSlimConfig;
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
