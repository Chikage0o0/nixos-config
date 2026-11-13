# Orange Pi Zero 3 支持

面向 Zero 3（H618）的板级支持：两个按需导入的公共模块，不在其他主机上自动启用。

- `nixosModules.orangepi-zero3`：H618 板级内核、DTB、UWE5622 驱动/固件与蓝牙初始化。
  仅支持 `aarch64-linux` 目标，内部从 `pkgs.stdenv` 推导与主机包集一致的内核构建平台；
  调用方不需要传递内核包集或额外模块参数。
- `nixosModules.orangepi-zero3-image`：SD 分区、extlinux 文件填充、
  8 KiB 偏移处的 U-Boot/SPL 写入与 `.img.xz` 压缩。
  使用时需同时导入板级模块并选择 extlinux 启动。

## 主机接入

通过现有 `lib.mkHost` 组合：

```nix
{
  system = "aarch64-linux";
  stateVersion = "26.05";
  profiles = [ "server-base" ];
  machine.boot.mode = "extlinux";
  hardwareModules = [ public.nixosModules.orangepi-zero3 ];
  extraModules = [
    public.nixosModules.orangepi-zero3-image
    # 主机自己的网络、用户和设备策略模块
  ];
}
```

以上是主机声明片段，仍需提供 `hostname` 和 `user`。镜像通过
`config.system.build.sdImage` 构建。固定 H618/SD 启动链不启用 SD 模板的全硬件 initrd profile，
使用板级 MMC 和默认文件系统驱动；其他设备仍可在进入根文件系统后加载模块。
日常受管配置不必导入 image 模块，
但必须保留根挂载（默认 `/dev/disk/by-label/NIXOS_SD`、ext4）和
`machine.boot.mode = "extlinux"`；首次分区扩容由镜像启动服务执行。

## 启动模式与 U-Boot 边界

`machine.boot.mode` 支持 `uefi`、`bios`、`extlinux`：
前两者使用 GRUB；extlinux 不启用 GRUB/systemd-boot，也不写 EFI variables。
`machine.boot.grubDevice` 仅用于 BIOS，不能与 extlinux 一起设置。
U-Boot 位于文件系统以外，普通 NixOS generation 更新不会更新或回滚该区域。

## 内核与驱动固定

内核源码、模块目录和 hash 固定为 Linux 7.3.4，基于 `linuxPackages_7_3`，
不跟随 `linuxPackages_latest` 自动升级。板级补丁选自 Armbian build
`99bc323758a9448dc1a5274d6aaaca32769fef76` 的 `sunxi-7.3` 栈，仅引入所需显示、
Wi-Fi、蓝牙和地址管理支持，不引入 p-boot；UWE5622 固定到
`6a6387247c12bf6f0f5c1ed7da8b782623a74ea0`。保留三单元 GPIO 的 MMC reset 回退。
公开模块不含 SSH 身份、代理凭据、HA 实例或 Tailscale 网络策略。
`pkgs/home-assistant-python-deps.nix` 提供固定 HA 自定义集成依赖，
调用时传入 `pkgs.home-assistant.python3Packages`；其中 mini-racer wheel 仅支持 aarch64。
升级内核或依赖锁后需重新构建并在设备验证 SD、以太网、Wi-Fi、蓝牙和 HDMI。

## 构建要求

配置采用原生 aarch64 构建以复用公共软件包缓存；
在 x86_64 构建机上需使用 ARM builder 或 aarch64 binfmt。

## 支持状态

- Linux 7.3.4 和固定版本 UWE5622 已完成从 x86_64 到 aarch64 的交叉构建；
  已核对实际内核配置中的 Rust、FORTIFY、MMC、GMAC、显示及地址管理支持，以及模块的 ARM64 ELF 和 7.3.4 vermagic。
- 最终 DTB 已检查 phandle 唯一性、显示端点互相引用和 Wi-Fi reset GPIO provider；这些检查不能代替实体外设验收。
- 调用方已构建完整受管系统和首次 SD 镜像，并离线核对 MBR、SPL 位置、extlinux 默认目标，以及镜像内 kernel、initrd 和最终 DTB 与目标产物的哈希一致性。
- 升级需重新构建日常系统及首次 SD 镜像；构建通过不等于实机可用。部署后仍需在设备上
  验证启动、SD、以太网、Wi-Fi、蓝牙和 HDMI；U-Boot 区域不随系统 generation 更新。
