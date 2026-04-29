{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform.machine;
in
{
  config = lib.mkMerge [
    {
      hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
      hardware.enableRedistributableFirmware = lib.mkDefault true;
    }

    (lib.mkIf cfg.powerProfiles.enable {
      services.power-profiles-daemon.enable = true;
    })

    (lib.mkIf cfg.brightness.enable {
      environment.systemPackages = [ pkgs.brightnessctl ];
    })
  ];
}
