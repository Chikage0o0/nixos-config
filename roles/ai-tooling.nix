{ lib, ... }:
{
  home-manager.sharedModules = [
    {
      programs.omp.enable = lib.mkDefault true;
    }
  ];
  platform.home.shell.enable = lib.mkDefault true;
  platform.home.rtk.enable = lib.mkDefault true;
}
