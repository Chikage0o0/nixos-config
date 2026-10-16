{
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "uwe5622";
  version = "0-unstable-2026-10-13-${kernel.version}";

  src = fetchFromGitHub {
    owner = "armbian";
    repo = "uwe5622";
    rev = "fa9d1a6703a93a85bcf68e865ebc2726474076ad";
    hash = "sha256-kbv1O0qPKnUGSrv4B+nq1YZcYZPOziWAeLw2aOkFhPA=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  postPatch = ''
    substituteInPlace Makefile \
      --replace-fail 'obj-y += unisocwcn/' 'obj-m += unisocwcn/'
  '';

  buildPhase = ''
    runHook preBuild
    make ${lib.escapeShellArgs kernelModuleMakeFlags} \
      -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M=$PWD \
      KERNELRELEASE=${kernel.modDirVersion} \
      UNISOC_BSP_INCLUDE=$PWD/unisocwcn/include \
      CONFIG_AW_WIFI_DEVICE_UWE5622=y \
      CONFIG_WLAN_UWE5622=m \
      CONFIG_TTY_OVERY_SDIO=m \
      modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    moduleDir=$out/lib/modules/${kernel.modDirVersion}/extra
    mkdir -p "$moduleDir"
    find . -name '*.ko' -exec cp -v '{}' "$moduleDir"/ \;
    runHook postInstall
  '';

  meta = {
    description = "Out-of-tree AW859A/UWE5622 Wi-Fi and Bluetooth driver";
    homepage = "https://github.com/armbian/uwe5622";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
  };
}
