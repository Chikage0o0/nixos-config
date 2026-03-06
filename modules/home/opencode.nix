{
  config,
  pkgs,
  varsExt,
  inputs,
  ...
}:
{
  home.file = {
    ".config/opencode/skills/".source = "${inputs.opencode-config}/skills";
    ".config/opencode/AGENTS.md".source = "${inputs.opencode-config}/AGENTS.md";
    ".config/opencode/plugins/".source = "${inputs.opencode-config}/plugins";
  };

  programs.opencode = {
    enable = true;
    package = inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default;
    settings = pkgs.lib.recursiveUpdate (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json")) varsExt.opencodeSettings;
  };

  systemd.user.services.opencode-serve = {
    Unit = {
      Description = "OpenCode Serve";
      After = [ "network.target" ];
    };
    Service = {
      Environment = [
        "PATH=${config.home.profileDirectory}/bin:/etc/profiles/per-user/${varsExt.username}/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin"
      ];
      ExecStart = "${config.programs.opencode.package}/bin/opencode serve --port 14096 --hostname 0.0.0.0";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
