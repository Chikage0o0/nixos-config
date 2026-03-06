{ varsExt, ... }:
{
  home.username = varsExt.username;
  home.homeDirectory = "/home/${varsExt.username}";
  home.stateVersion = "25.11";
}
