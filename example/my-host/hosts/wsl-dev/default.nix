{ config, lib, ... }:
{
  wsl = {
    enable = true;
    defaultUser = config.platform.user.name;
    interop.register = true;
  };

  users.users.${config.platform.user.name}.hashedPasswordFile =
    lib.mkIf (config ? sops) config.sops.secrets."user/hashedPassword".path;
}
