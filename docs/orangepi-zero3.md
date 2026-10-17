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
`config.system.build.sdImage` 构建。日常受管配置不必导入 image 模块，
但必须保留根挂载（默认 `/dev/disk/by-label/NIXOS_SD`、ext4）和
`machine.boot.mode = "extlinux"`；首次分区扩容由镜像启动服务执行。

## 启动模式与 U-Boot 边界

`machine.boot.mode` 支持 `uefi`、`bios`、`extlinux`：
前两者使用 GRUB；extlinux 不启用 GRUB/systemd-boot，也不写 EFI variables。
`machine.boot.grubDevice` 仅用于 BIOS，不能与 extlinux 一起设置。
U-Boot 位于文件系统以外，普通 NixOS generation 更新不会更新或回滚该区域。

## 内核与驱动固定

内核源码版本、模块目录版本和 hash 显式固定为 Linux 7.2.11，不跟随
`linuxPackages_latest` 自动升级。配套固定 Armbian `sunxi-7.2` 补丁与 UWE5622 源码；
显示设备树补丁复用 7.2 上游已有的 SRAM C 节点，避免创建重叠 SRAM 区域。
公开模块不含 SSH 身份、代理凭据、HA 实例或 Tailscale 网络策略。
`pkgs/home-assistant-python-deps.nix` 提供固定 HA 自定义集成依赖，
调用时传入 `pkgs.home-assistant.python3Packages`；其中 mini-racer wheel 仅支持 aarch64。
升级内核或依赖锁后需重新构建并在设备验证 SD、以太网、Wi-Fi、蓝牙和 HDMI。

## 构建要求

配置采用原生 aarch64 构建以复用公共软件包缓存；
在 x86_64 构建机上需使用 ARM builder 或 aarch64 binfmt。

## 支持状态

- Linux 7.2.11、UWE5622 和 hciattach-opi 已完成从 x86_64 到 aarch64 的交叉构建：
  内核产物为 ARM64 Image，已生成 Zero 3 DTB，三个无线/蓝牙模块的 vermagic 均为
  `7.2.11 SMP preempt mod_unload aarch64`。
- 完整 SD 镜像构建与实机启动、Wi-Fi、蓝牙、HDMI 验收尚未完成；交叉构建通过不等于实机可用。
