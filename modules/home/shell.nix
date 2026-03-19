{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.myConfig;
  sshSopsSecrets = cfg.sshSopsSecrets;
  enableSshAgent = cfg.enableSshAgent;

  # 生成加载 sops secret 的脚本
  loadSopsSecrets = lib.concatMapStringsSep "\n" (name: ''
    if [ -f "/run/secrets/${name}" ]; then
      ${pkgs.openssh}/bin/ssh-add "/run/secrets/${name}" >/dev/null 2>&1
    fi
  '') sshSopsSecrets;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      clean = "nix-collect-garbage -d";
    };

    initContent = lib.mkIf enableSshAgent ''
      ssh-add -l >/dev/null 2>&1
      ssh_agent_state=$?

      if [ "$ssh_agent_state" -eq 2 ]; then
        eval "$(${pkgs.openssh}/bin/ssh-agent -s)" >/dev/null
        ssh_agent_state=1
      fi

      if [ "$ssh_agent_state" -eq 1 ]; then
        # 加载 sops 解密的私钥
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
    settings = fromTOML (builtins.readFile ../../home/starship.toml);
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };
}
