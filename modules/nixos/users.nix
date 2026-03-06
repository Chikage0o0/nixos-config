{
  pkgs,
  varsExt,
  ...
}:
{
  users.users.${varsExt.username} = {
    isNormalUser = true;
    description = varsExt.userFullName;
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
    ];
    shell = pkgs.zsh;
    initialPassword = varsExt.initialPassword;
    openssh.authorizedKeys.keys = [
      varsExt.sshPublicKey
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ varsExt.username ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
