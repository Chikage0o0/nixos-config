{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostSystem = pkgs.stdenv.hostPlatform.system;
  armbianBuild = pkgs.fetchFromGitHub {
    owner = "armbian";
    repo = "build";
    rev = "8b778f3d82fb8dcfb3d663187de890a3700c8ee2";
    hash = "sha256-rVX7uIRb4nOLxWcQ6iH4e3Qs9PhYabuVmFv5v9Uvo/Q=";
  };
  patchRoot = "${armbianBuild}/patch/kernel/archive/sunxi-7.0";
  # 保留内核自身的 override 接口，供 NixOS 注入 features/kernelPatches 等参数。
  pinnedKernel = import ../../../pkgs/linux-orangepi-zero3 {
    inherit (pkgs) fetchurl;
    linux = pkgs.linuxPackages_7_2.kernel;
  };
  kernelPatch = path: {
    name = baseNameOf path;
    patch = "${patchRoot}/${path}";
  };
  # 7.2 已定义完整 SRAM C 区域；复用上游节点，避免重复插入重叠的 sram-section@0。
  displayPipelinePatch =
    pkgs.runCommand "sunxi-display-pipeline-linux-7.2.patch"
      {
        nativeBuildInputs = [ pkgs.patchutils ];
      }
      ''
        filterdiff --hunks=1-3,5 \
          "${patchRoot}/patches.drm/0042-arm64-dts-allwinner-h616-Add-display-pipeline.patch" \
          > "$out"
        substituteInPlace "$out" --replace-fail '<&de3_sram 1>' '<&sram_c 1>'
      '';
  # Armbian 的补丁假定已应用无关的 modem-power 补丁；只调整过期的 Makefile 片段。
  addrMgtPatch =
    pkgs.runCommand "sunxi-addr-mgt.patch"
      {
        nativeBuildInputs = [ pkgs.patchutils ];
      }
      ''
            filterdiff -x 'a/drivers/misc/Makefile' \
              "${patchRoot}/patches.armbian/drv-misc-sunxi-add-addr-mgt-driver-uwe5622.patch" \
              > "$out"
            cat >> "$out" <<'PATCH'
        diff --git a/drivers/misc/Makefile b/drivers/misc/Makefile
        --- a/drivers/misc/Makefile
        +++ b/drivers/misc/Makefile
        @@ -75,3 +75,4 @@ obj-y				+= keba/
         obj-y				+= amd-sbi/
         obj-$(CONFIG_MISC_RP1)		+= rp1/
        +obj-$(CONFIG_SUNXI_ADDR_MGT)	+= sunxi-addr/
        PATCH
      '';
  uwe5622 = config.boot.kernelPackages.callPackage ../../../pkgs/uwe5622 { };
  hciattachOpi = pkgs.callPackage ../../../pkgs/hciattach-opi { };
  uwe5622Firmware =
    pkgs.runCommand "orangepi-zero3-uwe5622-firmware"
      {
        meta = pkgs.armbian-firmware.meta;
      }
      ''
        mkdir -p "$out/lib/firmware"
        cp -a "${pkgs.armbian-firmware}/lib/firmware/uwe5622" "$out/lib/firmware/"
        ln -s uwe5622/wifi_2355b001_1ant.ini \
          "$out/lib/firmware/wifi_2355b001_1ant.ini"
      '';
in
{
  # 板级模块自身声明目标平台，不依赖 mkHost 的旧 system 参数。
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  assertions = [
    {
      assertion = hostSystem == "aarch64-linux";
      message = "Orange Pi Zero 3 板级模块要求 aarch64-linux 主机平台";
    }
  ];

  boot = {
    kernelPackages = lib.mkForce (pkgs.linuxPackagesFor pinnedKernel);

    # Linux 7.2 已包含 Zero 3 的 CPU、SD 与 GMAC 设备树支持。
    # HDMI 和 AW859A 尚未进入主线，保留固定 Armbian 补丁集中兼容的部分。
    kernelPatches =
      map kernelPatch [
        "patches.drm/0032-drm-sun4i-Add-support-for-DE33-CSC.patch"
        "patches.drm/0033-drm-sun4i-vi_layer-Limit-formats-for-DE33.patch"
        "patches.drm/0034-clk-sunxi-ng-de2-Export-register-regmap-for-DE33.patch"
        "patches.drm/0035-dt-bindings-display-allwinner-Add-DE33-planes.patch"
        "patches.drm/0036-drm-sun4i-Add-planes-driver.patch"
        "patches.drm/0037-dt-bindings-display-allwinner-Update-H616-DE33-bindi.patch"
        "patches.drm/0038-drm-sun4i-switch-DE33-to-new-bindings.patch"
        "patches.drm/0039-drm-sun4i-Add-H616-TCON-TV-support.patch"
        "patches.drm/0040-srm-sun4i-Add-support-for-H616-HDMI-PHY.patch"
        "patches.drm/0041-drm-sun4i-Add-compatible-for-H616-display-engine.patch"
      ]
      ++ [
        {
          name = "sunxi-display-pipeline-linux-7.2.patch";
          patch = displayPipelinePatch;
        }
      ]
      ++ map kernelPatch [
        "patches.drm/0043-arm64-dts-allwinner-h616-Enable-HDMI-on-several-boar.patch"
        "patches.armbian/arm64-dts-sun50i-h616-orangepi-zero2-enable-usb1-vbus.patch"
        "patches.armbian/arm64-dts-sun50i-h616-orangepi-zero2-zero3-add-wifi.patch"
        "patches.armbian/drv-nvmem-sunxi-add-chipid-serial-helpers.patch"
        "patches.armbian/drv-bluetooth-hci-sprd-broken-park-link-quirk-v6.16-plus.patch"
      ]
      ++ [
        {
          name = "sunxi-addr-mgt.patch";
          patch = addrMgtPatch;
        }
        {
          # reset-gpio 不支持 Allwinner 的三单元 GPIO 描述；回退到旧 GPIO 路径。
          name = "mmc-pwrseq-simple-reset-gpio-fallback.patch";
          patch = ../../../pkgs/linux-orangepi-zero3/mmc-pwrseq-simple-reset-gpio-fallback.patch;
        }
        {
          name = "orangepi-zero3-required-kernel-options";
          patch = null;
          structuredExtraConfig = with lib.kernel; {
            DRM_SUN4I = yes;
            DRM_SUN8I_DW_HDMI = yes;
            DRM_SUN8I_MIXER = yes;
            DRM_SUN50I_PLANES = yes;
            SUNXI_ADDR_MGT = module;
            NVMEM_SUNXI_SID = yes;
            # Panfrost 的内建消费者探测前必须存在 H616 电源域。
            SUN50I_H6_PRCM_PPU = yes;
          };
        }
      ];

    initrd.availableKernelModules = [
      "mmc_block"
      "sunxi_mmc"
    ];
    extraModulePackages = [ uwe5622 ];
    kernelModules = [
      "sunxi_addr"
      "uwe5622_bsp_sdio"
      "sprdbt_tty"
      "sprdwl_ng"
    ];
    kernelParams = [
      "rootwait"
      "console=ttyS0,115200n8"
      "console=tty0"
      "consoleblank=0"
    ];
  };

  hardware = {
    # 板载 AW859A 仅需下方显式提供的 UWE5622 固件。
    enableRedistributableFirmware = lib.mkForce false;
    # UWE5622 驱动直接读取文件，无法处理内核固件加载器支持的压缩格式。
    firmwareCompression = "none";
    deviceTree = {
      filter = "sun50i-h618-orangepi-zero3.dtb";
      name = "allwinner/sun50i-h618-orangepi-zero3.dtb";
      overlays = [
        {
          name = "orangepi-zero3-address-manager";
          filter = "sun50i-h618-orangepi-zero3.dtb";
          dtsText = ''
            /dts-v1/;
            /plugin/;

            / {
              compatible = "xunlong,orangepi-zero3";
            };

            &{/soc} {
              addr_mgt: addr-mgt {
                compatible = "allwinner,sunxi-addr_mgt";
                type_addr_wifi = <0x2>;
                type_addr_bt = <0x2>;
                type_addr_eth = <0x2>;
                status = "okay";
              };
            };
          '';
        }
      ];
    };
    firmware = [ uwe5622Firmware ];
    wirelessRegulatoryDatabase = true;
  };
  # 厂商驱动硬编码 /lib/firmware；在加载模块前提供稳定的运行时路径。
  system.activationScripts.uwe5622FirmwareLink = ''
    ln -sfn /run/current-system/firmware /lib/firmware
  '';

  systemd.services.aw859a-bluetooth = {
    description = "Initialize the Orange Pi Zero 3 AW859A Bluetooth controller";
    wantedBy = [ "multi-user.target" ];
    before = [ "bluetooth.service" ];
    after = [ "systemd-modules-load.service" ];
    unitConfig = {
      ConditionPathExists = "/dev/ttyBT0";
      StartLimitIntervalSec = "30s";
      StartLimitBurst = 5;
    };
    serviceConfig = {
      Type = "simple";
      ExecStart = "${hciattachOpi}/bin/hciattach_opi -n -s 1500000 /dev/ttyBT0 sprd";
      Restart = "on-failure";
      RestartSec = "2s";
    };
  };
}
