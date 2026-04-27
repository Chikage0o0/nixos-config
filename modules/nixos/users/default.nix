{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
in
{
  users.users.${cfg.user.name} = {
    isNormalUser = true;
    description = cfg.user.fullName;
    linger = true;
    extraGroups =
      [ "wheel" ]
      ++ lib.optionals (!cfg.machine.wsl.enable) [
        "networkmanager"
        "dialout"
      ]
      ++ lib.optionals cfg.containers.podman.enable [ "podman" ];
    shell = pkgs.zsh;
    # 密码由 sops-nix 管理，此处仅作为备用
    # initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      cfg.user.sshPublicKey
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ cfg.user.name ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
