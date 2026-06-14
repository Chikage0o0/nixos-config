{
  config,
  lib,
  ...
}:
let
  cfg = config.platform;
  # Tabby 通过 iTerm2 兼容的 OSC 1337 CurrentDir 序列获取远端/WSL/tmux
  # 中的当前目录。统一走各 shell 的 prompt hook，避免污染 prompt 字符串。
  tabbyShellReporting = {
    bash = ''
      __platform_tabby_report_cwd() {
        printf '\033]1337;CurrentDir=%s\a' "$PWD"
      }

      case "$(declare -p PROMPT_COMMAND 2>/dev/null)" in
        declare\ -a*)
          if [[ " ''${PROMPT_COMMAND[*]} " != *" __platform_tabby_report_cwd "* ]]; then
            PROMPT_COMMAND=(__platform_tabby_report_cwd "''${PROMPT_COMMAND[@]}")
          fi
          ;;
        *)
          case ";''${PROMPT_COMMAND:-};" in
            *";__platform_tabby_report_cwd;"*) ;;
            *) PROMPT_COMMAND="__platform_tabby_report_cwd''${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
          esac
          ;;
      esac
    '';

    zsh = ''
      __platform_tabby_report_cwd() {
        printf '\033]1337;CurrentDir=%s\a' "$PWD"
      }

      if [[ -z ''${precmd_functions[(r)__platform_tabby_report_cwd]} ]]; then
        precmd_functions+=(__platform_tabby_report_cwd)
      fi
    '';

    fish = ''
      function __platform_tabby_report_cwd --on-event fish_prompt
          printf '\033]1337;CurrentDir=%s\a' "$PWD"
      end
    '';

    nushell = ''
      $env.config = (
        $env.config
        | upsert hooks.pre_prompt (
            $env.config.hooks.pre_prompt?
            | default []
            | append {||
                print -n $"(char esc)]1337;CurrentDir=($env.PWD)(char bel)"
              }
          )
      )
    '';
  };
in
{
  config = lib.mkIf cfg.home.shell.enable {
    programs.bash.initExtra = lib.mkAfter tabbyShellReporting.bash;

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      initContent = lib.mkAfter tabbyShellReporting.zsh;
      shellAliases = {
        ll = "ls -l";
        clean = "nix-collect-garbage -d";
      };
    };

    programs.fish.interactiveShellInit = lib.mkAfter tabbyShellReporting.fish;

    programs.nushell.extraConfig = lib.mkAfter tabbyShellReporting.nushell;

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
