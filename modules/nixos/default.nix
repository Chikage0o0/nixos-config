{ ... }:
{
  imports = [
    ./base.nix
    ./network.nix
    ./users.nix
    ./virtualisation.nix
    ./packages.nix
    ./services/dae.nix
    ./services/openssh.nix
    ./hardware/nvidia.nix
  ];
}
