{
  fetchFromGitHub,
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "hciattach-opi";
  version = "0-unstable-2026-06-29";

  src = fetchFromGitHub {
    owner = "orangepi-xunlong";
    repo = "orangepi-build";
    rev = "bdba421984211da19191dc6ac6818a247817335f";
    hash = "sha256-E/5bSALLlMK0e6YqZv1pvcPhXtwC7s8INNqmVr1pBgc=";
  };

  patches = [ ./guard-missing-bt-address.patch ];

  sourceRoot = "source/external/cache/sources/hcitools";
  postPatch = ''
    substituteInPlace hciattach.c \
      --replace-fail \
        '{  "sprd",      0x0000, 0x0000, NULL,' \
        '{  "sprd",      0x0000, 0x0000, HCI_UART_H4,'
    substituteInPlace hciattach_qualcomm.c hciattach_sprd.c hciattach_tialt.c \
      --replace-fail \
        '#include <sys/ioctl.h>' \
        $'#include <sys/ioctl.h>\n#include <sys/uio.h>'
    substituteInPlace rule.mk \
      --replace-fail \
        'OUTPUT_BIN := $(shell (mkdir -p output); cd ./output; pwd)' \
        'OUTPUT_BIN := output' \
      --replace-fail \
        'BINDIR := $(shell cd $(pwd))/$(OUTPUT_BIN)' \
        'BINDIR := output'
  '';

  buildPhase = ''
    runHook preBuild
    mkdir -p output
    make CC=$CC hciattach_opi
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 output/hciattach_opi $out/bin/hciattach_opi
    runHook postInstall
  '';

  meta = {
    description = "Orange Pi hciattach with Spreadtrum/Unisoc initialization";
    homepage = "https://github.com/orangepi-xunlong/orangepi-build";
    license = lib.licenses.gpl2Only;
    platforms = [ "aarch64-linux" ];
    mainProgram = "hciattach_opi";
  };
}
