# V2Ray Rules DAT Package

这个 package 自动从 [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat) 下载最新版本的 `geoip.dat` 和 `geosite.dat` 文件,用于 dae 等代理软件的路由规则。

## 功能特性

- ✅ 自动从 GitHub Releases 下载最新版本
- ✅ 自动计算文件 hash 值确保完整性
- ✅ 集成到 NixOS 配置中,声明式管理
- ✅ 提供便捷的更新脚本

## 文件说明

- `v2ray-rules-dat.nix` - NixOS derivation,定义如何下载和安装文件
- `update-v2ray-rules-dat.sh` - 自动更新脚本,获取最新版本并更新 .nix 文件

## 使用方法

### 1. 在 configuration.nix 中使用

已在 `configuration.nix` 中配置:

```nix
services.dae = {
  enable = true;
  configFile = ./dae/config.dae;
  assets = with pkgs; [
    (pkgs.callPackage ./pkgs/v2ray-rules-dat/v2ray-rules-dat.nix { })
  ];
};
```

### 2. 更新到最新版本

#### 方法一: 使用 shell alias (推荐)

```bash
# 仅更新 geoip/geosite 数据
update-geoip

# 更新 geoip/geosite 并重建系统(自动执行)
update
```

#### 方法二: 手动运行脚本

```bash
cd ~/nixos-config
bash pkgs/v2ray-rules-dat/update-v2ray-rules-dat.sh
```

脚本会自动:
1. 从 GitHub API 获取最新版本号
2. 下载 `geoip.dat` 和 `geosite.dat`
3. 计算文件的 SHA256 hash
4. 自动更新 `pkgs/v2ray-rules-dat/v2ray-rules-dat.nix` 文件

### 3. 应用更新

更新脚本运行后,执行系统重建:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#dev-machine
```

或者直接使用 `update` alias,它会自动执行上述步骤。

## 文件位置

构建后的文件会被安装到:
- `/nix/store/xxx-v2ray-rules-dat/share/v2ray/geoip.dat`
- `/nix/store/xxx-v2ray-rules-dat/share/v2ray/geosite.dat`

dae 服务会自动找到这些文件并使用。

## 版本信息

当前版本: `202512312215` (2025-12-31 22:15)

## 故障排除

### 更新脚本失败

如果更新脚本失败,可能的原因:
1. **网络问题**: 无法访问 GitHub API 或下载文件
2. **nix-prefetch-url 未找到**: 确保 Nix 已正确安装

### 构建失败

如果 `nixos-rebuild` 时构建失败:
1. 检查 hash 值是否正确
2. 确保版本号存在于 GitHub Releases 中
3. 尝试手动运行更新脚本

## 手动更新 (不推荐)

如果自动脚本不工作,可以手动更新 `v2ray-rules-dat.nix`:

1. 访问 https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest
2. 获取最新的 tag 名称
3. 使用 `nix-prefetch-url` 计算 hash:
   ```bash
   nix-prefetch-url https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/VERSION/geoip.dat
   nix-prefetch-url https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/VERSION/geosite.dat
   ```
4. 手动编辑 `pkgs/v2ray-rules-dat/v2ray-rules-dat.nix`,更新 `version` 和两个 `sha256` 值

## 参考链接

- [Loyalsoldier/v2ray-rules-dat](https://github.com/Loyalsoldier/v2ray-rules-dat)
- [dae 文档](https://github.com/daeuniverse/dae)
