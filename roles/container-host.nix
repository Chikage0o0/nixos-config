{ lib, ... }:
{
  platform.containers.podman.enable = lib.mkDefault true;
}
