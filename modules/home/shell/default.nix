{
  config,
  lib,
  ...
}:
let
  cfg = config.platform;
in
{
  config = lib.mkIf cfg.home.shell.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -l";
        clean = "nix-collect-garbage -d";
      };
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        ForwardAgent = false;
        AddKeysToAgent = "yes";
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = fromTOML (builtins.readFile ../../../home/starship.toml);
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };
  };
}
