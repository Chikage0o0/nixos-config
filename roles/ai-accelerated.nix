{
  config,
  lib,
  pkgs,
  ...
}:
let
  gpu = config.platform.machine.gpu;
in
{
  config = lib.mkMerge [
    (lib.mkIf gpu.nvidia.enable {
      hardware.nvidia-container-toolkit.enable = true;
      environment.systemPackages = [ pkgs.cudatoolkit ];
    })

    (lib.mkIf gpu.amd.enable {
      hardware.amdgpu.opencl.enable = true;
      environment.systemPackages = [ pkgs.rocmPackages.rocminfo ];
    })

    (lib.mkIf gpu.intel.enable {
      environment.systemPackages = [
        pkgs.openvino
        pkgs.intel-compute-runtime
      ];
    })
  ];
}
