# NixOS 配置平台化重写 实施计划

> **给代理执行者：** REQUIRED SUB-SKILL: 使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务执行本计划。步骤使用复选框 `- [ ]` 语法追踪。

**目标：** 将仓库从旧 `myConfig` 模块集合重写为以 `mkHost`、`platform.*`、profile、role 和 feature 为入口的可组合 NixOS 配置平台。

**架构：** 新增 `modules/shared/options.nix` 作为 NixOS 与 Home Manager 共享的 `platform.*` 类型定义；新增 `lib/platform` 统一处理 host 规范化、profile/role 解析、Home Manager 桥接、sops-nix 和 flake checks。能力模块迁移到按职责划分的目录，profile 只描述机器形态，role/feature 负责 OpenCode、全栈工具、Podman、远程管理和 AI 加速等可组合能力。

**技术栈：** NixOS Flakes, Nix modules, Home Manager, sops-nix, nixos-wsl, Podman, OpenCode

---

## 文件结构与职责

新增或重写这些文件：

| 路径 | 职责 |
| --- | --- |
| `modules/shared/options.nix` | 定义 NixOS 与 Home Manager 共享的 `platform.*` 选项。 |
| `lib/default.nix` | 导出 `platform`、`mkHost`、`mkSystem`、`mkHome`，不再导出旧 `myConfig` options。 |
| `lib/platform/default.nix` | 实现 `normalizeHost`、`validateHost`、`resolveProfiles`、`resolveRoles`、`mkHost`。 |
| `lib/platform/modules.nix` | 集中维护 profile 与 role 名称到模块路径的映射。 |
| `lib/platform/checks.nix` | 生成 eval-only checks，覆盖 WSL、服务器、工作站和跨 profile 工具组合。 |
| `modules/nixos/default.nix` | 聚合新的 NixOS 平台模块。 |
| `modules/nixos/core/base.nix` | Nix、`nix-ld`、zsh、内核基线、`system.stateVersion`。 |
| `modules/nixos/core/assertions.nix` | 跨字段断言：boot、WSL、透明代理、NVIDIA/CUDA。 |
| `modules/nixos/boot/grub.nix` | 非 WSL 主机的 GRUB/UEFI/BIOS 配置。 |
| `modules/nixos/users/default.nix` | 主用户、SSH 公钥、sudo 规则、按能力加入系统组。 |
| `modules/nixos/networking/base.nix` | NetworkManager、firewall、hosts、BBR、时区。 |
| `modules/nixos/networking/transparent-proxy.nix` | 本机透明代理 feature，初始 backend 为 `dae`。 |
| `modules/nixos/services/cockpit.nix` | Cockpit 服务、插件、allowed origins、内存限制。 |
| `modules/nixos/services/openssh.nix` | OpenSSH 服务与安全默认值。 |
| `modules/nixos/hardware/nvidia.nix` | NVIDIA/CUDA 与 nvidia-container-toolkit。 |
| `modules/nixos/containers/podman.nix` | Podman、Docker CLI 兼容、podman-compose 网络设置。 |
| `modules/nixos/packages/system.nix` | 系统基础包与 host 扩展包。 |
| `modules/home/default.nix` | 聚合新的 Home Manager 平台模块。 |
| `modules/home/core/base.nix` | Home Manager 用户名、homeDirectory、stateVersion。 |
| `modules/home/git/default.nix` | Git、LFS、SSH 签名。 |
| `modules/home/shell/default.nix` | zsh、ssh-agent、starship、direnv、SSH 默认配置。 |
| `modules/home/development/cli-tools.nix` | eza、zoxide、fzf、bat、lazygit。 |
| `modules/home/development/packages.nix` | 通用开发包、全栈开发包、sops/age 工具。 |
| `modules/home/opencode/default.nix` | OpenCode 包、公共配置文件、运行时 out-of-store 配置。 |
| `profiles/*.nix` | 机器形态基线：`wsl-base`、`workstation-base`、`server-base`、`generic-linux`。 |
| `roles/*.nix` | 可跨 profile 组合的职责：开发、全栈、AI 工具、容器、远程管理、AI 加速。 |
| `flake.nix` | 导出新 overlay、lib、modules、checks、formatter。 |
| `example/my-host/**` | 改为多场景私有仓库模板。 |
| `README.md` | 改成平台入口文档。 |
| `docs/migration-from-root-nix.md` | 更新 root 迁移流程到新 API。 |
| `docs/migration-from-myConfig.md` | 新增旧字段到新字段迁移指南。 |

删除这些旧入口文件，避免继续暴露旧 `myConfig`：

| 路径 | 删除原因 |
| --- | --- |
| `lib/options.nix` | 旧 NixOS `myConfig` options。 |
| `lib/home-options.nix` | 旧 Home Manager `myConfig` options。 |
| `modules/nixos/base.nix` | 迁移到 `modules/nixos/core/base.nix` 与 `modules/nixos/boot/grub.nix`。 |
| `modules/nixos/network.nix` | 迁移到 `modules/nixos/networking/base.nix`。 |
| `modules/nixos/users.nix` | 迁移到 `modules/nixos/users/default.nix`。 |
| `modules/nixos/virtualisation.nix` | 迁移到 `modules/nixos/containers/podman.nix`。 |
| `modules/nixos/packages.nix` | 迁移到 `modules/nixos/packages/system.nix`。 |
| `modules/home/base.nix` | 迁移到 `modules/home/core/base.nix`。 |
| `modules/home/git.nix` | 迁移到 `modules/home/git/default.nix`。 |
| `modules/home/shell.nix` | 迁移到 `modules/home/shell/default.nix`。 |
| `modules/home/cli-tools.nix` | 迁移到 `modules/home/development/cli-tools.nix`。 |
| `modules/home/opencode.nix` | 迁移到 `modules/home/opencode/default.nix`。 |
| `modules/home/packages.nix` | 迁移到 `modules/home/development/packages.nix`。 |

## 全局执行规则

- 每个任务开始前运行 `git status --short`，只确认当前变更范围，不回滚用户或其他代理的改动。
- 所有 Nix 文件改动后运行 `nix fmt`；最终运行 `nix flake check`。
- 如果执行会话已获得用户明确授权提交，则每个任务结束后用 `git-commit` skill 提交该任务的变更；没有授权时跳过提交步骤并记录未提交状态。
- 所有新文档和代码注释使用中文；Nix 标识符、路径、命令保持原样。

---

### 任务 1：建立 `platform.*` 共享选项

**文件：**
- 新增：`modules/shared/options.nix`
- 修改：`modules/nixos/default.nix`
- 修改：`modules/home/default.nix`

- [ ] **步骤 1：写失败验证**

运行：`nix eval .#nixosModules.platform`

预期：失败，并出现属性不存在的错误，因为 flake 还没有导出 `nixosModules.platform`。

- [ ] **步骤 2：新增共享 options 文件**

创建 `modules/shared/options.nix`：

```nix
{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.platform = {
    profiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "当前 host 启用的 profile 名称列表。";
    };

    roles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "当前 host 启用的 role 名称列表。";
    };

    stateVersion = mkOption {
      type = types.str;
      default = "25.11";
      description = "NixOS 与 Home Manager 的 stateVersion。";
    };

    user = {
      name = mkOption {
        type = types.str;
        description = "主用户名。";
        example = "chikage";
      };

      fullName = mkOption {
        type = types.str;
        description = "用户全名，用于 Git 等用户态工具。";
        example = "Chikage";
      };

      email = mkOption {
        type = types.str;
        description = "用户邮箱，用于 Git 等用户态工具。";
        example = "user@example.com";
      };

      sshPublicKey = mkOption {
        type = types.str;
        description = "主用户 SSH 公钥。";
        example = "ssh-ed25519 AAAA... user@host";
      };
    };

    machine = {
      class = mkOption {
        type = types.enum [
          "wsl"
          "workstation"
          "server"
          "generic"
        ];
        default = "generic";
        description = "机器形态，不表达工具能力。";
      };

      wsl.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 WSL 机器形态约束。";
      };

      boot = {
        mode = mkOption {
          type = types.enum [
            "uefi"
            "bios"
          ];
          default = "uefi";
          description = "非 WSL 主机的 GRUB 启动模式。";
        };

        grubDevice = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "传统 BIOS 模式下 GRUB 的安装目标磁盘路径。";
          example = "/dev/disk/by-id/wwn-0x500001234567890a";
        };
      };

      nvidia.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 NVIDIA/CUDA 机器能力。";
      };
    };

    nix.maxJobs = mkOption {
      type = types.either types.int (types.enum [ "auto" ]);
      default = "auto";
      description = "Nix 最大并行构建数。";
    };

    networking = {
      extraHosts = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        description = "额外的 /etc/hosts 映射。";
      };

      transparentProxy = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用本机透明代理。";
        };

        backend = mkOption {
          type = types.enum [ "dae" ];
          default = "dae";
          description = "透明代理 backend。第一版只支持 dae。";
        };

        configFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "透明代理运行时配置文件路径，推荐使用 /run/secrets/...。";
        };
      };
    };

    services = {
      openssh.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 OpenSSH。";
      };

      cockpit = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 Cockpit。";
        };

        extraOrigins = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "额外允许的 Cockpit Web origin。";
        };
      };
    };

    containers.podman.enable = mkOption {
      type = types.bool;
      default = false;
      description = "是否启用 Podman 与 Docker CLI 兼容层。";
    };

    home = {
      git.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 Git 用户配置。";
      };

      shell.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 zsh、starship、direnv 与 SSH 用户配置。";
      };

      cliTools.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用现代 CLI 工具。";
      };

      sshAgent = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否自动启动 ssh-agent 并加载 sops 私钥。";
        };

        sopsSecrets = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "要加载到 ssh-agent 的 sops secret 名称列表。";
        };
      };

      opencode = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 OpenCode 用户态配置。";
        };

        settings = mkOption {
          type = types.attrs;
          default = { };
          description = "OpenCode 非机密 settings 覆盖。";
        };

        configFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "运行时生成的 OpenCode 配置文件路径，优先于 settings。";
        };
      };
    };

    development = {
      fullstack.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用全栈开发工具包。";
      };
    };

    packages = {
      system.extra = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "额外系统包。";
      };

      home.extra = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "额外 Home Manager 用户包。";
      };
    };
  };
}
```

- [ ] **步骤 3：临时接入共享 options，不切换旧模块实现**

修改 `modules/nixos/default.nix`，先只把共享 options 加入 imports，旧模块仍保留到后续任务迁移：

```nix
{ ... }:
{
  imports = [
    ../shared/options.nix
    ../../lib/options.nix
    ./base.nix
    ./network.nix
    ./users.nix
    ./virtualisation.nix
    ./packages.nix
    ./services/cockpit.nix
    ./services/dae.nix
    ./services/openssh.nix
    ./hardware/nvidia.nix
  ];
}
```

修改 `modules/home/default.nix`，先只把共享 options 加入 imports，旧模块仍保留到后续任务迁移：

```nix
{ ... }:
{
  imports = [
    ../shared/options.nix
    ../../lib/home-options.nix
    ./base.nix
    ./git.nix
    ./shell.nix
    ./cli-tools.nix
    ./opencode.nix
    ./packages.nix
  ];
}
```

- [ ] **步骤 4：验证共享 options 可被导入**

运行：`nix eval --impure --expr 'let flake = builtins.getFlake (toString ./.); in builtins.hasAttr "default" flake.nixosModules'`

预期：输出 `true`。

---

### 任务 2：实现平台 lib、profile 和 role 映射

**文件：**
- 新增：`lib/platform/default.nix`
- 新增：`lib/platform/modules.nix`
- 新增：`profiles/default.nix`
- 新增：`profiles/wsl-base.nix`
- 新增：`profiles/workstation-base.nix`
- 新增：`profiles/server-base.nix`
- 新增：`profiles/generic-linux.nix`
- 新增：`roles/default.nix`
- 新增：`roles/development.nix`
- 新增：`roles/fullstack-development.nix`
- 新增：`roles/ai-tooling.nix`
- 新增：`roles/container-host.nix`
- 新增：`roles/remote-admin.nix`
- 新增：`roles/ai-accelerated.nix`
- 修改：`lib/default.nix`
- 修改：`flake.nix`

- [ ] **步骤 1：写失败验证**

运行：`nix eval .#lib.platform.profileNames --json`

预期：失败，并出现 `platform` 属性不存在。

- [ ] **步骤 2：创建 profile 模块**

创建 `profiles/default.nix`：

```nix
{
  wsl-base = ./wsl-base.nix;
  workstation-base = ./workstation-base.nix;
  server-base = ./server-base.nix;
  generic-linux = ./generic-linux.nix;
}
```

创建 `profiles/wsl-base.nix`：

```nix
{ lib, ... }:
{
  platform.machine.class = lib.mkDefault "wsl";
  platform.machine.wsl.enable = lib.mkDefault true;
  platform.services.openssh.enable = lib.mkDefault false;
  platform.services.cockpit.enable = lib.mkDefault false;
}
```

创建 `profiles/workstation-base.nix`：

```nix
{ lib, ... }:
{
  platform.machine.class = lib.mkDefault "workstation";
  platform.machine.wsl.enable = lib.mkDefault false;
  platform.services.openssh.enable = lib.mkDefault false;
  platform.services.cockpit.enable = lib.mkDefault false;
}
```

创建 `profiles/server-base.nix`：

```nix
{ lib, ... }:
{
  platform.machine.class = lib.mkDefault "server";
  platform.machine.wsl.enable = lib.mkDefault false;
  platform.services.openssh.enable = lib.mkDefault true;
  platform.services.cockpit.enable = lib.mkDefault false;
}
```

创建 `profiles/generic-linux.nix`：

```nix
{ lib, ... }:
{
  platform.machine.class = lib.mkDefault "generic";
  platform.machine.wsl.enable = lib.mkDefault false;
}
```

- [ ] **步骤 3：创建 role 模块**

创建 `roles/default.nix`：

```nix
{
  development = ./development.nix;
  fullstack-development = ./fullstack-development.nix;
  ai-tooling = ./ai-tooling.nix;
  container-host = ./container-host.nix;
  remote-admin = ./remote-admin.nix;
  ai-accelerated = ./ai-accelerated.nix;
}
```

创建 `roles/development.nix`：

```nix
{ lib, ... }:
{
  platform.home.git.enable = lib.mkDefault true;
  platform.home.shell.enable = lib.mkDefault true;
  platform.home.cliTools.enable = lib.mkDefault true;
}
```

创建 `roles/fullstack-development.nix`：

```nix
{ lib, ... }:
{
  platform.development.fullstack.enable = lib.mkDefault true;
  platform.home.git.enable = lib.mkDefault true;
  platform.home.shell.enable = lib.mkDefault true;
  platform.home.cliTools.enable = lib.mkDefault true;
}
```

创建 `roles/ai-tooling.nix`：

```nix
{ lib, ... }:
{
  platform.home.opencode.enable = lib.mkDefault true;
  platform.home.shell.enable = lib.mkDefault true;
}
```

创建 `roles/container-host.nix`：

```nix
{ lib, ... }:
{
  platform.containers.podman.enable = lib.mkDefault true;
}
```

创建 `roles/remote-admin.nix`：

```nix
{ config, lib, ... }:
{
  platform.services.openssh.enable = lib.mkDefault true;
  platform.services.cockpit.enable = lib.mkDefault (!config.platform.machine.wsl.enable);
}
```

创建 `roles/ai-accelerated.nix`：

```nix
{ lib, ... }:
{
  platform.machine.nvidia.enable = lib.mkDefault true;
}
```

- [ ] **步骤 4：创建平台模块映射**

创建 `lib/platform/modules.nix`：

```nix
{
  profiles = import ../../profiles;
  roles = import ../../roles;
}
```

- [ ] **步骤 5：创建平台 lib 骨架**

创建 `lib/platform/default.nix`：

```nix
{
  inputs,
  self,
}:
let
  lib = inputs.nixpkgs.lib;
  moduleSets = import ./modules.nix;

  resolveNamedModules =
    kind: available: names:
    map (
      name:
      if builtins.hasAttr name available then
        available.${name}
      else
        throw "Unknown ${kind} '${name}'. Available ${kind}s: ${lib.concatStringsSep ", " (builtins.attrNames available)}"
    ) names;

  requireAttrs =
    attrPath: value: names:
    builtins.map (
      name:
      if builtins.hasAttr name value then
        null
      else
        throw "mkHost requires ${attrPath}.${name}"
    ) names;

  compactNulls = attrs: lib.filterAttrs (_: value: value != null) attrs;

  normalizeHost = host:
    let
      _requiredTop = requireAttrs "host" host [
        "hostname"
        "user"
      ];
      _requiredUser = requireAttrs "host.user" host.user [
        "name"
        "fullName"
        "email"
        "sshPublicKey"
      ];
    in
    host
    // {
      system = host.system or "x86_64-linux";
      profiles = host.profiles or [ "generic-linux" ];
      roles = host.roles or [ ];
      machine = host.machine or { };
      networking = host.networking or { };
      services = host.services or { };
      home = host.home or { };
      secrets = host.secrets or { };
      extraModules = host.extraModules or [ ];
      hardwareModules = host.hardwareModules or [ ];
    };

  platformHostModule = host: { lib, ... }: {
    networking.hostName = host.hostname;
    platform = lib.mkMerge [
      {
        profiles = host.profiles;
        roles = host.roles;
        user = host.user;
      }
      (compactNulls {
        stateVersion = host.stateVersion or null;
        machine = host.machine or null;
        nix = host.nix or null;
        networking = host.networking or null;
        services = host.services or null;
        containers = host.containers or null;
        home = host.home or null;
        development = host.development or null;
        packages = host.packages or null;
      })
    ];
  };

  sopsModule = host: { lib, ... }:
    let
      sops = host.secrets.sops or { enable = false; };
    in
    lib.mkIf (sops.enable or false) {
      sops.defaultSopsFile = sops.defaultFile;
      sops.age.keyFile = sops.ageKeyFile;
      sops.secrets = sops.secrets or { };
      sops.templates = sops.templates or { };
    };

  homeManagerBridgeModule = host: { config, ... }: {
    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.extraSpecialArgs = {
      inherit inputs;
      hostname = host.hostname;
    };
    home-manager.users.${config.platform.user.name} = {
      imports = [ self.homeModules.default ];
      platform = config.platform;
    };
  };
in
rec {
  inherit normalizeHost;

  profileNames = builtins.attrNames moduleSets.profiles;
  roleNames = builtins.attrNames moduleSets.roles;

  resolveProfiles = names: resolveNamedModules "profile" moduleSets.profiles names;
  resolveRoles = names: resolveNamedModules "role" moduleSets.roles names;

  mkHost = hostInput:
    let
      host = normalizeHost hostInput;
      profileModules = resolveProfiles host.profiles;
      roleModules = resolveRoles host.roles;
      wslModules = lib.optionals (host.machine.wsl.enable or false) [ inputs.nixos-wsl.nixosModules.default ];
    in
    inputs.nixpkgs.lib.nixosSystem {
      system = host.system;
      specialArgs = {
        inherit inputs;
        hostname = host.hostname;
      };
      modules =
        [
          { nixpkgs.overlays = [ self.overlays.default ]; }
          { nixpkgs.config.allowUnfree = true; }
          self.nixosModules.platform
          inputs.sops-nix.nixosModules.sops
          inputs.home-manager.nixosModules.home-manager
          (platformHostModule host)
          (sopsModule host)
        ]
        ++ wslModules
        ++ profileModules
        ++ roleModules
        ++ host.hardwareModules
        ++ host.extraModules
        ++ [ (homeManagerBridgeModule host) ];
    };

  mkSystem = mkHost;

  mkHome = args:
    inputs.home-manager.lib.homeManagerConfiguration args;
}
```

- [ ] **步骤 6：更新 lib 和 flake 导出平台 lib**

修改 `lib/default.nix`：

```nix
{
  inputs,
  self,
}:
let
  platform = import ./platform { inherit inputs self; };
in
platform
// {
  inherit platform;
}
```

修改 `flake.nix` 的 `outputs` 参数和 `lib` 导出：

```nix
  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      defaultOverlay = final: prev: {
        v2ray-rules-dat = final.callPackage ./pkgs/v2ray-rules-dat { };
        opencode = final.callPackage ./pkgs/opencode { };
      };
      platformLib = import ./lib { inherit inputs self; };
    in
    {
      overlays.default = defaultOverlay;
      lib = platformLib;
    };
```

- [ ] **步骤 7：验证 profile/role 名称导出**

运行：`nix eval .#lib.platform.profileNames --json`

预期：输出包含 `"wsl-base"`、`"workstation-base"`、`"server-base"`、`"generic-linux"`。

运行：`nix eval .#lib.platform.roleNames --json`

预期：输出包含 `"development"`、`"fullstack-development"`、`"ai-tooling"`、`"container-host"`、`"remote-admin"`、`"ai-accelerated"`。

---

### 任务 3：迁移 NixOS 模块到 `platform.*`

**文件：**
- 新增：`modules/nixos/core/base.nix`
- 新增：`modules/nixos/core/assertions.nix`
- 新增：`modules/nixos/boot/grub.nix`
- 新增：`modules/nixos/users/default.nix`
- 新增：`modules/nixos/networking/base.nix`
- 新增：`modules/nixos/networking/transparent-proxy.nix`
- 修改：`modules/nixos/services/cockpit.nix`
- 修改：`modules/nixos/services/openssh.nix`
- 修改：`modules/nixos/hardware/nvidia.nix`
- 新增：`modules/nixos/containers/podman.nix`
- 新增：`modules/nixos/packages/system.nix`
- 修改：`modules/nixos/default.nix`

- [ ] **步骤 1：写失败验证**

运行：`nix eval .#nixosModules.platform.imports --apply builtins.length`

预期：失败，因为 `nixosModules.platform` 还没有完成导出。

- [ ] **步骤 2：新增核心模块**

创建 `modules/nixos/core/base.nix`：

```nix
{
  config,
  pkgs,
  ...
}:
let
  cfg = config.platform;
  emulateArchs = builtins.filter (system: system != pkgs.stdenv.hostPlatform.system) [
    "aarch64-linux"
    "x86_64-linux"
  ];
in
{
  boot.binfmt.emulatedSystems = emulateArchs;
  boot.kernelPackages = pkgs.linuxPackages;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    max-jobs = cfg.nix.maxJobs;
    substituters = [
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://cache.nixos.org"
      "https://devenv.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
    ];
    trusted-users = [
      "root"
      cfg.user.name
    ];
  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc.lib
    zlib
    glib
    openssl
    curl
    icu
    libxml2
    libuuid
    ncurses
  ];

  programs.zsh.enable = true;
  system.stateVersion = cfg.stateVersion;
}
```

创建 `modules/nixos/core/assertions.nix`：

```nix
{ config, lib, ... }:
let
  cfg = config.platform;
in
{
  assertions = [
    {
      assertion = cfg.machine.wsl.enable || cfg.machine.boot.mode != "uefi" || cfg.machine.boot.grubDevice == null;
      message = "使用 UEFI 启动时不要设置 platform.machine.boot.grubDevice；GRUB 会以 EFI 方式安装并使用 device = \"nodev\"。";
    }
    {
      assertion = cfg.machine.wsl.enable || cfg.machine.boot.mode != "bios" || cfg.machine.boot.grubDevice != null;
      message = "使用传统 BIOS 启动时必须设置 platform.machine.boot.grubDevice，例如 /dev/disk/by-id/...。";
    }
    {
      assertion = !cfg.networking.transparentProxy.enable || cfg.networking.transparentProxy.configFile != null;
      message = "启用本机透明代理时必须设置 platform.networking.transparentProxy.configFile。";
    }
    {
      assertion = cfg.networking.transparentProxy.backend == "dae";
      message = "platform.networking.transparentProxy.backend 第一版只支持 dae。";
    }
    {
      assertion = !(cfg.machine.wsl.enable && cfg.machine.nvidia.enable);
      message = "WSL profile 不能启用 platform.machine.nvidia.enable；GPU/CUDA 能力只能用于非 WSL Linux 主机。";
    }
  ];
}
```

- [ ] **步骤 3：新增 boot、networking、users 模块**

创建 `modules/nixos/boot/grub.nix`：

```nix
{ config, lib, ... }:
let
  cfg = config.platform;
  isUEFI = cfg.machine.boot.mode == "uefi";
  isBIOS = cfg.machine.boot.mode == "bios";
in
{
  boot.loader.grub = lib.mkMerge [
    { enable = !cfg.machine.wsl.enable; }
    (lib.mkIf (!cfg.machine.wsl.enable) {
      configurationLimit = 6;
    })
    (lib.mkIf (!cfg.machine.wsl.enable && isUEFI) {
      efiSupport = true;
      device = "nodev";
    })
    (lib.mkIf (!cfg.machine.wsl.enable && isBIOS && cfg.machine.boot.grubDevice != null) {
      devices = lib.mkForce [ cfg.machine.boot.grubDevice ];
    })
  ];

  boot.loader.efi.canTouchEfiVariables = !cfg.machine.wsl.enable && isUEFI;
}
```

创建 `modules/nixos/networking/base.nix`：

```nix
{ config, lib, ... }:
let
  cfg = config.platform;
in
{
  networking.networkmanager.enable = lib.mkDefault (!cfg.machine.wsl.enable);
  networking.hosts = cfg.networking.extraHosts;
  networking.firewall.enable = lib.mkDefault (!cfg.machine.wsl.enable);
  time.timeZone = "Asia/Shanghai";

  boot.kernel.sysctl = lib.optionalAttrs (!cfg.machine.wsl.enable) {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };
}
```

创建 `modules/nixos/users/default.nix`：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
in
{
  users.users.${cfg.user.name} = {
    isNormalUser = true;
    description = cfg.user.fullName;
    linger = true;
    extraGroups =
      [ "wheel" ]
      ++ lib.optionals (!cfg.machine.wsl.enable) [
        "networkmanager"
        "dialout"
      ]
      ++ lib.optionals cfg.containers.podman.enable [ "podman" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [ cfg.user.sshPublicKey ];
  };

  security.sudo.extraRules = [
    {
      users = [ cfg.user.name ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
```

- [ ] **步骤 4：新增 service、hardware、container、packages 模块**

修改 `modules/nixos/services/openssh.nix`：

```nix
{ config, lib, ... }:
{
  config = lib.mkIf config.platform.services.openssh.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
```

修改 `modules/nixos/services/cockpit.nix`：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
  cockpitPort = toString config.services.cockpit.port;
  cockpitHostOrigin = "https://${config.networking.hostName}:${cockpitPort}";
  cockpitExtraOrigins = lib.unique (
    lib.optional (config.networking.hostName != "" && config.networking.hostName != "localhost") cockpitHostOrigin
    ++ cfg.services.cockpit.extraOrigins
  );
in
{
  config = lib.mkIf cfg.services.cockpit.enable {
    services.cockpit = {
      enable = true;
      openFirewall = true;
      package = pkgs.cockpit;
      plugins = [
        pkgs."cockpit-files"
        pkgs."cockpit-podman"
      ];
      allowed-origins = cockpitExtraOrigins;
    };

    systemd.slices."system-cockpithttps".sliceConfig = {
      MemoryHigh = "192M";
      MemoryMax = "256M";
    };
  };
}
```

创建 `modules/nixos/networking/transparent-proxy.nix`：

```nix
{
  config,
  pkgs,
  ...
}:
let
  cfg = config.platform;
in
{
  services.dae = {
    enable = (!cfg.machine.wsl.enable) && cfg.networking.transparentProxy.enable;
    configFile = cfg.networking.transparentProxy.configFile;
    assets = [ pkgs.v2ray-rules-dat ];
  };
}
```

修改 `modules/nixos/hardware/nvidia.nix`：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.platform.machine.nvidia.enable {
    services.xserver = {
      enable = false;
      videoDrivers = [ "nvidia" ];
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.nvidia-container-toolkit.enable = true;

    hardware.nvidia = {
      open = false;
      nvidiaSettings = false;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      nvidiaPersistenced = false;
      powerManagement = {
        enable = true;
        finegrained = false;
      };
    };

    environment.systemPackages = with pkgs; [
      cudatoolkit
      linuxPackages.nvidia_x11
    ];
  };
}
```

创建 `modules/nixos/containers/podman.nix`：

```nix
{ config, lib, ... }:
{
  config = lib.mkIf config.platform.containers.podman.enable {
    virtualisation = {
      containers.enable = true;
      containers.registries.search = [ "docker.io" ];

      podman = {
        enable = true;
        dockerCompat = true;
        dockerSocket.enable = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };
  };
}
```

创建 `modules/nixos/packages/system.nix`：

```nix
{ config, pkgs, ... }:
{
  environment.systemPackages =
    (with pkgs; [
      vim
      wget
      curl
      git
      tree
      nixfmt
      nixd
      cachix
      devenv
      kmod
      usbutils
      openssl
    ])
    ++ config.platform.packages.system.extra;
}
```

- [ ] **步骤 5：切换 NixOS default 聚合**

修改 `modules/nixos/default.nix`：

```nix
{ ... }:
{
  imports = [
    ../shared/options.nix
    ./core/base.nix
    ./core/assertions.nix
    ./boot/grub.nix
    ./users
    ./networking/base.nix
    ./networking/transparent-proxy.nix
    ./services/cockpit.nix
    ./services/openssh.nix
    ./hardware/nvidia.nix
    ./containers/podman.nix
    ./packages/system.nix
  ];
}
```

- [ ] **步骤 6：验证 NixOS 平台模块可 eval**

运行：`nix eval .#nixosModules.platform.imports --apply builtins.length`

预期：输出大于 `0` 的整数。

---

### 任务 4：迁移 Home Manager 模块到 `platform.*`

**文件：**
- 新增：`modules/home/core/base.nix`
- 新增：`modules/home/git/default.nix`
- 新增：`modules/home/shell/default.nix`
- 新增：`modules/home/development/cli-tools.nix`
- 新增：`modules/home/development/packages.nix`
- 新增：`modules/home/opencode/default.nix`
- 修改：`modules/home/default.nix`

- [ ] **步骤 1：写失败验证**

运行：`nix eval .#homeModules.platform.imports --apply builtins.length`

预期：失败，因为 `homeModules.platform` 尚未导出。

- [ ] **步骤 2：新增 Home core、Git、shell 模块**

创建 `modules/home/core/base.nix`：

```nix
{ config, ... }:
let
  cfg = config.platform;
in
{
  home.username = cfg.user.name;
  home.homeDirectory = "/home/${cfg.user.name}";
  home.stateVersion = cfg.stateVersion;
}
```

创建 `modules/home/git/default.nix`：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
in
{
  config = lib.mkIf cfg.home.git.enable {
    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user = {
          name = cfg.user.fullName;
          email = cfg.user.email;
          signingKey = cfg.user.sshPublicKey;
        };
        init.defaultBranch = "main";
        gpg.format = "ssh";
        "gpg \"ssh\"".program = "${pkgs.openssh}/bin/ssh-keygen";
        commit.gpgsign = true;
      };
    };
  };
}
```

创建 `modules/home/shell/default.nix`：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
  loadSopsSecrets = lib.concatMapStringsSep "\n" (name: ''
    if [ -f "/run/secrets/${name}" ]; then
      ${pkgs.openssh}/bin/ssh-add "/run/secrets/${name}" >/dev/null 2>&1
    fi
  '') cfg.home.sshAgent.sopsSecrets;
in
{
  config = lib.mkIf cfg.home.shell.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -l";
        clean = "nix-collect-garbage -d";
      };
      initContent = lib.mkIf cfg.home.sshAgent.enable ''
        ssh-add -l >/dev/null 2>&1
        ssh_agent_state=$?

        if [ "$ssh_agent_state" -eq 2 ]; then
          eval "$(${pkgs.openssh}/bin/ssh-agent -s)" >/dev/null
          ssh_agent_state=1
        fi

        if [ "$ssh_agent_state" -eq 1 ]; then
          ${loadSopsSecrets}
        fi
      '';
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = fromTOML (builtins.readFile ../../../home/starship.toml);
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = true;
    };
  };
}
```

- [ ] **步骤 3：新增 Home development 与 OpenCode 模块**

创建 `modules/home/development/cli-tools.nix`：

```nix
{ config, lib, ... }:
{
  config = lib.mkIf config.platform.home.cliTools.enable {
    programs.eza = {
      enable = true;
      enableZshIntegration = true;
      icons = "auto";
      git = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.bat = {
      enable = true;
      config.theme = "TwoDark";
    };

    programs.lazygit.enable = true;
  };
}
```

创建 `modules/home/development/packages.nix`：

```nix
{ config, lib, pkgs, ... }:
let
  cfg = config.platform;
  basePackages = with pkgs; [
    ripgrep
    fd
    btop
    jq
    tldr
    curl
    wget
    zip
    unzip
    xz
    age
    sops
    ssh-to-age
    gh
    zellij
  ];
  fullstackPackages = with pkgs; [
    bun
    nodejs
    python3
    python3Packages.pip
    uv
    go
    rustc
    cargo
    sqlite
    postgresql
    just
    gnumake
  ];
  containerPackages = with pkgs; [
    podman-compose
    (writeShellScriptBin "docker-compose" ''
      exec ${podman-compose}/bin/podman-compose "$@"
    '')
  ];
in
{
  home.packages =
    basePackages
    ++ lib.optionals cfg.development.fullstack.enable fullstackPackages
    ++ lib.optionals cfg.containers.podman.enable containerPackages
    ++ cfg.packages.home.extra;
}
```

创建 `modules/home/opencode/default.nix`：

```nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.platform;
  opencodeConfigPath = ".config/opencode/opencode.json";
in
{
  config = lib.mkIf cfg.home.opencode.enable {
    home.file = {
      ".config/opencode/agents/".source = "${inputs.opencode-config}/agents";
      ".config/opencode/skills/".source = "${inputs.opencode-config}/skills";
      ".config/opencode/AGENTS.md".source = "${inputs.opencode-config}/AGENTS.md";
      ".config/opencode/plugins/".source = "${inputs.opencode-config}/plugins";
      ".config/opencode/tui.json".source = "${inputs.opencode-config}/tui.json";
    }
    // lib.optionalAttrs (cfg.home.opencode.configFile != null) {
      "${opencodeConfigPath}" = {
        source = config.lib.file.mkOutOfStoreSymlink cfg.home.opencode.configFile;
        force = true;
      };
    };

    programs.opencode = {
      enable = true;
      package = pkgs.opencode;
    }
    // lib.optionalAttrs (cfg.home.opencode.configFile == null) {
      settings = pkgs.lib.recursiveUpdate (builtins.fromJSON (builtins.readFile "${inputs.opencode-config}/opencode.json")) cfg.home.opencode.settings;
    };
  };
}
```

- [ ] **步骤 4：切换 Home Manager default 聚合**

修改 `modules/home/default.nix`：

```nix
{ ... }:
{
  imports = [
    ../shared/options.nix
    ./core/base.nix
    ./git
    ./shell
    ./development/cli-tools.nix
    ./development/packages.nix
    ./opencode
  ];
}
```

- [ ] **步骤 5：验证 Home 平台模块可 eval**

运行：`nix eval .#homeModules.platform.imports --apply builtins.length`

预期：输出大于 `0` 的整数。

---

### 任务 5：切换 flake 导出、formatter 和 checks

**文件：**
- 修改：`flake.nix`
- 新增：`lib/platform/checks.nix`
- 修改：`lib/platform/default.nix`

- [ ] **步骤 1：写失败验证**

运行：`nix eval .#checks.x86_64-linux.example-wsl.drvPath`

预期：失败，因为 checks 尚未生成。

- [ ] **步骤 2：补齐 `nixosModules` 和 `homeModules` 导出**

修改 `flake.nix` 输出结构：

```nix
{
  overlays.default = defaultOverlay;

  lib = platformLib;

  nixosModules = {
    default = self.nixosModules.platform;
    platform = {
      imports = [ ./modules/nixos ];
      nixpkgs.overlays = [ self.overlays.default ];
    };
    profiles = import ./profiles;
    roles = import ./roles;
  };

  homeModules = {
    default = self.homeModules.platform;
    platform = ./modules/home;
  };

  formatter = nixpkgs.lib.genAttrs [
    "x86_64-linux"
    "aarch64-linux"
  ] (system: nixpkgs.legacyPackages.${system}.nixfmt);

  checks = import ./lib/platform/checks.nix { inherit inputs self; };
}
```

- [ ] **步骤 3：创建 eval-only checks**

创建 `lib/platform/checks.nix`：

```nix
{
  inputs,
  self,
}:
let
  systems = [ "x86_64-linux" ];
  lib = inputs.nixpkgs.lib;

  mkEvalCheck = system: name: host:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
    in
    pkgs.runCommand "${name}-eval" {
      evaluatedSystem = config.config.system.build.toplevel.drvPath;
    } ''
      touch $out
    '';

  user = {
    name = "example";
    fullName = "Example User";
    email = "example@example.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
  };

  base = {
    inherit user;
    stateVersion = "25.11";
    secrets.sops.enable = false;
  };

  hosts = {
    example-wsl = base // {
      hostname = "example-wsl";
      profiles = [ "wsl-base" ];
      roles = [ ];
      machine.wsl.enable = true;
    };

    example-wsl-dev-container = base // {
      hostname = "example-wsl-dev-container";
      profiles = [ "wsl-base" ];
      roles = [
        "development"
        "fullstack-development"
        "ai-tooling"
        "container-host"
      ];
      machine.wsl.enable = true;
      home.opencode.enable = true;
    };

    example-server = base // {
      hostname = "example-server";
      profiles = [ "server-base" ];
      roles = [ "remote-admin" ];
      machine.boot.mode = "uefi";
    };

    example-server-dev-container = base // {
      hostname = "example-server-dev-container";
      profiles = [ "server-base" ];
      roles = [
        "development"
        "container-host"
      ];
      machine.boot.mode = "uefi";
    };

    example-workstation = base // {
      hostname = "example-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "development" ];
      machine.boot.mode = "uefi";
    };

    example-gpu-workstation = base // {
      hostname = "example-gpu-workstation";
      profiles = [ "workstation-base" ];
      roles = [
        "development"
        "fullstack-development"
        "ai-tooling"
        "container-host"
        "ai-accelerated"
      ];
      machine.boot.mode = "uefi";
      machine.nvidia.enable = true;
      home.opencode.enable = true;
    };
  };
in
lib.genAttrs systems (
  system:
  lib.mapAttrs' (name: host: lib.nameValuePair name (mkEvalCheck system name host)) hosts
)
```

- [ ] **步骤 4：验证 checks drvPath 可 eval**

运行：`nix eval .#checks.x86_64-linux.example-wsl.drvPath`

预期：输出 `/nix/store/...-example-wsl-eval.drv`。

运行：`nix eval .#checks.x86_64-linux.example-wsl-dev-container.drvPath`

预期：输出 `/nix/store/...-example-wsl-dev-container-eval.drv`。

运行：`nix eval .#checks.x86_64-linux.example-gpu-workstation.drvPath`

预期：输出 `/nix/store/...-example-gpu-workstation-eval.drv`，不实际构建 CUDA 依赖。

---

### 任务 6：迁移 example 为多场景私有仓库模板

**文件：**
- 修改：`example/my-host/flake.nix`
- 新增：`example/my-host/hosts/wsl-dev/default.nix`
- 新增：`example/my-host/hosts/wsl-dev/secrets.yaml`
- 新增：`example/my-host/hosts/server/default.nix`
- 新增：`example/my-host/hosts/server/hardware-configuration.nix.example`
- 新增：`example/my-host/hosts/server/secrets.yaml`
- 新增：`example/my-host/hosts/workstation/default.nix`
- 新增：`example/my-host/hosts/workstation/hardware-configuration.nix.example`
- 新增：`example/my-host/hosts/workstation/secrets.yaml`
- 新增：`example/my-host/templates/opencode-config.template.json`
- 删除：`example/my-host/hosts/my-host/default.nix`

- [ ] **步骤 1：写失败验证**

运行：`nix eval ./example/my-host#nixosConfigurations.wsl-dev.config.networking.hostName`

预期：失败，因为新的 example host 还不存在。

- [ ] **步骤 2：重写 example flake**

将 `example/my-host/flake.nix` 替换为：

```nix
{
  description = "My NixOS Private Configuration";

  inputs.nixos-config-public.url = "github:Chikage0o0/nixos-config";

  outputs = { nixos-config-public, ... }:
  let
    public = nixos-config-public;
    commonUser = {
      name = "your_username";
      fullName = "Your Name";
      email = "your@email.com";
      sshPublicKey = "ssh-ed25519 AAAA... user@host";
    };
  in
  {
    nixosConfigurations = {
      wsl-dev = public.lib.mkHost {
        hostname = "wsl-dev";
        system = "x86_64-linux";
        user = commonUser;
        profiles = [ "wsl-base" ];
        roles = [
          "development"
          "fullstack-development"
          "ai-tooling"
          "container-host"
        ];
        machine.wsl.enable = true;
        home.opencode.enable = true;
        secrets.sops = {
          enable = true;
          defaultFile = ./hosts/wsl-dev/secrets.yaml;
          ageKeyFile = "/home/${commonUser.name}/.config/sops/age/keys.txt";
          secrets = {
            "user/hashedPassword".neededForUsers = true;
            "opencode/apiKey" = { };
            "ssh_private_key" = {
              owner = commonUser.name;
              mode = "0400";
            };
          };
        };
        extraModules = [ ./hosts/wsl-dev ];
      };

      server = public.lib.mkHost {
        hostname = "server";
        system = "x86_64-linux";
        user = commonUser;
        profiles = [ "server-base" ];
        roles = [
          "remote-admin"
          "container-host"
        ];
        machine.boot.mode = "uefi";
        secrets.sops = {
          enable = true;
          defaultFile = ./hosts/server/secrets.yaml;
          ageKeyFile = "/home/${commonUser.name}/.config/sops/age/keys.txt";
          secrets."user/hashedPassword".neededForUsers = true;
        };
        hardwareModules = [ ./hosts/server/hardware-configuration.nix ];
        extraModules = [ ./hosts/server ];
      };

      workstation = public.lib.mkHost {
        hostname = "workstation";
        system = "x86_64-linux";
        user = commonUser;
        profiles = [ "workstation-base" ];
        roles = [
          "development"
          "fullstack-development"
          "ai-tooling"
          "container-host"
          "ai-accelerated"
        ];
        machine = {
          boot.mode = "uefi";
          nvidia.enable = true;
        };
        home.opencode.enable = true;
        secrets.sops = {
          enable = true;
          defaultFile = ./hosts/workstation/secrets.yaml;
          ageKeyFile = "/home/${commonUser.name}/.config/sops/age/keys.txt";
          secrets = {
            "user/hashedPassword".neededForUsers = true;
            "opencode/apiKey" = { };
            "ssh_private_key" = {
              owner = commonUser.name;
              mode = "0400";
            };
          };
        };
        hardwareModules = [ ./hosts/workstation/hardware-configuration.nix ];
        extraModules = [ ./hosts/workstation ];
      };
    };
  };
}
```

- [ ] **步骤 3：创建 WSL host 模块**

创建 `example/my-host/hosts/wsl-dev/default.nix`：

```nix
{ config, lib, ... }:
{
  wsl = {
    enable = true;
    defaultUser = config.platform.user.name;
    interop.register = true;
  };

  users.users.${config.platform.user.name}.hashedPasswordFile =
    lib.mkIf (config ? sops) config.sops.secrets."user/hashedPassword".path;
}
```

创建 `example/my-host/hosts/wsl-dev/secrets.yaml`：

```yaml
user:
  hashedPassword: "$y$j9T$example"
opencode:
  apiKey: "replace-me"
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  replace-me
  -----END OPENSSH PRIVATE KEY-----
```

- [ ] **步骤 4：创建 server 和 workstation host 模块**

创建 `example/my-host/hosts/server/default.nix`：

```nix
{ config, lib, ... }:
{
  users.users.${config.platform.user.name}.hashedPasswordFile =
    lib.mkIf (config ? sops) config.sops.secrets."user/hashedPassword".path;
}
```

创建 `example/my-host/hosts/server/hardware-configuration.nix.example`：

```nix
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];
  fileSystems."/".device = "/dev/disk/by-label/nixos";
}
```

创建 `example/my-host/hosts/server/secrets.yaml`：

```yaml
user:
  hashedPassword: "$y$j9T$example"
```

创建 `example/my-host/hosts/workstation/default.nix`：

```nix
{ config, lib, ... }:
{
  users.users.${config.platform.user.name}.hashedPasswordFile =
    lib.mkIf (config ? sops) config.sops.secrets."user/hashedPassword".path;

  sops.templates."opencode-config.json" = {
    owner = config.platform.user.name;
    mode = "0400";
    content = builtins.toJSON {
      provider = {
        openai.options.apiKey = config.sops.placeholder."opencode/apiKey";
      };
    };
  };

  platform.home.opencode.configFile = config.sops.templates."opencode-config.json".path;
  platform.home.sshAgent.sopsSecrets = [ "ssh_private_key" ];
}
```

创建 `example/my-host/hosts/workstation/hardware-configuration.nix.example`：

```nix
{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  fileSystems."/".device = "/dev/disk/by-label/nixos";
}
```

创建 `example/my-host/hosts/workstation/secrets.yaml`：

```yaml
user:
  hashedPassword: "$y$j9T$example"
opencode:
  apiKey: "replace-me"
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  replace-me
  -----END OPENSSH PRIVATE KEY-----
```

创建 `example/my-host/templates/opencode-config.template.json`：

```json
{
  "provider": {
    "openai": {
      "options": {
        "apiKey": "__OPENCODE_API_KEY__"
      }
    }
  }
}
```

- [ ] **步骤 5：验证 example host 可 eval**

运行：`nix eval ./example/my-host#nixosConfigurations.wsl-dev.config.networking.hostName`

预期：输出 `"wsl-dev"`。

运行：`nix eval ./example/my-host#nixosConfigurations.server.config.networking.hostName`

预期：输出 `"server"`。如果缺少 `hardware-configuration.nix`，先在 example 中复制 `.example` 文件作为 eval 用文件，再在 README 中说明真实私有仓库必须替换为 `/etc/nixos/hardware-configuration.nix`。

---

### 任务 7：删除旧入口并更新文档

**文件：**
- 删除：旧 `myConfig` options 和旧平铺模块文件
- 修改：`README.md`
- 修改：`docs/migration-from-root-nix.md`
- 新增：`docs/migration-from-myConfig.md`

- [ ] **步骤 1：写失败验证**

运行：`grep -R "myConfig" README.md docs/migration-from-root-nix.md example/my-host || true`

预期：当前会输出旧接口引用，说明文档还未迁移。

- [ ] **步骤 2：删除旧入口文件**

删除这些文件：

```text
lib/options.nix
lib/home-options.nix
modules/nixos/base.nix
modules/nixos/network.nix
modules/nixos/users.nix
modules/nixos/virtualisation.nix
modules/nixos/packages.nix
modules/home/base.nix
modules/home/git.nix
modules/home/shell.nix
modules/home/cli-tools.nix
modules/home/opencode.nix
modules/home/packages.nix
```

- [ ] **步骤 3：重写 README 平台入口**

README 必须包含这段新 API 示例：

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

README 必须明确这三条规则：

```markdown
- `profile` 只描述机器形态：`wsl-base`、`workstation-base`、`server-base`、`generic-linux`。
- OpenCode、全栈开发工具和 Podman 由 role/feature 组合，不绑定到某个 profile。
- dae 是本机透明代理 feature：`platform.networking.transparentProxy`，不是代理网关 role。
```

- [ ] **步骤 4：新增 `docs/migration-from-myConfig.md`**

新增迁移表，至少包含这些映射：

```markdown
# 从 myConfig 迁移到 platform.*

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
| `myConfig.isNvidia` | `platform.machine.nvidia.enable` 或 `ai-accelerated` role |
| `myConfig.enableDae` | `platform.networking.transparentProxy.enable` |
| `myConfig.daeConfigFile` | `platform.networking.transparentProxy.configFile` |
| `myConfig.enableCockpit` | `platform.services.cockpit.enable` 或 `remote-admin` role |
| `myConfig.cockpitExtraOrigins` | `platform.services.cockpit.extraOrigins` |
| `myConfig.extraHosts` | `platform.networking.extraHosts` |
| `myConfig.opencodeSettings` | `platform.home.opencode.settings` |
| `myConfig.opencodeConfigFile` | `platform.home.opencode.configFile` |
| `myConfig.sshSopsSecrets` | `platform.home.sshAgent.sopsSecrets` |
| `myConfig.enableSshAgent` | `platform.home.sshAgent.enable` |
```

- [ ] **步骤 5：更新 root 迁移指南**

`docs/migration-from-root-nix.md` 必须把“编辑 `myConfig`”改为“编辑 `mkHost` host 声明”，并保留首次切换命令：

```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake ".#$HOSTNAME_FINAL"
```

- [ ] **步骤 6：验证旧接口不再作为推荐路径出现**

运行：`grep -R "myConfig" README.md docs/migration-from-root-nix.md example/my-host || true`

预期：无输出。

运行：`grep -R "rtk" README.md docs example/my-host || true`

预期：无输出。

---

### 任务 8：最终格式化、flake check 与自审

**文件：**
- 修改：由格式化器调整的 Nix 文件
- 修改：必要时修正前面任务暴露出的 eval 问题

- [ ] **步骤 1：运行格式化**

运行：`nix fmt`

预期：命令退出码为 `0`。如果格式化修改了文件，保留这些格式化变更。

- [ ] **步骤 2：运行 checks drvPath eval**

运行：`nix eval .#checks.x86_64-linux.example-wsl-dev-container.drvPath`

预期：输出 `/nix/store/...-example-wsl-dev-container-eval.drv`。

运行：`nix eval .#checks.x86_64-linux.example-server-dev-container.drvPath`

预期：输出 `/nix/store/...-example-server-dev-container-eval.drv`。

运行：`nix eval .#checks.x86_64-linux.example-gpu-workstation.drvPath`

预期：输出 `/nix/store/...-example-gpu-workstation-eval.drv`。

- [ ] **步骤 3：运行完整 flake check**

运行：`nix flake check`

预期：命令退出码为 `0`。

- [ ] **步骤 4：执行需求覆盖自审**

逐项确认：

```text
platform.* 共享选项：modules/shared/options.nix
mkHost/mkSystem/mkHome：lib/platform/default.nix
profile/role 合成：lib/platform/modules.nix, profiles/, roles/
WSL + OpenCode + 全栈工具 + Podman eval：checks.x86_64-linux.example-wsl-dev-container
服务器 + 开发工具 + Podman eval：checks.x86_64-linux.example-server-dev-container
workstation-base 命名：profiles/workstation-base.nix, README, example, checks
dae 本机透明代理：modules/nixos/networking/transparent-proxy.nix, README, migration 文档
旧 myConfig 推荐路径清理：README, docs/migration-from-root-nix.md, example/my-host
```

- [ ] **步骤 5：检查工作区状态**

运行：`git status --short`

预期：只看到本次平台化重写相关文件变更。

- [ ] **步骤 6：提交或交付**

如果执行会话已获得用户明确授权提交，使用 `git-commit` skill 提交最终变更，建议提交信息：

```text
🏗️ refactor(platform): rewrite config library as composable platform
```

如果没有提交授权，停止在未提交状态，并在回复中列出验证命令与结果。

## 计划自审结果

- Spec 覆盖：计划覆盖平台 API、`platform.*` options、profile/role/feature、dae 本机透明代理、secrets、flake 导出、example、README、迁移文档和 checks。
- 占位扫描：计划不包含未完成标记或占位章节。
- 类型一致性：计划统一使用 `platform.user.*`、`platform.machine.*`、`platform.home.opencode.*`、`platform.networking.transparentProxy.*`、`workstation-base`、`ai-tooling`、`ai-accelerated`。
