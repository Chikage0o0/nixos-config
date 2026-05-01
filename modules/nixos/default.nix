{ ... }:
{
  imports = [
    ../shared/options.nix
    ./core/base.nix
    ./core/assertions.nix
    ./boot/grub.nix
    ./users
    ./networking/base.nix
    ./services/cockpit.nix
    ./services/openssh.nix
    ./hardware/nvidia.nix
    ./hardware/workstation.nix
    ./containers/podman.nix
    ./packages/system.nix
    ./desktop/plasma.nix
  ];
}
