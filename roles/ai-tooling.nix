{ lib, ... }:
{
  services.orca-server.enable = lib.mkDefault true;
  home-manager.sharedModules = [
    {
      programs.omp.enable = lib.mkDefault true;
    }
  ];
  platform.home.shell.enable = lib.mkDefault true;
  platform.home.rtk.enable = lib.mkDefault true;
}
