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
  config = lib.mkIf cfg.home.git.enable {
    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user = {
          name = cfg.user.fullName;
          email = cfg.user.email;
          signingKey = cfg.user.sshPublicKey;
        };
        init.defaultBranch = "main";
        gpg.format = "ssh";
        "gpg \"ssh\"".program = "${pkgs.openssh}/bin/ssh-keygen";
        commit.gpgsign = true;
      };
    };
  };
}
