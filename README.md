# NixOS Config Library

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![CUDA](https://img.shields.io/badge/CUDA-12.x-green.svg?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

这是一个基于 **NixOS Flakes** 构建的可复用模块库，专为 **AI 研发**、**CUDA 加速** 以及 **全栈开发** 场景设计。

## 架构设计

本项目采用 **双仓库分层架构**：

```
┌─────────────────────────────────────────┐
│         本仓库 (公开模块库)              │
│  modules/  lib/  pkgs/  dae/            │
│  可复用的 NixOS 和 Home Manager 模块     │
└─────────────────┬───────────────────────┘
                  │ flake input
┌─────────────────▼───────────────────────┐
│         私有仓库 (主机配置)              │
│  hosts/<hostname>/                       │
│    ├── default.nix    # 主机特定配置     │
│    ├── hardware-configuration.nix        │
│    └── secrets.yaml   # sops 加密机密    │
└─────────────────────────────────────────┘
```

**优势**：
- 通用模块开源共享，个性化配置私有管理
- 机密信息通过 [sops-nix](https://github.com/Mic92/sops-nix) 加密
- 通过 hostname 自动识别主机配置

---

## 核心特性

| 特性 | 描述 |
|------|------|
| 🚀 **CUDA 支持** | NVIDIA 闭源驱动 + CUDA Toolkit，支持 TensorRT 开发 |
| 🌐 **透明代理** | 基于 dae (eBPF) 的系统级透明代理，内核态智能分流 |
| ⚡ **现代 CLI** | eza, zoxide, fzf, bat, lazygit + zsh + starship |
| 🔐 **安全设计** | SSH 密钥登录，sops-nix 机密管理 |
| 🐳 **开发就绪** | Docker, nix-ld, uv (Python), bun (JS/TS) |
| 🖥️ **多环境** | 支持物理机、WSL、多主机配置 |

---

## 项目结构

```
nixos-config/
├── flake.nix              # Flake 入口，导出模块和 overlays
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
│   │   ├── virtualisation.nix  # Docker
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
├── dae/
│   └── config.nix         # dae 透明代理配置模板
└── pkgs/
    └── v2ray-rules-dat/   # GeoIP/GeoSite 规则包
```

---

## 使用方式

### 作为 Flake Input 引入

在你的私有配置仓库的 `flake.nix` 中：

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixos-config-public = {
      url = "github:Chikage0o0/nixos-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager.url = "github:nix-community/home-manager";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { nixpkgs, nixos-config-public, ... }@inputs: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # 导入公共模块
        nixos-config-public.nixosModules.default

        # 你的主机配置
        ./hosts/my-host
      ];
    };
  };
}
```

### 配置 myConfig

模块通过 `config.myConfig` 接收配置：

```nix
# hosts/my-host/default.nix
{ config, ... }:
{
  myConfig = {
    # 用户信息
    username = "your_username";
    userFullName = "Your Name";
    userEmail = "your@email.com";
    sshPublicKey = "ssh-ed25519 AAAA...";

    # 功能开关
    isWSL = false;
    isNvidia = true;
    enableDae = true;
    # Nix 构建
    nixMaxJobs = 8;

    # 网络
    extraHosts = { };

    # dae 代理 (建议通过 sops 管理)
    daeNodes = { };
    daeSubscriptions = [ ];

    # OpenCode
    opencodeSettings = { };
  };
}
```

---

## 导出内容

### nixosModules

| 模块 | 描述 |
|------|------|
| `default` | 完整 NixOS 模块聚合 |
| `base` | 基础系统配置 |
| `network` | 网络配置 |
| `users` | 用户管理 |
| `nvidia` | NVIDIA/CUDA 支持 |
| `dae` | dae 透明代理 |
| `openssh` | SSH 服务 |

### homeModules

| 模块 | 描述 |
|------|------|
| `default` | 完整 Home Manager 模块聚合 |

### overlays

| Overlay | 描述 |
|---------|------|
| `default` | v2ray-rules-dat 等自定义包 |

---

## 私有仓库示例

推荐的私有仓库结构：

```
nixos-config-private/
├── flake.nix
├── .sops.yaml
├── deploy.sh
└── hosts/
    ├── workstation/
    │   ├── default.nix
    │   ├── hardware-configuration.nix
    │   └── secrets.yaml
    └── laptop/
        ├── default.nix
        ├── hardware-configuration.nix
        └── secrets.yaml
```

详细的私有仓库配置指南请参考 [私有仓库 README](https://github.com/Chikage0o0/nixos-config-private)（需单独创建）。

---

## 许可证

MIT License
