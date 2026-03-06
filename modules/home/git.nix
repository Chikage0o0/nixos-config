{
  pkgs,
  varsExt,
  ...
}:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = varsExt.userFullName;
        email = varsExt.userEmail;
        signingKey = varsExt.sshPublicKey;
      };
      init.defaultBranch = "main";
      gpg.format = "ssh";
      "gpg \"ssh\"".program = "${pkgs.openssh}/bin/ssh-keygen";
      commit.gpgsign = true;
    };
  };
}
