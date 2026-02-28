{
  lib,
  vars,
  inputs,
  ...
}:
{
  imports = [
    ../../modules/nixos
  ]
  ++ lib.optionals vars.isWSL [ inputs.nixos-wsl.nixosModules.default ]
  ++ (if vars.isWSL then [ ] else [ /etc/nixos/hardware-configuration.nix ]);

  networking.hostName = vars.hostName or "dev-machine";

}
// lib.optionalAttrs vars.isWSL {
  wsl = {
    enable = true;
    defaultUser = vars.username or "nixos";
  };
}
