# NixOS Config Library

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![CUDA](https://img.shields.io/badge/CUDA-12.x-green.svg?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

基于 **NixOS Flakes** 的可复用模块库，为 **AI 研发**、**CUDA 加速**和**全栈开发**场景提供开箱即用的配置。

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
┌─────────────────▼───────────────────────┐
│         私有仓库（主机配置）              │
│  hosts/<hostname>/                       │
│    ├── default.nix    # 主机特定配置     │
│    ├── hardware-configuration.nix        │
│    └── secrets.yaml   # sops 加密机密    │
└─────────────────────────────────────────┘
```

**为什么这样设计？**
- 通用模块开源共享，个性化配置私有管理
- 机密信息通过 [sops-nix](https://github.com/Mic92/sops-nix) + age 加密，永远不进入 nix store
- 通过 hostname 自动识别主机配置，`deploy.sh` 一键部署

---

## 快速开始

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
nix shell nixpkgs#age nixpkgs#ssh-to-age nixpkgs#sops

# 生成管理员 age 密钥
age-keygen -o ~/.config/sops/age/keys.txt

# 查看公钥，填入 .sops.yaml 的 admin 处
age-keygen -y ~/.config/sops/age/keys.txt

# 在目标主机上获取 host age 公钥
ssh-keyscan localhost 2>/dev/null | ssh-to-age
# 将输出填入 .sops.yaml 的主机密钥处
```

### 3. 编辑主机配置

编辑 `hosts/my-host/default.nix`，修改以下内容：

```nix
myConfig = {
  username = "your_username";       # 你的用户名
  userFullName = "Your Name";       # 全名
  userEmail = "your@email.com";     # 邮箱
  sshPublicKey = "ssh-ed25519 ..."; # SSH 公钥
  isWSL = false;                    # 是否为 WSL 环境
  isNvidia = false;                 # 是否启用 NVIDIA
  enableDae = false;                # 是否启用透明代理
};
```

编辑 `hosts/my-host/secrets.yaml` 填入真实密码和密钥，然后用 sops 加密：

```bash
sops -e --input-type yaml --output-type yaml \
  hosts/my-host/secrets.yaml > /tmp/secrets.yaml
mv /tmp/secrets.yaml hosts/my-host/secrets.yaml
```

### 4. 部署

```bash
chmod +x deploy.sh
./deploy.sh
```

### 5. 添加新主机

1. 在 `hosts/` 下创建新目录
2. 复制并修改主机配置
3. 在 `.sops.yaml` 中添加新主机密钥
4. 在 `flake.nix` 的 `hostConfigs` 中添加条目
5. 加密新主机的 `secrets.yaml`

---

## 配置参考

### NixOS 级 myConfig 选项

在主机配置的 `myConfig` 块中设置，由公共模块库读取。

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `username` | string | **必填** | 主用户名 |
| `userFullName` | string | **必填** | 用户全名（用于 Git 等） |
| `userEmail` | string | **必填** | 用户邮箱 |
| `sshPublicKey` | string | **必填** | SSH 公钥 |
| `nixMaxJobs` | int \| "auto" | `"auto"` | Nix 最大并行构建数 |
| `isWSL` | bool | `false` | 是否为 WSL 环境 |
| `isNvidia` | bool | `false` | 启用 NVIDIA 闭源驱动 + CUDA |
| `enableDae` | bool | `false` | 启用 dae (eBPF) 透明代理 |
| `extraHosts` | attrsOf (listOf str) | `{ }` | 额外的 `/etc/hosts` 映射 |
| `daeConfigFile` | nullOr string | `null` | dae 完整配置文件路径（推荐通过 sops 提供） |
| `opencodeSettings` | attrs | `{ }` | OpenCode 自定义配置 |

### Home Manager 级 myConfig 选项

在 `home-manager.users.<name>.myConfig` 中设置。

| 选项 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `username` | string | **必填** | 主用户名 |
| `userFullName` | string | **必填** | 用户全名 |
| `userEmail` | string | **必填** | 用户邮箱 |
| `sshPublicKey` | string | **必填** | SSH 公钥 |
| `sshSopsSecrets` | listOf string | `[ ]` | 要加载到 ssh-agent 的 sops secret 名称 |
| `opencodeSettings` | attrs | `{ }` | OpenCode 自定义配置 |
| `opencodeConfigFile` | nullOr string | `null` | 运行时生成的 OpenCode 配置路径（含机密，优先于 opencodeSettings） |
| `enableSshAgent` | bool | `true` | 自动启动 ssh-agent 并加载私钥 |

---

## 高级用法

### 物理机 + NVIDIA + dae 透明代理

```nix
let
  isWSL = false;
  isNvidia = true;
in
{
  imports = [ ./hardware-configuration.nix ];

  myConfig = lib.mkMerge [
    {
      isWSL = isWSL;
      isNvidia = isNvidia;
      enableDae = true;
      # ...其他必填字段
    }
    (lib.mkIf config.myConfig.enableDae {
      daeConfigFile = config.sops.secrets."dae/config".path;
    })
  ];

  sops.secrets = lib.mkMerge [
    { /* 基础 secrets */ }
    (lib.mkIf config.myConfig.enableDae {
      "dae/config" = { };
    })
  ];
}
```

> **注意：** `daeConfigFile` 包含节点和订阅信息，务必通过 sops 管理，不要将明文写入 nix 文件。

### 多主机管理

在 `flake.nix` 中添加多台主机：

```nix
hostConfigs = {
  "workstation" = ./hosts/workstation;
  "laptop" = ./hosts/laptop;
  "server" = ./hosts/server;
};
```

使用 `./deploy.sh workstation` 或 `./deploy.sh laptop` 部署到不同主机。

### 自定义模块组合

可以按需导入单独的模块，而非使用完整的 `default` 聚合：

```nix
modules = [
  nixos-config-public.nixosModules.base
  nixos-config-public.nixosModules.network
  nixos-config-public.nixosModules.users
  nixos-config-public.nixosModules.packages
  # 不需要 nvidia、dae 等就不导入
];
```

---

## 项目结构

```
nixos-config/
├── flake.nix              # Flake 入口，导出模块和 overlays
├── example/               # 私有仓库模板
│   └── my-host/           # 完整可运行示例
├── lib/
│   ├── options.nix        # NixOS myConfig options 定义
│   └── home-options.nix   # Home Manager myConfig options 定义
├── modules/
│   ├── nixos/
│   │   ├── default.nix    # 系统模块聚合
│   │   ├── base.nix       # 基础配置 (Nix, 内核, swap)
│   │   ├── network.nix    # 网络配置
│   │   ├── users.nix      # 用户管理
│   │   ├── packages.nix   # 系统包
│   │   ├── virtualisation.nix  # Podman
│   │   ├── hardware/
│   │   │   └── nvidia.nix # NVIDIA/CUDA 支持
│   │   └── services/
│   │       ├── dae.nix    # 透明代理
│   │       └── openssh.nix
│   └── home/
│       ├── default.nix    # Home Manager 模块聚合
│       ├── base.nix
│       ├── git.nix        # Git 配置 + SSH 签名
│       ├── shell.nix      # Zsh + Starship
│       ├── cli-tools.nix  # 现代 CLI 工具
│       ├── opencode.nix   # OpenCode AI 助手
│       └── packages.nix   # 用户包
└── pkgs/
    └── v2ray-rules-dat/   # GeoIP/GeoSite 规则包
```

---

## 导出内容

### nixosModules

| 模块 | 描述 |
|------|------|
| `default` | 完整 NixOS 模块聚合（推荐直接使用） |
| `base` | 基础系统配置 |
| `network` | 网络配置 |
| `users` | 用户管理 |
| `nvidia` | NVIDIA/CUDA 支持 |
| `dae` | dae 透明代理 |
| `openssh` | SSH 服务 |
| `virtualisation` | Podman（兼容 Docker CLI） |
| `packages` | 系统包 |

### homeModules

| 模块 | 描述 |
|------|------|
| `default` | 完整 Home Manager 模块聚合 |

### overlays

| Overlay | 描述 |
|---------|------|
| `default` | v2ray-rules-dat、opencode、rtk 自定义包 |

---

## 许可证

MIT License
