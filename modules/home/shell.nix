{
  varsExt,
  pkgs,
  ...
}:
let
  configDir = varsExt.configDir;
  sshKeysDir = varsExt.sshKeysDir;
  hostName = varsExt.hostName;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      ll = "ls -l";
      update-geoip = "bash ${configDir}/pkgs/v2ray-rules-dat/update-v2ray-rules-dat.sh";
      update = "bash ${configDir}/pkgs/v2ray-rules-dat/update-v2ray-rules-dat.sh && nix flake update opencode-config --flake ${configDir} && sudo nixos-rebuild switch --flake ${configDir}#${hostName} --impure";
      clean = "nix-collect-garbage -d";
    };

    initContent = ''
      ssh-add -l >/dev/null 2>&1
      ssh_agent_state=$?

      if [ "$ssh_agent_state" -eq 2 ]; then
        eval "$(${pkgs.openssh}/bin/ssh-agent -s)" >/dev/null
        ssh_agent_state=1
      fi

      if [ "$ssh_agent_state" -eq 1 ]; then
        ssh_keys_dir="${sshKeysDir}"
        ssh_keys_dir="''${ssh_keys_dir/#\~/$HOME}"

        if [ -d "$ssh_keys_dir" ]; then
          for key_file in "$ssh_keys_dir"/*; do
            [ -f "$key_file" ] || continue

            case "$key_file" in
              *.pub|*.txt|*.md) continue ;;
            esac

            ${pkgs.openssh}/bin/ssh-add "$key_file" >/dev/null 2>&1
          done
        fi
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
