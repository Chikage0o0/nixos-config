{
  vars,
  pkgs,
  ...
}:
let
  configDir = vars.configDir or "~/nixos-config";
  hostName = vars.hostName or "dev-machine";
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
