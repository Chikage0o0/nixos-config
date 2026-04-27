{ config, lib, ... }:
{
  config = lib.mkIf config.platform.home.cliTools.enable {
    programs.eza = {
      enable = true;
      enableZshIntegration = true;
      icons = "auto";
      git = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.bat = {
      enable = true;
      config.theme = "TwoDark";
    };

    programs.lazygit.enable = true;
  };
}
