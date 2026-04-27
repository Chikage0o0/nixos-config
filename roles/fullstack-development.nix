{ lib, ... }:
{
  platform.development.fullstack.enable = lib.mkDefault true;
  platform.home.git.enable = lib.mkDefault true;
  platform.home.shell.enable = lib.mkDefault true;
  platform.home.cliTools.enable = lib.mkDefault true;
}
