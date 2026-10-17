# Example 创建与 README 重构 实施计划

> **给代理执行者：** REQUIRED SUB-SKILL: 使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务执行本计划。步骤使用复选框 `- [ ]` 语法追踪。

**目标：** 在公开仓库中创建完整可运行的 example 模板，并重构 README 使新用户能快速上手。

**架构：** example 目录模拟私有仓库结构，包含 flake.nix、主机配置、sops 配置和部署脚本，用户可以直接复制为新仓库。README 保留架构图和项目结构，新增快速开始引导和配置参考。

**技术栈：** NixOS Flakes, Home Manager, sops-nix, age

---

### 任务 1：创建 example/flake.nix

**文件：**
- 新增：`example/my-host/flake.nix`

- [ ] **步骤 1：创建 example/my-host/flake.nix**

```nix
# example/my-host/flake.nix
# 私有配置仓库的 flake 入口
# 用法：将此 example 目录复制为你的私有仓库根目录，然后按需修改
{
  description = "My NixOS Private Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # 引入公共模块库
    # 正式使用时将 url 改为你的 fork 或原始仓库
    nixos-config-public = {
      url = "github:Chikage0o0/nixos-config";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager - 用户级别配置管理
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # NixOS-WSL - Windows Subsystem for Linux 支持
    # 物理机部署可以移除此 input
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sops-nix - 通过 age/PGP 加密管理机密文件
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-config-public,
      home-manager,
      nixos-wsl,
      sops-nix,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # 主机配置映射表
      # 键为主机名（需与 `hosts/` 下的目录名一致），值为主机配置路径
      hostConfigs = {
        "my-host" = ./hosts/my-host;
      };

      # 通用主机构建函数
      # 为每台主机组装 NixOS 配置：公共模块 + sops + 主机配置 + Home Manager
      mkHost =
        hostname: hostPath:
        nixpkgs.lib.nixosSystem {
          inherit system;

          # 通过 specialArgs 将 hostname 和 inputs 传递给所有模块
          # 这样主机配置中可以直接使用 inputs.nixos-wsl 等
          specialArgs = {
            inherit hostname;
            inputs =
              nixos-config-public.inputs
              // inputs
              // {
                inherit nixos-config-public;
              };
          };

          modules = [
            # 允许安装非自由软件（如 NVIDIA 驱动）
            { nixpkgs.config.allowUnfree = true; }

            # 导入公共模块库（包含 myConfig 选项定义和所有系统模块）
            nixos-config-public.nixosModules.default

            # 导入 sops-nix（机密管理）
            sops-nix.nixosModules.sops

            # 导入主机特定配置
            hostPath

            # Home Manager 集成
            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = {
                inherit hostname;
                inputs = nixos-config-public.inputs // inputs;
              };
            }
          ];
        };
    in
    {
      # 为 hostConfigs 中的每台主机生成 nixosConfigurations
      # 部署命令：sudo nixos-rebuild switch --flake .#my-host
      nixosConfigurations = builtins.mapAttrs mkHost hostConfigs;
    };
}
```

- [ ] **步骤 2：验证文件已正确写入**

运行：`cat example/my-host/flake.nix | head -5`
预期：看到 flake 描述行

---

### 任务 2：创建 example/hosts/my-host/default.nix

**文件：**
- 新增：`example/my-host/hosts/my-host/default.nix`

- [ ] **步骤 1：创建目录和主机配置文件**

```nix
# example/my-host/hosts/my-host/default.nix
# my-host 主机配置
# 这是一个 WSL 环境的示例配置，物理机配置请参考 README 中的高级用法
{
  config,
  lib,
  inputs,
  hostname,
  ...
}:
let
  # 在 let 中定义功能开关，避免在 imports 中引用 config（会导致无限递归）
  isWSL = true;
  isNvidia = false;
in
{
  # ─── 模块导入 ───
  # 根据 isWSL 条件导入 WSL 模块或硬件配置
  imports =
    [ ]
    ++ lib.optionals isWSL [ inputs.nixos-wsl.nixosModules.default ]
    ++ (if isWSL then [ ] else [ ./hardware-configuration.nix ]);

  # ─── 主机标识 ───
  networking.hostName = hostname;

  # ─── 用户与功能配置 ───
  # myConfig 由公共模块库定义，所有选项见 README 配置参考
  myConfig = {
    # 必填：用户基础信息
    username = "your_username";
    userFullName = "Your Name";
    userEmail = "your@email.com";
    sshPublicKey = "ssh-ed25519 AAAA... user@host";

    # Nix 构建并行度，"auto" 或具体数字
    nixMaxJobs = 4;

    # 功能开关（需与上方 let 变量保持一致）
    isWSL = isWSL;
    isNvidia = isNvidia;
    enableDae = false;

    # 额外的 /etc/hosts 映射，按需填写
    extraHosts = { };
  };

  # ─── WSL 特定配置 ───
  # 仅 WSL 环境生效
  wsl = lib.mkIf isWSL {
    enable = true;
    defaultUser = config.myConfig.username;
    interop.register = true;
  };

  # ─── sops 机密管理 ───
  # 机密文件使用 age 加密，明文永远不进入 git 或 nix store
  sops = {
    # 每台主机的 secrets.yaml 存放在对应主机目录下
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/home/${config.myConfig.username}/.config/sops/age/keys.txt";

    secrets = {
      # 用户登录密码（hashed password，用 mkpasswd 生成）
      "user/hashedPassword" = {
        neededForUsers = true;
      };

      # OpenCode API 密钥
      "opencode/apiKey" = { };

      # SSH 私钥（权限设为仅用户可读）
      "ssh_private_key" = {
        owner = config.myConfig.username;
        mode = "0400";
      };
    };
  };

  # 将 sops 解密后的密码文件设为用户密码
  users.users.${config.myConfig.username}.hashedPasswordFile =
    config.sops.secrets."user/hashedPassword".path;

  # ─── OpenCode 配置模板 ───
  # 将 opencode-config.template.json 中的 __OPENCODE_API_KEY__ 占位符
  # 替换为 sops 解密后的真实 API 密钥，生成运行时配置文件
  sops.templates."opencode-config.json" = {
    owner = config.myConfig.username;
    mode = "0400";
    content = builtins.toJSON (
      lib.recursiveUpdate
        (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json"))
        (
          builtins.fromJSON (
            builtins.replaceStrings [ "__OPENCODE_API_KEY__" ] [ config.sops.placeholder."opencode/apiKey" ] (
              builtins.readFile ../opencode-config.template.json
            )
          )
        )
    );
  };

  # ─── Home Manager 配置 ───
  # 导入公共模块库的 Home Manager 模块，并传递用户配置
  home-manager.users.${config.myConfig.username} = {
    imports = [ inputs.nixos-config-public.homeModules.default ];

    myConfig = {
      inherit (config.myConfig)
        username
        userFullName
        userEmail
        sshPublicKey
        ;
      # 指向 sops 生成的 OpenCode 配置文件
      opencodeConfigFile = config.sops.templates."opencode-config.json".path;
      # 要自动加载到 ssh-agent 的 sops secret 名称
      sshSopsSecrets = [ "ssh_private_key" ];
    };
  };
}
```

- [ ] **步骤 2：验证文件已正确写入**

运行：`ls -la example/my-host/hosts/my-host/`
预期：看到 default.nix

---

### 任务 3：创建 example/.sops.yaml

**文件：**
- 新增：`example/my-host/.sops.yaml`

- [ ] **步骤 1：创建 sops 配置模板**

```yaml
# .sops.yaml
# sops 配置文件 - 定义密钥和加密规则
#
# 所需工具：nix shell nixpkgs#age nixpkgs#ssh-to-age nixpkgs#sops
#
# 步骤：
# 1. 生成 age 密钥对：
#    age-keygen -o ~/.config/sops/age/keys.txt
# 2. 查看公钥（填入下方 admin 处）：
#    age-keygen -y ~/.config/sops/age/keys.txt
# 3. 在目标主机上，从 SSH host key 派生 age 公钥：
#    ssh-keyscan localhost 2>/dev/null | ssh-to-age
#    或：cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age

keys:
  # 管理员 age 密钥（你的本地密钥）
  - &admin age1_REPLACE_WITH_YOUR_PUBLIC_KEY

  # 主机密钥（从目标主机的 SSH host ed25519 公钥派生）
  - &my-host age1_REPLACE_WITH_HOST_PUBLIC_KEY

creation_rules:
  # my-host 主机的机密文件
  - path_regex: hosts/my-host/secrets\.yaml$
    key_groups:
      - age:
          - *admin
          - *my-host
```

- [ ] **步骤 2：验证文件已正确写入**

运行：`cat example/my-host/.sops.yaml | head -3`
预期：看到注释行

---

### 任务 4：创建 example/deploy.sh

**文件：**
- 新增：`example/my-host/deploy.sh`

- [ ] **步骤 1：创建部署脚本**

```bash
#!/usr/bin/env bash
# deploy.sh - NixOS 配置部署脚本
# 用法: ./deploy.sh [hostname]
# 如果不指定 hostname，则自动使用当前主机名

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME="${1:-$(hostname)}"

echo "=== NixOS Configuration Deploy ==="
echo "Target host: $HOSTNAME"
echo "Config dir: $SCRIPT_DIR"
echo ""

# 检查主机配置是否存在
if [[ ! -d "$SCRIPT_DIR/hosts/$HOSTNAME" ]]; then
    echo "Error: Host configuration not found: hosts/$HOSTNAME"
    echo "Available hosts:"
    ls -1 "$SCRIPT_DIR/hosts/" 2>/dev/null || echo "  (none)"
    exit 1
fi

# 检查 sops 密钥
SOPS_KEY_FILE="$HOME/.config/sops/age/keys.txt"
if [[ ! -f "$SOPS_KEY_FILE" ]]; then
    echo "Warning: sops age key not found at $SOPS_KEY_FILE"
    echo "Generate one with: age-keygen -o $SOPS_KEY_FILE"
    echo ""
fi

# 执行部署
echo "Running: sudo nixos-rebuild switch --flake .#$HOSTNAME"
echo ""

cd "$SCRIPT_DIR"
sudo nixos-rebuild switch --flake ".#$HOSTNAME"

echo ""
echo "=== Deploy complete ==="
```

- [ ] **步骤 2：设置可执行权限并验证**

运行：`chmod +x example/my-host/deploy.sh && ls -la example/my-host/deploy.sh`
预期：文件存在且有执行权限

---

### 任务 5：创建 example/opencode-config.template.json

**文件：**
- 新增：`example/my-host/hosts/opencode-config.template.json`

- [ ] **步骤 1：创建 OpenCode 配置模板**

```json
{
  "model": "openai/gpt-4o",
  "provider": {
    "openai": {
      "npm": "@ai-sdk/openai",
      "options": {
        "apiKey": "__OPENCODE_API_KEY__"
      },
      "models": {
        "gpt-4o": {
          "name": "GPT-4o"
        }
      }
    }
  }
}
```

- [ ] **步骤 2：验证文件已正确写入**

运行：`python3 -c "import json; json.load(open('example/my-host/hosts/opencode-config.template.json'))"`
预期：无错误输出

---

### 任务 6：创建 example/hosts/my-host/secrets.yaml

**文件：**
- 新增：`example/my-host/hosts/my-host/secrets.yaml`

- [ ] **步骤 1：创建机密文件模板**

这是一个未加密的 YAML 模板，展示 secrets.yaml 应有的结构。
用户需在填写真实值后用 `sops -e` 加密。

```yaml
# secrets.yaml - 机密文件模板（明文）
# ⚠️ 填写真实值后务必用 sops 加密，切勿提交明文到 git
#
# 加密命令：
#   sops -e --input-type yaml --output-type yaml hosts/my-host/secrets.yaml > /tmp/secrets.yaml
#   mv /tmp/secrets.yaml hosts/my-host/secrets.yaml
#
# 编辑已加密文件：
#   sops hosts/my-host/secrets.yaml

user:
    hashedPassword: $6$rounds=65536$saltsalt$HASHED_PASSWORD_HERE
opencode:
    apiKey: sk-your-api-key-here
ssh_private_key: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    YOUR_SSH_PRIVATE_KEY_HERE
    -----END OPENSSH PRIVATE KEY-----
```

- [ ] **步骤 2：验证文件已正确写入**

运行：`cat example/my-host/hosts/my-host/secrets.yaml | head -3`
预期：看到注释行

---

### 任务 7：创建 example/README.md

**文件：**
- 新增：`example/my-host/README.md`

- [ ] **步骤 1：创建示例说明文档**

```markdown
# Example - 私有配置仓库模板

这是 [nixos-config](https://github.com/Chikage0o0/nixos-config) 公共模块库的配套私有仓库模板。

## 快速开始

### 1. 初始化仓库

```bash
# 复制整个 example 目录为你的私有仓库
cp -r example/my-host ~/my-nixos-config
cd ~/my-nixos-config

# 初始化 git
git init
git add .
git commit -m "init: from nixos-config example"
```

### 2. 生成 age 密钥

```bash
# 进入包含所需工具的 shell
nix shell nixpkgs#age nixpkgs#ssh-to-age nixpkgs#sops

# 生成管理员 age 密钥对
age-keygen -o ~/.config/sops/age/keys.txt
# 查看公钥，稍后填入 .sops.yaml
age-keygen -y ~/.config/sops/age/keys.txt
```

### 3. 获取主机 age 公钥

在目标主机（要部署 NixOS 的机器）上执行：

```bash
# 方法一：通过 ssh-keyscan
ssh-keyscan localhost 2>/dev/null | ssh-to-age

# 方法二：直接读取 host key
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```

将输出的 age 公钥填入 `.sops.yaml` 的 `&my-host` 处。

### 4. 编辑配置

1. 编辑 `.sops.yaml` - 填入管理员和主机公钥
2. 编辑 `hosts/my-host/default.nix` - 修改用户名、邮箱、SSH 公钥等
3. 编辑 `hosts/my-host/secrets.yaml` - 填写真实密码和密钥
4. 编辑 `hosts/opencode-config.template.json` - 自定义 AI 模型配置

### 5. 加密机密文件

```bash
# 加密 secrets.yaml（.sops.yaml 配置正确后）
sops -e --input-type yaml --output-type yaml \
  hosts/my-host/secrets.yaml > /tmp/secrets.yaml
mv /tmp/secrets.yaml hosts/my-host/secrets.yaml

# 验证加密成功
cat hosts/my-host/secrets.yaml
# 应看到 sops metadata 和加密后的内容
```

### 6. 部署

```bash
# 确保当前主机名与 hostConfigs 中的键一致
hostname
# 如果不一致，可以手动指定：./deploy.sh my-host

./deploy.sh
```

## 添加新主机

1. 在 `hosts/` 下创建新目录，如 `hosts/laptop/`
2. 复制 `hosts/my-host/default.nix` 并修改配置
3. 非 WSL 环境需要将 `hardware-configuration.nix` 放入主机目录
4. 在 `.sops.yaml` 中添加新主机密钥和加密规则
5. 在 `flake.nix` 的 `hostConfigs` 中添加新条目
6. 为新主机创建并加密 `secrets.yaml`

## 目录结构

```
.
├── flake.nix          # Flake 入口
├── .sops.yaml         # sops 密钥配置
├── deploy.sh          # 部署脚本
├── hosts/
│   ├── my-host/
│   │   ├── default.nix            # 主机配置
│   │   ├── hardware-configuration.nix  # 硬件配置（非 WSL 需要）
│   │   └── secrets.yaml           # sops 加密的机密文件
│   └── opencode-config.template.json   # OpenCode 配置模板
└── README.md
```

## 注意事项

- `secrets.yaml` **必须**用 sops 加密后才能提交到 git
- `hardware-configuration.nix` 由 `nixos-generate-config` 自动生成，不要手动编辑
- 修改 `flake.nix` 中的 `nixos-config-public.url` 可以指向你自己的 fork
```

- [ ] **步骤 2：验证文件已正确写入**

运行：`wc -l example/my-host/README.md`
预期：约 100+ 行

---

### 任务 8：重构 README.md

**文件：**
- 修改：`README.md`（完整重写）

- [ ] **步骤 1：重写 README.md**

```markdown
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
| `virtualisation` | Docker |
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
```

- [ ] **步骤 2：验证 README 已正确写入**

运行：`wc -l README.md`
预期：约 200+ 行

---

### 任务 9：清理旧的 example 空目录

**文件：**
- 检查并清理：`example/` 目录下是否存在旧的空目录结构

- [ ] **步骤 1：检查 example 目录结构**

运行：`find example/ -type d -empty`
预期：不应有空目录（如果有，删除）

- [ ] **步骤 2：验证最终目录结构**

运行：`find example/ -type f | sort`
预期：看到以下文件列表
```
example/my-host/.sops.yaml
example/my-host/deploy.sh
example/my-host/flake.nix
example/my-host/hosts/my-host/default.nix
example/my-host/hosts/my-host/secrets.yaml
example/my-host/hosts/opencode-config.template.json
example/my-host/README.md
```

---

## 自审检查

**1. Spec 覆盖率：**
- ✅ 完整可运行 example（任务 1-7）
- ✅ README 重构（任务 8）
- ✅ 中文文档和注释
- ✅ sops-nix 示例
- ✅ 双受众（新手引导 + 高级用法）

**2. 占位符扫描：**
- 所有代码块均为完整内容，无 TBD/TODO

**3. 类型一致性：**
- myConfig 字段名与 lib/options.nix 和 lib/home-options.nix 完全一致
