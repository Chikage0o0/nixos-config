# lib/default.nix
# 导出库模块
{
  inputs,
  self,
}:
let
  platform = import ./platform { inherit inputs self; };
in
platform
// {
  inherit platform;
}
