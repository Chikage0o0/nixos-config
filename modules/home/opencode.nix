{
  config,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.myConfig;
in
{
  home.file = {
    ".config/opencode/skills/".source = "${inputs.opencode-config}/skills";
    ".config/opencode/AGENTS.md".source = "${inputs.opencode-config}/AGENTS.md";
    ".config/opencode/plugins/".source = "${inputs.opencode-config}/plugins";
  };

  programs.opencode = {
    enable = true;
    package = pkgs.opencode;
    settings = pkgs.lib.recursiveUpdate (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json")) cfg.opencodeSettings;
  };
}
