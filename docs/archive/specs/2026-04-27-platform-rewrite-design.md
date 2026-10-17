# NixOS 配置平台化重写设计

## 目标

将当前仓库从“可复用模块集合”重构为“可组合的 NixOS 配置平台”。新的平台需要同时服务 WSL、工作站、AI 加速主机、服务器管理和通用模块库场景，并在允许破坏性调整的前提下改善架构边界、配置接口和验证闭环。

本次设计追求三项平衡：

- 模块边界清晰，新增能力时能定位到明确目录和职责。
- 配置接口更语义化，host 声明描述“机器是什么、承担什么职责、启用什么能力”。
- 具备最小可执行验证，降低平台化重写带来的回归风险。

## 当前问题

现有代码已经具备可复用基础，但结构仍偏向单仓库模块拼装：

- `myConfig` 是扁平字段集合，`username`、`isWSL`、`enableDae`、`opencodeSettings` 等不同领域混在一起。
- NixOS 与 Home Manager 选项分别定义在 `lib/options.nix` 和 `lib/home-options.nix`，用户信息、OpenCode 配置等存在重复传参。
- `modules/nixos/` 当前按少量文件平铺，基础系统、启动器、网络、容器、服务、硬件和开发工具的边界不够清晰。
- `example/my-host` 暴露大量平台装配细节，例如 `specialArgs`、Home Manager 接入、sops 模板和 WSL/物理机分支。
- 当前缺少 `checks`，重构后只能依赖人工 eval 或实际部署发现问题。

## 非目标

- 不保留旧 `myConfig` 兼容层。迁移通过文档和映射表完成。
- 不把 dae 设计成代理网关角色。dae 只表示本机透明代理能力。
- 不把 OpenCode、AI/全栈开发工具或 Podman 绑定到某个 profile。它们必须能在 WSL、服务器和工作站之间按需组合。
- 不在第一版实现复杂测试 harness。先提供能覆盖 example/profile 组合的 flake checks。
- 不把私有 host 信息、secrets 明文或机器专属路径写进公共 profile。

## 总体架构

新架构分为三层：平台构造层、能力模块层、场景组合层。

```text
lib/platform/
  负责 mkHost、mkSystem、mkHome、profile/role 合成、host 规范化和验证。

modules/
  负责可复用能力实现。模块只消费明确的 platform.* 选项，不负责猜测主机场景。

profiles/ 和 roles/
  负责把机器形态基线与可跨场景复用的职责组合成 host 配置。
```

私有仓库不再手写 `nixpkgs.lib.nixosSystem` 和大量 `specialArgs`，而是调用公共仓库导出的平台函数声明 host。平台函数统一处理 inputs、overlays、Home Manager、sops、profile/role 合成和验证入口。

## 对外 API

废弃扁平 `myConfig`，改用结构化平台配置。`mkHost` 的输入保持面向 host 声明的简洁字段；平台函数会把这些字段规范化为模块内部读取的 `config.platform.*`。私有仓库示例：

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

  machine = {
    class = "workstation";
    wsl.enable = false;
    boot = {
      mode = "uefi";
      grubDevice = null;
    };
    nvidia.enable = true;
  };

  profiles = [ "workstation-base" ];
  roles = [
    "development"
    "fullstack-development"
    "ai-tooling"
    "container-host"
    "remote-admin"
  ];

  home.opencode = {
    enable = true;
    settings = { };
    configFile = null;
  };

  networking = {
    transparentProxy = {
      enable = false;
      backend = "dae";
      configFile = null;
    };
  };

  services = {
    cockpit.enable = true;
    openssh.enable = true;
  };

  secrets.sops = {
    enable = true;
    defaultFile = ./hosts/workstation/secrets.yaml;
    ageKeyFile = "/home/chikage/.config/sops/age/keys.txt";
  };
}
```

模块内部统一读取规范化后的 `config.platform.*`。Home Manager 通过 `home-manager.sharedModules` 接收同一份用户和功能配置，避免 NixOS 与 Home Manager 选项重复定义和重复传参。

旧字段迁移关系：

| 旧字段 | 新字段 |
| --- | --- |
| `myConfig.username` | `platform.user.name` |
| `myConfig.userFullName` | `platform.user.fullName` |
| `myConfig.userEmail` | `platform.user.email` |
| `myConfig.sshPublicKey` | `platform.user.sshPublicKey` |
| `myConfig.nixMaxJobs` | `platform.nix.maxJobs` |
| `myConfig.isWSL` | `platform.machine.wsl.enable` |
| `myConfig.bootMode` | `platform.machine.boot.mode` |
| `myConfig.grubDevice` | `platform.machine.boot.grubDevice` |
| `myConfig.isNvidia` | `platform.machine.nvidia.enable` |
| `myConfig.enableDae` | `platform.networking.transparentProxy.enable` |
| `myConfig.daeConfigFile` | `platform.networking.transparentProxy.configFile` |
| `myConfig.enableCockpit` | `platform.services.cockpit.enable` |
| `myConfig.cockpitExtraOrigins` | `platform.services.cockpit.extraOrigins` |
| `myConfig.extraHosts` | `platform.networking.extraHosts` |
| `myConfig.opencodeSettings` | `platform.home.opencode.settings` |
| `myConfig.opencodeConfigFile` | `platform.home.opencode.configFile` |
| `myConfig.sshSopsSecrets` | `platform.home.sshAgent.sopsSecrets` |
| `myConfig.enableSshAgent` | `platform.home.sshAgent.enable` |

## 目录结构

目标结构：

```text
lib/
  default.nix
  platform/
    default.nix
    types.nix
    checks.nix
    modules.nix

modules/
  shared/
    options.nix
  nixos/
    default.nix
    core/
    boot/
    users/
    networking/
    services/
    hardware/
    containers/
    packages/
  home/
    default.nix
    core/
    shell/
    git/
    development/
    opencode/

  profiles/
    default.nix
    wsl-base.nix
    workstation-base.nix
    server-base.nix
    generic-linux.nix

roles/
    default.nix
    development.nix
    fullstack-development.nix
    ai-tooling.nix
    container-host.nix
    remote-admin.nix
    ai-accelerated.nix
```

边界规则：

- `lib/platform` 只负责组合、规范化和验证，不写具体服务配置。
- `modules/shared/options.nix` 定义 `platform.*` 公共选项，NixOS 与 Home Manager 共享。
- NixOS 模块只依赖 `config.platform.*` 和本层 NixOS 选项，不读取 example 或私有仓库路径。
- Home Manager 模块只处理用户态配置，系统级开关由共享 `platform.*` 配置提供。
- `profiles` 只设置机器形态默认值和平台约束，不包含 host 私有信息、secrets 或可跨场景复用的工具能力。

## Profile、Role 与 Feature

三者分工：

- `profile` 表达机器形态、平台约束和最低默认值，例如 WSL 基线、工作站基线、服务器基线。
- `role` 表达主机职责和工具组合，例如开发环境、全栈开发、AI 工具、容器宿主、远程管理、AI 加速。
- `feature` 表达可独立开关的能力，例如本机透明代理、Cockpit、OpenSSH、OpenCode。

组合原则：`profile` 不拥有工具能力，`role` 和 `feature` 不能假设自己只运行在某一种机器形态上。WSL 可以启用 OpenCode、AI/全栈开发工具和 Podman；服务器也可以启用这些能力。平台只在能力确实依赖不可用硬件或系统机制时给出断言，例如 NVIDIA/CUDA 不能在 WSL profile 中启用。

默认值优先级从低到高为：模块默认值、profile 默认值、role 默认值、host 显式配置。profile 可以提供硬约束，例如 WSL 不配置 bootloader；但不应通过 profile 阻止用户启用 OpenCode、开发工具或容器工具。

初始 profile：

| Profile | 职责 |
| --- | --- |
| `wsl-base` | 启用 WSL 集成，禁用 boot、firewall、NetworkManager 等物理机默认能力；不默认绑定开发工具。 |
| `workstation-base` | 物理工作站基线，面向本地交互、图形/硬件设备和可选专用硬件；不默认绑定 Podman、AI/全栈开发工具、OpenCode 或 NVIDIA/CUDA。 |
| `server-base` | 服务器基线、OpenSSH、最小系统包、禁用 GUI 假设。 |
| `generic-linux` | 最小 NixOS + Home Manager 基线，作为特殊机器起点。 |

初始 role：

| Role | 职责 |
| --- | --- |
| `development` | git、shell、direnv、通用 CLI 工具。 |
| `fullstack-development` | Node.js、Python、Go、Rust、数据库客户端和构建工具等全栈开发工具。 |
| `ai-tooling` | OpenCode、AI CLI、AI 辅助研发工具和相关 Home Manager 配置；secret 值仍由 host 显式提供。 |
| `container-host` | Podman、Docker CLI 兼容、podman-compose shim。应能用于服务器、工作站和 WSL；实现时按 profile 调整不适用的系统级细节。 |
| `remote-admin` | OpenSSH、Cockpit、必要 firewall 规则；WSL 默认不启用 Cockpit，显式启用时由模块校验支持性。 |
| `ai-accelerated` | NVIDIA、CUDA、nvidia-container-toolkit。只在非 WSL 且启用 NVIDIA 的 Linux 主机上有效。 |

示例组合：

| 场景 | Profile | Roles / Features |
| --- | --- | --- |
| WSL 上使用 OpenCode、全栈工具和 Podman | `wsl-base` | `development`、`fullstack-development`、`ai-tooling`、`container-host` |
| 服务器上跑 Podman 并远程管理 | `server-base` | `container-host`、`remote-admin`，可按需加 `development` 或 `ai-tooling` |
| GPU 工作站做 AI/全栈开发 | `workstation-base` | `development`、`fullstack-development`、`ai-tooling`、`container-host`、`ai-accelerated` |

`networking.transparentProxy` 是本机透明代理 feature，初始 backend 为 `dae`。它不是 `proxy-gateway` role，也不表示为局域网其他设备提供网关能力。

## 平台构建数据流

```text
private flake host 声明
  -> lib.platform.normalizeHost
  -> lib.platform.validateHost
  -> lib.platform.resolveProfiles
  -> nixpkgs.lib.nixosSystem
  -> NixOS modules + Home Manager sharedModules
```

职责分配：

- 私有仓库只声明 host metadata、profiles、roles、features、secrets 路径。
- `normalizeHost` 补齐默认值，例如 `system`、`stateVersion`、profile 默认服务开关。
- `validateHost` 对跨字段约束给出清晰错误。
- `resolveProfiles` 将 profile/role 转为模块列表和 `platform.*` 默认值，并按“模块默认值 < profile < role < host 显式配置”的优先级合并。
- NixOS 模块读取 `config.platform.*` 生成系统配置。
- Home Manager 通过 shared module 接收 `platform.user`、`platform.home` 和开发工具配置。

## Secrets 设计

平台只接收 secret 文件路径和 sops secret 名称，不接受明文 secret 值。

规则：

- OpenCode API key、SSH 私钥、dae 配置都通过 sops runtime path 注入。
- 含密 OpenCode 配置继续通过 sops template 或 out-of-store symlink 暴露给 Home Manager，避免进入 Nix store。
- `networking.transparentProxy.configFile` 应指向 `/run/secrets/...` 这类运行时路径。
- example 的 `secrets.yaml` 只能作为结构模板，文档必须要求用户填入真实值后加密再提交。

## 错误处理与断言

平台和模块提供以下断言：

- 非 WSL + BIOS 必须提供 `platform.machine.boot.grubDevice`。
- UEFI 不允许设置 `platform.machine.boot.grubDevice`。
- `platform.networking.transparentProxy.enable = true` 时必须提供 `configFile`。
- `platform.networking.transparentProxy.backend` 初始只支持 `dae`。
- `platform.machine.wsl.enable = true` 时默认禁用不适用的 boot、firewall、NetworkManager 和 Cockpit，但不得因此禁止 OpenCode、开发工具或 WSL 可支持的容器工具。
- `platform.machine.nvidia.enable = true` 只允许在非 WSL Linux 主机启用。
- `ai-accelerated` 依赖 NVIDIA/CUDA；`ai-tooling` 只依赖用户态工具和 secrets 配置，两者不能混为一个硬件条件。
- 用户字段 `name`、`fullName`、`email`、`sshPublicKey` 必须存在且类型明确。

## Flake 导出设计

公共仓库导出：

```nix
{
  overlays.default = ...;

  lib = {
    mkHost = ...;
    mkSystem = ...;
    mkHome = ...;
    platform = ...;
  };

  nixosModules = {
    default = ...;
    platform = ...;
    profiles = ...;
    roles = ...;
  };

  homeModules = {
    default = ...;
    platform = ...;
  };

  checks = ...;
  formatter = ...;
}
```

旧的单模块导出可以在重写期间删除或重新映射到新模块路径。由于本次允许破坏性调整，不需要保留旧导出名的兼容层；但 README 和迁移文档必须明确新 API 是唯一推荐入口。

## Example 与文档迁移

`example/my-host` 升级为多场景私有仓库模板：

```text
example/my-host/
  flake.nix
  README.md
  .sops.yaml
  deploy.sh
  hosts/
    wsl-dev/
      default.nix
      secrets.yaml
    workstation/
      default.nix
      hardware-configuration.nix.example
      secrets.yaml
    server/
      default.nix
      hardware-configuration.nix.example
      secrets.yaml
  templates/
    opencode-config.template.json
```

文档更新：

- `README.md` 改成平台入口说明，重点介绍 `mkHost`、profile、role、feature。
- `docs/migration-from-root-nix.md` 更新为新私有仓库模板流程。
- 新增 `docs/migration-from-myConfig.md`，提供旧字段到新字段映射和迁移示例。
- completed spec/plan 作为历史不修改，但新文档不得继续推荐旧 `myConfig` 接口。
- 清理新文档中的旧概念残留，例如已删除的 `rtk`、不准确的 Docker 命名。

## 验证设计

新增最小验证闭环：

- `formatter` 使用仓库选定的 Nix formatter，例如 `nixfmt-rfc-style`。
- `checks.x86_64-linux.example-wsl` 验证 WSL profile 可以 eval。
- `checks.x86_64-linux.example-wsl-dev-container` 验证 WSL + OpenCode + 全栈开发工具 + Podman 组合可以 eval。
- `checks.x86_64-linux.example-server` 验证服务器 profile 可以 eval。
- `checks.x86_64-linux.example-server-dev-container` 验证服务器 + 开发工具 + Podman 组合可以 eval。
- `checks.x86_64-linux.example-workstation` 验证工作站 profile 可以 eval。
- `checks.x86_64-linux.example-gpu-workstation` 验证工作站 + AI 加速 role 可以 eval，必要时只做 eval 或 dry-run，避免强制本地构建大型 CUDA 闭源依赖。
- 实施完成后运行 `nix flake check`。
- 必要时补充 `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run` 作为人工验收命令。

验收标准：

- 仓库格式化通过。
- `nix flake check` 通过。
- example 中至少一个 WSL、一个服务器、一个工作站配置可 eval。
- WSL 和服务器 example 至少各有一个组合验证覆盖 OpenCode、开发工具或 Podman，证明工具能力没有绑定到单一 profile。
- README、example 和迁移文档均使用新 API，无旧 `myConfig` 作为推荐路径。
- dae 在文档和配置中都表述为“本机透明代理”，不作为代理网关角色。

## 实施顺序建议

后续实施计划应按以下顺序拆分：

1. 建立 `platform.*` option 类型和 `lib/platform` 构造函数骨架。
2. 重组 NixOS 模块目录并迁移 core、boot、users、networking、services、hardware、containers。
3. 重组 Home Manager 模块目录并接入共享 `platform.*` 配置。
4. 实现 profiles、roles 和 features 合成，包括跨 profile 组合、默认值优先级和冲突断言。
5. 改造 `flake.nix` 导出、formatter 和 checks。
6. 迁移 `example/my-host` 为多场景模板。
7. 更新 README 和迁移文档。
8. 运行格式化和 `nix flake check`，根据失败补齐断言或默认值。
