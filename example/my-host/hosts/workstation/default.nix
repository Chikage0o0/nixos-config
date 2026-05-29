{ config, lib, ... }:
let
  opencodeTemplate = builtins.readFile ../../templates/opencode-config.template.json;
in
{
  users.users.${config.platform.user.name}.hashedPasswordFile = lib.mkIf (
    config ? sops
  ) config.sops.secrets."user/hashedPassword".path;

  sops.templates."opencode-config.json" = {
    owner = config.platform.user.name;
    mode = "0400";
    content = lib.replaceStrings
      [ "__OPENCODE_API_KEY__" ]
      [ config.sops.placeholder."opencode/apiKey" ]
      opencodeTemplate;
  };

  platform.home.opencode.configFile = config.sops.templates."opencode-config.json".path;
  platform.home.sshAgent.sopsSecrets = [ "ssh_private_key" ];
}
