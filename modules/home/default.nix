{ ... }:
{
  imports = [
    ../shared/options.nix
    ./core/base.nix
    ./git
    ./shell
    ./development/cli-tools.nix
    ./development/packages.nix
    ./development/mirrors.nix
    ./opencode
  ];
}
