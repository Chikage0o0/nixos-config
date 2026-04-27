{
  config,
  lib,
  ...
}:
let
  cfg = config.platform.services.openssh;
in
{
  services.openssh = lib.mkIf cfg.enable {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
