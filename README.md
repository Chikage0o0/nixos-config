# NixOS Config Library

[![NixOS](https://img.shields.io/badge/NixOS-stable-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![CUDA](https://img.shields.io/badge/CUDA-12.x-green.svg?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

基于 **NixOS Flakes** 的可复用模块库，为 **KDE Plasma 日常工作站**、**AI 研发**、**CUDA 加速**和**全栈开发**场景提供开箱即用的配置。

仓库以 NixOS 26.05 对应的 stable `nixpkgs` 作为系统基线。Orange Pi Zero 3
提供按需导入的板级支持模块（内核固定、镜像封装与支持状态见
[`docs/orangepi-zero3.md`](docs/orangepi-zero3.md)），不影响其他主机。

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
- OMP、全栈开发工具和 Podman 由 role/feature 组合，不绑定到某个 profile。
- VS Code 属于 `fullstack-development` 的桌面 GUI 开发能力，不属于基础桌面包集合；仅在 fullstack-development role、platform.desktop.enable 与 platform.desktop.apps.enable 三者同时启用时安装。
- `fullstack-development` 通过 `nix-ld` 提供 Playwright 等工具下载的 Chromium 所需运行库（包括提供 `libnspr4.so` 的 `nspr`、NSS、图形与音频库），无需启用桌面。修改后需重新构建并切换系统配置；仅安装用户级包不能替代动态库搜索路径配置。

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
| `ai-tooling`            | OMP AI 助手、Orca 常驻服务、RTK 输出压缩与开发 Shell 环境 |
| `container-host`        | Podman 容器宿主                                    |
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
| `platform.machine.boot.mode`                    | enum                     | `"uefi"`    | 启动模式：uefi / bios / extlinux       |
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
| `platform.home.rtk.enable`                      | bool                     | `false`     | 安装 RTK CLI，供 AI 工具压缩命令输出 |
| `platform.home.rtk.package`                     | nullOr package           | `null`      | RTK 包覆盖；null 时使用 `pkgs.rtk`   |
| `platform.home.sshAgent.enable`                 | bool                     | `true`      | 自动启动 ssh-agent                   |
| `platform.home.sshAgent.sopsSecrets`            | listOf string            | `[ ]`       | 加载到 ssh-agent 的 sops secret      |
| `platform.development.fullstack.enable`        | bool                     | `false`     | 启用全栈开发工具包                  |
| `platform.packages.system.extra`                | listOf package           | `[ ]`       | 额外系统包                           |
| `platform.packages.home.extra`                  | listOf package           | `[ ]`       | 额外用户包                           |

### OMP 第一方 Home Manager Interface

`ai-tooling` role 通过 Home Manager shared module 以 `mkDefault` 启用 `programs.omp.enable`。OMP 的安装与声明式设置只使用官方 Interface：

| 选项路径 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `programs.omp.enable` | bool | `false` | 安装 OMP；`ai-tooling` role 默认启用 |
| `programs.omp.package` | package | Numtide `llm-agents.nix` 的 `omp` | 普通赋值即可覆盖，无需 `mkForce` |
| `programs.omp.settings` | nullOr YAML attrs | `null` | 以 `0600` 权限部署可写的 `~/.omp/agent/config.yml` |

公共 Home Manager 模块会在 `programs.omp.enable = true` 时以低优先级部署标准 `AGENTS.md`、skills、`.skill-lock.json` 和默认 `config.yml`。设置 `programs.omp.settings` 后，OMP 官方模块会在 Home Manager activation 中以可写普通文件覆盖默认 `config.yml`，允许 OMP 运行时加锁和改写；下一次 `home-manager switch` 会恢复声明值。其他标准资产仍可由调用方直接声明 `home.file` 覆盖；仓库不再维护第二套 OMP Interface。

标准 skills 位于 `modules/home/omp/agent/skills/`，包含 30 个技能及其参考文档、脚本和许可证。当前集合由以下固定快照组成：

| 来源 | 范围 | 固定版本 |
|---|---|---|
| [Matt Pocock](https://github.com/mattpocock/skills) | `engineering`、`productivity` 两组，共 27 个技能 | [`v1.3.1` / `24fe0ef7737efae15c87225755e9f6f5965e4888`](https://github.com/mattpocock/skills/tree/24fe0ef7737efae15c87225755e9f6f5965e4888/skills) |
| [Anthropic](https://github.com/anthropics/skills) | `frontend-design` | [`dbd4588f9e1033efb41dad4bef2f7947c8993d44`](https://github.com/anthropics/skills/tree/dbd4588f9e1033efb41dad4bef2f7947c8993d44/skills/frontend-design) |
| [Cloudflare](https://github.com/cloudflare/skills) | `web-perf` | [`86505e44f87d801aa1864a3c4109e9a8ae5c409f`](https://github.com/cloudflare/skills/tree/86505e44f87d801aa1864a3c4109e9a8ae5c409f/skills/web-perf) |
| [Jakub Krehel](https://github.com/jakubkrehel/make-interfaces-feel-better) | `make-interfaces-feel-better` | [`35545ea1512ad59fa463e6b1f95ca9c052981fe6`](https://github.com/jakubkrehel/make-interfaces-feel-better/tree/35545ea1512ad59fa463e6b1f95ca9c052981fe6/skills/make-interfaces-feel-better) |

Matt Pocock 的技能仅做 OMP 调用方式适配：模型通过 `read` 读取 `skill://<name>`，用户通过 `/skill:<name>` 调用；保留上游的 `disable-model-invocation` 边界。MIT 许可保存在 `skills/MATT-POCOCK-LICENSE.txt`。`v1.3.1` 新增 `implement-spec`、`pr`、`retro`，移除 `resolving-merge-conflicts`，并将领域词汇表约定从 `CONTEXT.md` / `CONTEXT-MAP.md` 改为 `GLOSSARY.md` / `GLOSSARY-MAP.md`；已有词汇表需随使用该集合的项目迁移。

更新技能集合时应完整替换对应来源的目录，删除新集合不再提供的旧技能，保留其他来源的技能，并重新应用上述 OMP 适配、同步来源版本和许可证。这些文件由仓库管理，`.skill-lock.json` 保持空的 v3 安装器记录，不承担版本追踪；来源版本以上表为准。部署更新后的 Home Manager 配置并重新启动 OMP 后，新集合才会用于正常会话。

若本仓库作为 Git 子模块被父 flake 引用，父仓库的普通 Git flake 评估可能仍使用子模块的已提交快照。验证未提交的修改时，使用 `--override-input <公共输入名> path:<本仓库绝对路径> --no-write-lock-file`；正常部署前需先提交子模块改动并更新父仓库的子模块指针。

#### 包来源、缓存与源码构建

本仓库统一管理 OMP 的模块和包来源，调用方不需要在父 flake 中声明 OMP 输入、
注入包集合或添加 Home Manager shared module 来覆盖安装包：

- `inputs.omp` 保留官方 NixOS/Home Manager Interface；`inputs.llm-agents` 跟随
  [`numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix) 的 `main`
  分支（上游只有 `assets` 一个 tag，没有版本 tag 或 release，无法跟随发布版本），
  当前锁定 `b711aa741409cd51bac109375cc6597c8b8f76cc`，提供 OMP `18.11.0`。
  官方配置 Interface 单独固定为 `v18.11.1`；Numtide 当前尚未提供该版本的包，
  因此更新到其最新 `main` 不代表 CLI 与官方最新 release 版本相同。
- `nixosModules.default` 和 `homeModules.default` 均以 `lib.mkDefault` 选择
  `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp`，
  覆盖 `x86_64-linux` 与 `aarch64-linux`。独立 Home Manager 消费方也使用同一默认包。
  自定义包仍通过对应层级的 `programs.omp.package` 设置。
- 保留 `llm-agents` 自己的 nixpkgs 锁，不设置 `inputs.nixpkgs.follows`，也不使用其
  共享 nixpkgs overlay；改变构建输入会改变 store 路径，可能失去缓存命中。
- 公共 NixOS 基础模块和本 flake 的 `nixConfig` 均配置 `https://cache.numtide.com`，
  公钥为 `niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=`。
  这是对 Numtide 构建产物的额外信任，不替代已有缓存。依赖 flake 的 `nixConfig`
  不替代消费方顶层的缓存配置；首次部署或独立 Home Manager 使用时，需要在构建机
  的 Nix 配置或顶层 flake 中显式信任该缓存。
- Numtide 的包从源码编译 Rust native addon 和 Bun CLI。缓存与本地 store 均没有输出时，
  Nix 可回退到源码构建；源码、依赖需可下载或已在 store 中，并需要足够资源及对应架构
  的本地、远程或模拟 builder。锁定输入可重建不等于已验证逐字节一致，本仓库未执行
  双架构完整源码重建。网络或签名错误不等于普通缓存未命中，不应关闭签名校验。
- 升级在本仓库执行 `nix flake update llm-agents`，检查两个架构的缓存和运行结果；
  依赖本仓库的父 flake 随后执行 `nix flake update <本仓库 input>`——`nix flake lock`
  不会重新解析已存在的传递输入。跟随 `main` 意味着每次更新都可能引入上游任意提交，
  发布前必须验证。

来源：[Numtide 缓存说明](https://github.com/numtide/llm-agents.nix#binary-cache)、
[OMP derivation](https://github.com/numtide/llm-agents.nix/blob/main/packages/omp/package.nix)。

### Orca 常驻服务

公共 NixOS 模块提供 `services.orca-server`，模块本身默认关闭，
`ai-tooling` role 通过 `lib.mkDefault true` 默认启用，无需主机单独开启。
主机可用普通赋值 `services.orca-server.enable = false;` 禁用。
公共 flake 已将
[`numtide/llm-agents.nix`](https://github.com/numtide/llm-agents.nix)
对应平台的 `packages.${system}.orca` 注入 `services.orca-server.package`；
单独导入服务文件时需自行提供该包。这里使用完整 Orca 包和官方推荐的
`orca serve --supervise`，不是精简的 server-only daemon。

```nix
{
  services.orca-server = {
    # ai-tooling 已默认启用；其他 role 按需设置 enable = true。
    # package 由公共 flake 注入 llm-agents.packages.${system}.orca。
    user = "chikage"; # 默认 config.platform.user.name
    port = 6768; # 默认值
  };
}
```

`user` 必须是 `users.users` 中已声明且有独立 home 的非 root 用户。
服务以该用户运行，等待 home 挂载，工作目录及 `HOME` 均使用其配置的 home，
`ORCA_USER_DATA_PATH` 为 `${home}/.orca`，复用已有 Orca 数据。
系统单元只配置静态工具路径，不自动读取交互 shell 环境或其中的机密。
模块不开放防火墙、不修改认证，也不绕过沙箱；是否允许远程访问由主机另行决定。

部署后检查系统单元与日志：

```bash
systemctl status orca-server.service
journalctl -u orca-server.service -b --no-pager
```

在私有 flake 根目录获取服务使用的准确包路径，再以服务用户运行 CLI，
避免误用其他版本或 root 的数据目录（替换主机名及用户名）：

```bash
orca_package=$(nix eval --raw \
  .#nixosConfigurations.chikage-homeserver.config.services.orca-server.package.outPath)
orca_data=$(nix eval --raw \
  .#nixosConfigurations.chikage-homeserver.config.systemd.services.orca-server.environment.ORCA_USER_DATA_PATH)
sudo -H -u chikage "$orca_package/bin/orca" --version
sudo -H -u chikage env ORCA_USER_DATA_PATH="$orca_data" "$orca_package/bin/orca" status --json
```

服务显式复用 `~/.orca`；CLI 的原生默认数据目录可能不同，管理此服务时必须指定相同
`ORCA_USER_DATA_PATH`，不要把另一个数据目录的 `not_running` 当成服务故障。
`orca status --json` 用于检查实际 runtime；应确认 `result.runtime.state = "ready"`、
`result.runtime.reachable = true`，不能只看顶层 `ok` 或 systemd 单元状态。
服务启动到网络端口就绪之间存在初始化阶段。
此模块管理的是系统单元，不使用 Orca 自注册的 service 管理命令。
服务始终带 `--no-pairing`，防止自动输出含 token 的配对链接到 journal。
需要配对时，须以同一用户在受信任的交互终端显式另行操作，参照
[官方 CLI 文档](https://www.onorca.dev/docs/cli/reference)；不要把配对链接或明文
token 写入 Nix 配置、公共文档或日志。

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
  secrets.sops = {
    enable = true;
    defaultFile = ./hosts/gpu-workstation/secrets.yaml;
    ageKeyFile = "/home/${commonUser.name}/.config/sops/age/keys.txt";
    secrets = {
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
│   │   ├── omp/           # Oh My Pi AI 助手与标准 agent 配置
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
| `default` | 导出 tabby 等自定义包 |

---

## 文档

| 文档 | 内容 |
| --- | --- |
| [`docs/migration-from-root-nix.md`](docs/migration-from-root-nix.md) | 从最小安装、`root` 直管的环境切换到本仓库工作流 |
| [`docs/migration-from-myConfig.md`](docs/migration-from-myConfig.md) | 从旧 `myConfig` 选项迁移到 `platform.*`（含字段映射表） |
| [`docs/orangepi-zero3.md`](docs/orangepi-zero3.md) | Orange Pi Zero 3 板级模块、内核固定与支持状态 |
| [`docs/archive/`](docs/archive/) | 历史实施计划与设计稿存档，不反映当前结构 |

---

## 许可证

MIT License
