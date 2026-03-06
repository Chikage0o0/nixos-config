{
  lib,
  varsExt,
  inputs,
  ...
}:
{
  imports = [
    ../../modules/nixos
  ]
  ++ lib.optionals varsExt.isWSL [ inputs.nixos-wsl.nixosModules.default ]
  ++ (if varsExt.isWSL then [ ] else [ /etc/nixos/hardware-configuration.nix ]);

  networking.hostName = varsExt.hostName;

}
// lib.optionalAttrs varsExt.isWSL {
  wsl = {
    enable = true;
    defaultUser = varsExt.username;
    interop.register = true;
  };
}
