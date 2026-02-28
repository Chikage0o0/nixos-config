{
  pkgs,
  vars,
  ...
}:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = vars.userFullName;
        email = vars.userEmail;
        signingKey = vars.sshPublicKey;
      };
      init.defaultBranch = "main";
      gpg.format = "ssh";
      "gpg \"ssh\"".program = "${pkgs.openssh}/bin/ssh-keygen";
      commit.gpgsign = true;
    };
  };
}
