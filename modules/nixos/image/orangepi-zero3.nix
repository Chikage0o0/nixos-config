{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];

  image.baseName = "nixos-orangepi-zero3";
  image.extension = lib.mkForce "img.xz";

  sdImage = {
    compressImage = false;
    firmwareSize = 64;
    populateFirmwareCommands = "";
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -c ${config.system.build.toplevel} \
        -d ./files/boot
    '';

    # Allwinner Boot ROM 在 8 KiB 处读取 SPL；第一分区从 8 MiB 开始。
    postBuildCommands = ''
      dd if=${pkgs.ubootOrangePiZero3}/u-boot-sunxi-with-spl.bin \
        of=$img bs=1024 seek=8 conv=notrunc
      ${pkgs.buildPackages.xz}/bin/xz --threads=2 --compress -6 "$img"
      echo "file sd-image $img.xz" > "$out/nix-support/hydra-build-products"
    '';
  };
}
