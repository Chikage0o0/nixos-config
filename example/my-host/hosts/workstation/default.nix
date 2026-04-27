{ config, lib, ... }:
{
  users.users.${config.platform.user.name}.hashedPasswordFile =
    lib.mkIf (config ? sops) config.sops.secrets."user/hashedPassword".path;

  sops.templates."opencode-config.json" = {
    owner = config.platform.user.name;
    mode = "0400";
    content = builtins.toJSON {
      provider = {
        openai.options.apiKey = config.sops.placeholder."opencode/apiKey";
      };
    };
  };

  platform.home.opencode.configFile = config.sops.templates."opencode-config.json".path;
  platform.home.sshAgent.sopsSecrets = [ "ssh_private_key" ];
}
