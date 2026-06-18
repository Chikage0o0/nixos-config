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
    ./hardware/intel.nix
    ./hardware/amd.nix
    ./hardware/nvidia.nix
    ./containers/podman.nix
    ./packages/system.nix
    ./i18n/chinese.nix
    ./desktop/plasma.nix
  ];
}
