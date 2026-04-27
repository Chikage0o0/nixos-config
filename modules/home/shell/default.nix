{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
  loadSopsSecrets = lib.concatMapStringsSep "\n" (name: ''
    if [ -f "/run/secrets/${name}" ]; then
      ${pkgs.openssh}/bin/ssh-add "/run/secrets/${name}" >/dev/null 2>&1
    fi
  '') cfg.home.sshAgent.sopsSecrets;
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
      initContent = lib.mkIf cfg.home.sshAgent.enable ''
        ssh-add -l >/dev/null 2>&1
        ssh_agent_state=$?

        if [ "$ssh_agent_state" -eq 2 ]; then
          eval "$(${pkgs.openssh}/bin/ssh-agent -s)" >/dev/null
          ssh_agent_state=1
        fi

        if [ "$ssh_agent_state" -eq 1 ]; then
          ${loadSopsSecrets}
        fi
      '';
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
