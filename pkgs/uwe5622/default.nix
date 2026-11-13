{
  fetchFromGitHub,
  kernel,
  kernelModuleMakeFlags,
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "uwe5622";
  version = "0-unstable-2026-11-09-${kernel.version}";

  src = fetchFromGitHub {
    owner = "armbian";
    repo = "uwe5622";
    rev = "6a6387247c12bf6f0f5c1ed7da8b782623a74ea0";
    hash = "sha256-qLDlI/Unu12ysxeIwT3nQLle2p9VLtAuKgFMhn2Z7d0=";
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
