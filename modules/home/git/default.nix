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
      lfs = {
        enable = true;
        skipSmudge = false;
      };
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

    programs.gh = {
      enable = true;
      # GitHub HTTPS 操作优先使用 gh 已登录凭据，避免无交互环境落到 askpass 后失败。
      gitCredentialHelper = {
        enable = true;
        hosts = [
          "https://github.com"
          "https://gist.github.com"
        ];
      };
      settings = {
        git_protocol = "https";
        prompt = "enabled";
      };
    };
  };
}
