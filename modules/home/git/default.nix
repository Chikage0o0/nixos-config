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
        # GitHub HTTPS 操作优先使用 gh 已登录凭据，避免无交互环境落到 askpass 后失败。
        "credential \"https://github.com\"".helper = [ "!${pkgs.gh}/bin/gh auth git-credential" ];
        "credential \"https://gist.github.com\"".helper = [ "!${pkgs.gh}/bin/gh auth git-credential" ];
        commit.gpgsign = true;
      };
    };
  };
}
