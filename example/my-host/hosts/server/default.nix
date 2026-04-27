{ config, lib, ... }:
{
  users.users.${config.platform.user.name}.hashedPasswordFile = lib.mkIf (
    config ? sops
  ) config.sops.secrets."user/hashedPassword".path;
}
