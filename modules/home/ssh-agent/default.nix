{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform.home.sshAgent;
  socket = config.services.ssh-agent.socket;
  addKeysScript = pkgs.writeShellScript "ssh-add-sops-keys" ''
    ${lib.concatMapStringsSep "\n" (name: ''
      if [ -f "/run/secrets/${name}" ]; then
        ${lib.getExe' pkgs.openssh "ssh-add"} "/run/secrets/${name}" >/dev/null
      fi
    '') cfg.sopsSecrets}
  '';
in
{
  config = lib.mkIf cfg.enable {
    services.ssh-agent.enable = true;

    systemd.user.sessionVariables.SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/${socket}";

    # No keys configured means there is nothing to preload into the session agent.
    systemd.user.services.ssh-add-sops-keys = lib.mkIf (cfg.sopsSecrets != [ ]) {
      Unit = {
        Description = "Load configured SSH keys into ssh-agent";
        Wants = [ "ssh-agent.service" ];
        After = [ "ssh-agent.service" ];
        PartOf = [ "ssh-agent.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        Environment = [ "SSH_AUTH_SOCK=%t/${socket}" ];
        ExecStart = toString addKeysScript;
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
