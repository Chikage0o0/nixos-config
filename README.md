# NixOS Config Library

[![NixOS](https://img.shields.io/badge/NixOS-stable-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![CUDA](https://img.shields.io/badge/CUDA-12.x-green.svg?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

基于 **NixOS Flakes** 的可复用模块库，为 **KDE Plasma 日常工作站**、**AI 研发**、**CUDA 加速**和**全栈开发**场景提供开箱即用的配置。

仓库默认以当前 stable `nixpkgs` 作为系统基线；对确实需要追新的少数应用，模块可显式使用 `pkgsUnstable`。当前 `remote-admin` 中的 Cockpit 就采用这种 selective unstable 策略，以便在不牵动整套系统频道的前提下追踪新版。

## 架构设计

采用**双仓库分层架构**——公共模块开源共享，个性化配置私有管理：

```
┌─────────────────────────────────────────┐
│         本仓库（公共模块库）              │
│  modules/  lib/  pkgs/                  │
│  可复用的 NixOS 和 Home Manager 模块     │
│  example/ - 私有仓库模板                 │
└─────────────────┬───────────────────────┘
                  │ flake input
┌──────────────────▼───────────────────────┐
│         私有仓库（主机配置）              │
│  nixosConfigurations.<hostname>/          │
│    ├── default.nix    # 主机特定配置     │
│    ├── hardware-configuration.nix        │
│    └── secrets.yaml   # sops 加密机密    │
└─────────────────────────────────────────┘
```

**为什么这样设计？**

- 通用模块开源共享，个性化配置私有管理
- 机密信息通过 [sops-nix](https://github.com/Mic92/sops-nix) + age 加密，永远不进入 nix store
- 通过 `lib.mkHost` 声明式定义主机，profile + role 自由组合

---

## 快速开始

如果你已经装好了一个最小可启动的 NixOS，当前主要还在用 `root` 和临时 `nix` 命令，想直接切到这套配置，先看这篇迁移指南：[`docs/migration-from-root-nix.md`](docs/migration-from-root-nix.md)

### 前置条件

- 已安装 NixOS（或准备全新安装）
- 基本的命令行操作能力
- 了解 Git 基本用法

### 1. 创建私有仓库

```bash
# 克隆公共模块库
git clone https://github.com/Chikage0o0/nixos-config.git

# 将 example 目录复制为你的私有仓库
cp -r nixos-config/example/my-host ~/my-nixos-config
cd ~/my-nixos-config
git init
```

### 2. 配置 sops 密钥

```bash
# 进入包含所需工具的 shell
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#age nixpkgs#ssh-to-age nixpkgs#sops nixpkgs#git nixpkgs#gh

# 生成管理员 age 密钥
age-keygen -o ~/.config/sops/age/keys.txt

# 查看公钥，填入 .sops.yaml 的 admin 处
age-keygen -y ~/.config/sops/age/keys.txt

# 在目标主机上获取 host age 公钥
ssh-keyscan localhost 2>/dev/null | ssh-to-age
# 将输出填入 .sops.yaml 的主机密钥处
```

### 3. 编辑主机声明

编辑 `flake.nix`，修改 `commonUser` 中的用户信息，或调整 profile/role 组合：

```nix
nixos-config-public.lib.mkHost {
  hostname = "workstation";
  system = "x86_64-linux";
  user = {
    name = "chikage";
    fullName = "Chikage";
    email = "user@example.com";
    sshPublicKey = "ssh-ed25519 ...";
  };
  profiles = [ "workstation-base" ];
  roles = [
    "development"
    "fullstack-development"
    "ai-tooling"
    "container-host"
  ];
}
```

### 4. 部署

```bash
chmod +x deploy.sh
./deploy.sh
```

### 5. 添加新主机

1. 在 `flake.nix` 的 `nixosConfigurations` 中添加新的 `mkHost` 声明
2. 创建对应的 `hosts/<hostname>/` 目录
3. 在 `.sops.yaml` 中添加新主机密钥
4. 加密新主机的 `secrets.yaml`

---

## 配置参考

### Profile / Role 设计规则

- **profile** 只描述机器形态：`wsl-base`、`workstation-base`、`server-base`、`generic-linux`。
- `workstation-base` 默认启用 KDE Plasma 6 日常桌面；主机可通过更高优先级关闭 `platform.desktop.enable` 或 `platform.desktop.apps.enable`。
- OpenCode、全栈开发工具和 Podman 由 role/feature 组合，不绑定到某个 profile。
- VS Code 和 dbgate 属于 `fullstack-development` 的桌面 GUI 开发能力，不属于基础桌面包集合；仅在 fullstack-development role、platform.desktop.enable 与 platform.desktop.apps.enable 三者同时启用时安装。

### Profile 列表

| Profile              | 描述                                          |
| -------------------- | --------------------------------------------- |
| `wsl-base`           | WSL 环境基础配置                              |
| `workstation-base`   | 物理工作站基础配置，默认包含 KDE Plasma 日常桌面 |
| `server-base`        | 服务器基础配置                                |
| `generic-linux`      | 通用 Linux（默认，不附加特定形态约束）        |

### Role 列表

| Role                    | 描述                                              |
| ----------------------- | ------------------------------------------------- |
| `development`           | 基础开发工具链                                    |
| `fullstack-development` | 全栈开发工具（Go、Rust、数据库 CLI 工具；桌面启用时含 VS Code、dbgate） |
| `ai-tooling`            | OpenCode AI 助手与开发 Shell 环境                 |
| `container-host`        | Podman 容器宿主                                    |
| `ai-accelerated`        | NVIDIA/CUDA 加速（配合 `machine.nvidia.enable`）  |
| `remote-admin`          | Cockpit 远程管理面板（Cockpit 走 selective unstable 以便追新） |

### platform 选项参考

`mkHost` 会将 host 声明规范化为 `config.platform.*`，供模块内部读取。

| 选项路径                                        | 类型                     | 默认值      | 说明                                 |
| ----------------------------------------------- | ------------------------ | ----------- | ------------------------------------ |
| `platform.profiles`                             | listOf string            | `[ ]`       | 启用的 profile 名称列表              |
| `platform.roles`                                | listOf string            | `[ ]`       | 启用的 role 名称列表                 |
| `platform.user.name`                            | string                   | **必填**    | 主用户名                             |
| `platform.user.fullName`                        | string                   | **必填**    | 用户全名                             |
| `platform.user.email`                           | string                   | **必填**    | 用户邮箱                             |
| `platform.user.sshPublicKey`                    | string                   | **必填**    | SSH 公钥                             |
| `platform.stateVersion`                         | string                   | `"25.11"`   | NixOS / HM stateVersion              |
| `platform.machine.class`                        | enum                     | `"generic"` | 机器形态：wsl / workstation / server |
| `platform.machine.wsl.enable`                   | bool                     | `false`     | 是否启用 WSL 约束                    |
| `platform.machine.boot.mode`                    | enum                     | `"uefi"`    | GRUB 启动模式                         |
| `platform.machine.boot.grubDevice`              | nullOr string            | `null`      | BIOS 模式下 GRUB 安装磁盘            |
| `platform.machine.nvidia.enable`                | bool                     | `false`     | 启用 NVIDIA/CUDA                     |
| `platform.machine.powerProfiles.enable`         | bool                     | `false`     | 启用通用电源/性能档位切换            |
| `platform.machine.brightness.enable`            | bool                     | `false`     | 安装内置屏幕与标准背光设备亮度控制工具 |
| `platform.desktop.enable`                      | bool                     | `false`     | 启用图形桌面环境                    |
| `platform.desktop.environment`                 | enum                     | `"plasma"` | 桌面环境；第一版只支持 Plasma       |
| `platform.desktop.apps.enable`                 | bool                     | `false`     | 启用日常桌面应用集、字体、输入法与 Kitty/mpv 配置 |
| `platform.nix.maxJobs`                          | int \| "auto"            | `"auto"`    | Nix 最大并行构建数                    |
| `platform.networking.extraHosts`                | attrsOf (listOf str)     | `{ }`       | 额外的 `/etc/hosts` 映射             |
| `platform.services.openssh.enable`              | bool                     | `false`     | 启用 OpenSSH                         |
| `platform.services.cockpit.enable`              | bool                     | `false`     | 启用 Cockpit                         |
| `platform.services.cockpit.extraOrigins`        | listOf string            | `[ ]`       | 额外 Cockpit origin                  |
| `platform.containers.podman.enable`             | bool                     | `false`     | 启用 Podman + Docker CLI 兼容层      |
| `platform.home.cliTools.enable`                | bool                     | `false`     | 启用现代 CLI 工具                   |
| `platform.home.opencode.enable`                 | bool                     | `false`     | 启用 OpenCode AI 助手                |
| `platform.home.opencode.settings`               | attrs                    | `{ }`       | OpenCode 自定义配置                  |
| `platform.home.opencode.configFile`             | nullOr string            | `null`      | 运行时生成的配置文件路径             |
| `platform.home.sshAgent.enable`                 | bool                     | `true`      | 自动启动 ssh-agent                   |
| `platform.home.sshAgent.sopsSecrets`            | listOf string            | `[ ]`       | 加载到 ssh-agent 的 sops secret      |
| `platform.development.fullstack.enable`        | bool                     | `false`     | 启用全栈开发工具包                  |
| `platform.packages.system.extra`                | listOf package           | `[ ]`       | 额外系统包                           |
| `platform.packages.home.extra`                  | listOf package           | `[ ]`       | 额外用户包                           |

### workstation-base 默认桌面

`workstation-base` 使用 profile 默认值启用：

- `platform.desktop.enable = true`
- `platform.desktop.environment = "plasma"`
- `platform.desktop.apps.enable = true`
- `platform.machine.powerProfiles.enable = true`
- `platform.machine.brightness.enable = true`

默认桌面能力包括 KDE Plasma 6、SDDM Wayland、PipeWire、蓝牙、打印、Flatpak、KDE Connect 和 Fcitx5 拼音输入法。

默认硬件体验包括通过 power-profiles-daemon 提供 KDE 可识别的电源/性能档位，以及通过 brightnessctl 控制笔记本内置屏幕和标准背光设备亮度；外接显示器 DDC/CI 调光不默认启用。

日常预置软件包括 Microsoft Edge、WPS Office CN、Gwenview、Spectacle、GIMP、Dolphin、Kate、Ark、KCalc、Bitwarden、Remmina、Plasma System Monitor、KDE Partition Manager、Filelight、Discover、AppImage 支持、Obsidian、Thunderbird、yt-dlp、ffmpeg-full 和 mediainfo。

字体包含 Noto CJK、Noto Color Emoji、Sarasa Gothic、FiraCode Nerd Font、corefonts、vista-fonts 和 vista-fonts-chs，用于中文显示、emoji、编程字体候选和 WPS/Office 文档常见 Windows 字体兼容。

基础桌面不包含聊天通讯软件、游戏/Wine/Proton 工具、同步云盘客户端、专用 PDF 查看器、IDE 或数据库 GUI。VS Code 与 dbgate 只在启用 `fullstack-development` role 且 platform.desktop.enable 与 platform.desktop.apps.enable 同时启用时通过 Home Manager 安装。

---

## 高级用法

### 物理机 + NVIDIA

```nix
public.lib.mkHost {
  hostname = "gpu-workstation";
  system = "x86_64-linux";
  user = commonUser;
  profiles = [ "workstation-base" ];
  roles = [
    "development"
    "ai-tooling"
    "ai-accelerated"
    "container-host"
  ];
  machine = {
    boot.mode = "uefi";
    nvidia.enable = true;
  };
  home.opencode.enable = true;
  secrets.sops = {
    enable = true;
    defaultFile = ./hosts/gpu-workstation/secrets.yaml;
    ageKeyFile = "/home/${commonUser.name}/.config/sops/age/keys.txt";
    secrets = {
      "opencode/apiKey" = { };
      "ssh_private_key" = {
        owner = commonUser.name;
        mode = "0400";
      };
    };
  };
  hardwareModules = [ ./hosts/gpu-workstation/hardware-configuration.nix ];
  extraModules = [ ./hosts/gpu-workstation ];
}
```

### 自定义模块组合

可以在 `extraModules` 中添加你自己的模块：

```nix
public.lib.mkHost {
  hostname = "custom";
  profiles = [ "generic-linux" ];
  user = commonUser;
  extraModules = [ ./my-custom-module.nix ];
}
```

---

## 项目结构

```
nixos-config/
├── flake.nix              # Flake 入口，导出模块和 overlays
├── example/               # 私有仓库模板
│   └── my-host/           # 完整可运行示例（wsl-dev / server / workstation）
├── home/                  # 共享 Home 资源（如 starship.toml）
├── lib/
│   └── platform/          # mkHost、mkSystem、mkHome 实现
├── modules/
│   ├── nixos/
│   │   ├── default.nix    # 系统模块聚合
│   │   ├── core/          # 基础系统配置与断言
│   │   ├── boot/          # 启动引导
│   │   ├── users/         # 用户管理
│   │   ├── networking/    # 网络配置
│   │   ├── desktop/       # KDE Plasma 桌面、输入法、字体、GUI 应用
│   │   ├── hardware/      # NVIDIA/CUDA
│   │   ├── services/      # SSH、Cockpit
│   │   ├── containers/    # Podman
│   │   └── packages/      # 系统包
│   ├── home/
│   │   ├── default.nix    # Home Manager 模块聚合
│   │   ├── core/          # 基础用户配置
│   │   ├── git/           # Git + SSH 签名
│   │   ├── shell/         # Zsh + Starship
│   │   ├── development/   # CLI 开发包与桌面 fullstack GUI 包门控
│   │   ├── desktop/       # Kitty 与 mpv 桌面用户配置
│   │   └── opencode/      # OpenCode AI 助手
│   └── shared/
│       └── options.nix    # platform 选项定义
├── profiles/              # 机器形态定义
├── roles/                 # 功能角色定义
└── pkgs/
    ├── opencode/          # OpenCode 自定义包

```

---

## 导出内容

### nixosModules

| 模块             | 描述                                              |
| ---------------- | ------------------------------------------------- |
| `default`        | `platform` 别名，完整 NixOS 模块聚合              |
| `platform`       | 完整平台模块聚合                                   |
| `profiles`       | profile 函数集合                                  |
| `roles`          | role 函数集合                                     |

### homeModules

| 模块      | 描述                       |
| --------- | -------------------------- |
| `default` | `platform` 别名            |
| `platform`| 完整 Home Manager 模块聚合 |

### lib

| 函数      | 描述                                          |
| --------- | --------------------------------------------- |
| `mkHost`  | 从 host 声明创建 NixOS 配置（参数同 mkSystem）|
| `mkSystem`| mkHost 别名                                   |
| `mkHome`  | 创建 Home Manager 配置                        |
| `profileNames` | 可用 profile 名称列表                   |
| `roleNames`    | 可用 role 名称列表                       |
| `resolveProfiles` | 按名称解析 profile 模块               |
| `resolveRoles`    | 按名称解析 role 模块                   |

### overlays

| Overlay   | 描述                                    |
| --------- | --------------------------------------- |
| `default` | opencode 自定义包                   |

---

## 从旧接口迁移

如果你是从旧版接口迁移过来的用户，请参阅 `docs/` 下的迁移文档。

---

## 许可证

MIT License
