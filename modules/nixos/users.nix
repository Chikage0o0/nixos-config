{
  config,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
in
{
  users.users.${cfg.username} = {
    isNormalUser = true;
    description = cfg.userFullName;
    linger = true;
    extraGroups = [
      "networkmanager"
      "wheel"
      "podman"
      "dialout"
    ];
    shell = pkgs.zsh;
    # 密码由 sops-nix 管理，此处仅作为备用
    # initialPassword = "changeme";
    openssh.authorizedKeys.keys = [
      cfg.sshPublicKey
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ cfg.username ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
