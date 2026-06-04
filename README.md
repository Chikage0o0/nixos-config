# NixOS Config Library

[![NixOS](https://img.shields.io/badge/NixOS-stable-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![CUDA](https://img.shields.io/badge/CUDA-12.x-green.svg?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

基于 **NixOS Flakes** 的可复用模块库，为 **KDE Plasma 日常工作站**、**AI 研发**、**CUDA 加速**和**全栈开发**场景提供开箱即用的配置。

仓库默认以 NixOS 26.05 对应的 stable `nixpkgs` 作为系统基线；所有平台模块默认只使用这一套包集，避免在稳定基线之外混入额外 channel。

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

### 前置条件与推荐起点

- 一台已安装 NixOS 的机器，或准备通过 `nixos-anywhere` / NixOS-WSL 初始化的新机器。
- 启用 flakes 的 Nix，或能运行带 `--extra-experimental-features "nix-command flakes"` 的命令。
- 基本 Git、SSH 和 NixOS 运维能力。
- 准备一个**私有仓库**保存主机差异和加密 secrets；不要把真实 secrets 放进公共模块仓库。

本仓库提供完整模板：[`example/my-host`](example/my-host)。建议先复制模板，再按自己的主机删减。

### 1. 创建私有仓库

```bash
# 克隆公共模块库
git clone https://github.com/Chikage0o0/nixos-config.git

# 将 example 模板复制为你的私有仓库
cp -r nixos-config/example/my-host ~/my-nixos-config
cd ~/my-nixos-config
git init
```

模板内已经包含：

- `flake.nix`：三台示例主机 `wsl-dev`、`server`、`workstation`
- `.sops.yaml`：管理员和主机 recipient 的示例规则
- `deploy.sh`：本机 `nixos-rebuild switch|boot` 包装脚本
- `scripts/add-host.sh`：添加新主机脚手架
- `scripts/remote-deploy.sh`：SSH 远程部署
- `scripts/build-wsl.sh`：构建 NixOS-WSL 导入包
- `scripts/reinstall.sh`：通过 `nixos-anywhere` 重装远端主机（破坏性，按需使用）
- `hosts/<hostname>/`：主机差异、硬件配置和 secrets 示例

### 2. 配置 sops 密钥

```bash
# 进入包含所需工具的 shell
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#age nixpkgs#ssh-to-age nixpkgs#sops nixpkgs#mkpasswd

# 生成管理员 age 密钥
age-keygen -o ~/.config/sops/age/keys.txt

# 查看公钥，填入 .sops.yaml 的 admin 处
age-keygen -y ~/.config/sops/age/keys.txt

# 普通 NixOS 主机：从 SSH host key 派生 age recipient
ssh-keyscan <target-host> 2>/dev/null | ssh-to-age
```

WSL 主机建议单独生成 host age key，并在构建 WSL 镜像时注入 `/var/lib/sops-nix/age/keys.txt`：

```bash
age-keygen -o hosts/wsl-dev/age-key.txt
age-keygen -y hosts/wsl-dev/age-key.txt

# 可选：用管理员公钥加密后提交，明文 age-key.txt 不要提交
age -e -r <admin-age-public-key> \
  -o hosts/wsl-dev/age-key.txt.age \
  hosts/wsl-dev/age-key.txt
```

把所有 `age1...` 公钥填入 `.sops.yaml`，再用 `sops -e -i hosts/<hostname>/secrets.yaml` 加密对应 secrets。

### 3. 编辑主机声明

编辑私有仓库的 `flake.nix`，先修改 `commonUser` 中的用户信息，再按主机类型调整 profile/role 组合：

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
    "hermes"
  ];
}
```

常见组合：

- WSL：`profiles = [ "wsl-base" ];` + `machine.wsl.enable = true;`
- 服务器：`profiles = [ "server-base" ];` + `remote-admin` / `container-host`
- 桌面工作站：`profiles = [ "workstation-base" ];` + `development` / `fullstack-development` / `ai-tooling`
- NVIDIA/CUDA：同时启用 `gpu-nvidia` 和 `ai-accelerated`

非 WSL 主机需要把目标机生成的硬件配置写入 `hosts/<hostname>/hardware-configuration.nix`：

```bash
sudo nixos-generate-config --show-hardware-config \
  > hosts/workstation/hardware-configuration.nix
```

### 4. 评估与部署

新文件尚未提交时，先让 flake 能看到它们：

```bash
git add --intent-to-add .
nix eval .#nixosConfigurations.workstation.config.networking.hostName
```

本机部署：

```bash
chmod +x deploy.sh
./deploy.sh workstation
```

远程部署：

```bash
scripts/remote-deploy.sh root@1.2.3.4
scripts/remote-deploy.sh --dry-run root@server.example.com
```

构建 WSL 导入包：

```bash
scripts/build-wsl.sh wsl-dev
```

更多脚本参数和高风险重装流程见 [`example/my-host/README.md`](example/my-host/README.md)。

### 5. 添加新主机

```bash
scripts/add-host.sh laptop x86_64-linux linux
scripts/add-host.sh wsl-work x86_64-linux wsl
```

然后按脚本输出完成：

1. 在 `flake.nix` 的 `nixosConfigurations` 中添加新的 `mkHost` 声明。
2. 在 `.sops.yaml` 中添加新主机 recipient 和 `hosts/<hostname>/secrets.yaml` 规则。
3. 填写并加密新主机的 `secrets.yaml`。
4. 非 WSL 主机替换 `hardware-configuration.nix`。
5. 运行 `nix eval .#nixosConfigurations.<hostname>.config.networking.hostName` 验证。

### 6. 脚本职责速查

| 脚本 | 场景 | 默认行为 | 风险提示 |
| --- | --- | --- | --- |
| `deploy.sh [hostname]` | 当前机器本机部署 | 询问 `switch` 或 `boot` | `switch` 会立即切换系统 |
| `scripts/add-host.sh <hostname> [system] [linux|wsl]` | 添加主机脚手架 | 只创建文件，不改 `flake.nix` / `.sops.yaml` | 生成的 secrets 是占位明文，需加密 |
| `scripts/remote-deploy.sh [选项] <ssh-target>` | 远程更新已有机器 | 探测远端 hostname 后执行 `nixos-rebuild boot` | 远端 hostname 必须匹配 flake host |
| `scripts/build-wsl.sh <hostname>` | 生成 NixOS-WSL `nixos.wsl` | 构建并运行 tarball builder | 明文 `age-key.txt` 不要提交 |
| `scripts/reinstall.sh <flake-host> <target-host> [disk-device]` | 通过 `nixos-anywhere` 重装 | 预检查 flake，可覆盖 disko 目标盘 | 破坏性操作，可能清空目标磁盘 |

---

## 配置参考

### Profile / Role 设计规则

- **profile** 只描述机器形态：`wsl-base`、`workstation-base`、`server-base`、`generic-linux`。
- `workstation-base` 默认启用 KDE Plasma 6 日常桌面；主机可通过更高优先级关闭 `platform.desktop.enable` 或 `platform.desktop.apps.enable`。
- OpenCode、全栈开发工具和 Podman 由 role/feature 组合，不绑定到某个 profile。
- VS Code 属于 `fullstack-development` 的桌面 GUI 开发能力，不属于基础桌面包集合；仅在 fullstack-development role、platform.desktop.enable 与 platform.desktop.apps.enable 三者同时启用时安装。

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
| `fullstack-development` | 全栈开发工具（Go、Rust、数据库 CLI 工具；桌面启用时含 VS Code） |
| `ai-tooling`            | OpenCode AI 助手与开发 Shell 环境                 |
| `container-host`        | Podman 容器宿主                                    |
| `hermes`                | Hermes Agent CLI、agent-browser、视频下载、Playwright/Chromium、中文字体和用户级 gateway 服务 |
| `ai-accelerated`        | NVIDIA/CUDA 加速（配合 `machine.nvidia.enable`）  |
| `remote-admin`          | Cockpit 远程管理面板                              |

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
| `platform.stateVersion`                         | string                   | `"26.05"`   | NixOS / HM stateVersion              |
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
| `platform.home.hermes.enable`                   | bool                     | `false`     | 启用 Hermes Agent 用户态环境         |
| `platform.home.hermes.package`                  | nullOr package           | `null`      | Hermes 包；null 时使用官方 flake 默认包 |
| `platform.home.hermes.extraPackages`            | listOf package           | `[ ]`       | 追加安装到 Hermes 用户环境的额外包   |
| `platform.home.hermes.service.enable`           | bool                     | `true`      | 声明用户级 Hermes gateway 服务        |
| `platform.home.hermes.service.extraArgs`        | listOf string            | `[ ]`       | 追加传给 `hermes gateway` 的参数      |
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

日常预置软件包括 Microsoft Edge、WPS Office CN、Gwenview、Spectacle、GIMP、Dolphin、Kate、Ark、KCalc、Bitwarden、Remmina、Plasma System Monitor、KDE Partition Manager、Filelight、Discover、AppImage 支持、Thunderbird、yt-dlp、ffmpeg-full 和 mediainfo。

字体包含 Noto CJK、Noto Color Emoji、Sarasa Gothic、FiraCode Nerd Font、corefonts、vista-fonts 和 vista-fonts-chs，用于中文显示、emoji、编程字体候选和 WPS/Office 文档常见 Windows 字体兼容。

基础桌面不包含聊天通讯软件、游戏/Wine/Proton 工具、同步云盘客户端、专用 PDF 查看器、IDE 或数据库 GUI。VS Code 只在启用 `fullstack-development` role 且 platform.desktop.enable 与 platform.desktop.apps.enable 同时启用时通过 Home Manager 安装。

---

## 高级用法

### Hermes Agent 用户级服务

启用 `hermes` role 后，主用户会获得 Hermes CLI、`agent-browser`、`yt-dlp`、`streamlink`、`playwright`、`playwright-mcp`、Chromium、Playwright browsers、中文/CJK/emoji 字体、较完整的 Python/Node/构建/媒体/搜索依赖，以及用户级 `hermes-agent.service`。本仓库不管理 `~/.hermes/config.yaml` 或 `~/.hermes/.env`，provider token 和 gateway token 仍由用户通过 Hermes CLI 写入自己的 home 目录。

```nix
public.lib.mkHost {
  hostname = "ai-workstation";
  system = "x86_64-linux";
  user = commonUser;
  profiles = [ "workstation-base" ];
  roles = [
    "development"
    "ai-tooling"
    "hermes"
  ];
}
```

首次部署后先配置 Hermes：

```bash
hermes setup
```

配置完成后启动 gateway：

```bash
systemctl --user start hermes-agent.service
```

如需随用户会话自动启动：

```bash
systemctl --user enable hermes-agent.service
```

查看日志：

```bash
journalctl --user -u hermes-agent.service -f
```

常用工具检查：

```bash
agent-browser --version
yt-dlp --version
playwright --version
chromium --version
```

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
    "gpu-nvidia"
    "ai-accelerated"
    "container-host"
  ];
  machine = {
    boot.mode = "uefi";
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
│       ├── deploy.sh      # 本机部署脚本
│       └── scripts/       # 添加主机、远程部署、重装、WSL 构建脚本
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
│   │   ├── opencode/      # OpenCode AI 助手
│   │   ├── hermes/        # Hermes Agent、agent-browser、浏览器自动化与 gateway 服务
│   │   └── desktop/       # Kitty 与 mpv 桌面用户配置
│   └── shared/
│       └── options.nix    # platform 选项定义
├── profiles/              # 机器形态定义
├── roles/                 # 功能角色定义
└── pkgs/                  # 自定义包与更新脚本

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
| `default` | 从 unstable 引入 opencode，并导出 tabby、agent-browser 等自定义包 |

---

## 从旧接口迁移

如果你是从旧版接口迁移过来的用户，请参阅 `docs/` 下的迁移文档。

---

## 许可证

MIT License
