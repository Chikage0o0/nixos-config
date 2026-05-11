{ lib, ... }:
{
  platform.home.hermes.enable = lib.mkDefault true;
  platform.home.hermes.service.enable = lib.mkDefault true;
  platform.home.shell.enable = lib.mkDefault true;
  platform.home.git.enable = lib.mkDefault true;
}
