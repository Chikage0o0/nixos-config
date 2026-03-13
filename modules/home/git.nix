{
  config,
  pkgs,
  ...
}:
let
  cfg = config.myConfig;
in
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = cfg.userFullName;
        email = cfg.userEmail;
        signingKey = cfg.sshPublicKey;
      };
      init.defaultBranch = "main";
      gpg.format = "ssh";
      "gpg \"ssh\"".program = "${pkgs.openssh}/bin/ssh-keygen";
      commit.gpgsign = true;
    };
  };
}
