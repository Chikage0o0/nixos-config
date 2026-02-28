{
  pkgs,
  vars,
  ...
}:
{
  users.users.${vars.username} = {
    isNormalUser = true;
    description = vars.userFullName;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    initialPassword = vars.initialPassword;
    openssh.authorizedKeys.keys = [
      vars.sshPublicKey
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ vars.username ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
