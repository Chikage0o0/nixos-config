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
      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
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
