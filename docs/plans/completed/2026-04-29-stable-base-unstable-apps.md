# stable 主系统与 selective unstable 应用 实施计划

> **给代理执行者：** REQUIRED SUB-SKILL: 使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务执行本计划。步骤使用复选框 `- [ ]` 语法追踪。

**目标：** 将仓库默认系统基线切到 stable，同时建立统一的 `pkgsUnstable` 入口，并让 Cockpit 显式使用 unstable 包集以追踪新版。

**架构：** `flake.nix` 改为双输入模式：主 `nixpkgs` 固定到 `nixos-25.11`，额外引入 `nixpkgs-unstable`。`lib/platform/default.nix` 在 `mkHost` 中构造显式的 `pkgsUnstable`，同时传给 NixOS 与 Home Manager 模块；`modules/nixos/services/cockpit.nix` 只把 Cockpit 本体与插件切到 `pkgsUnstable`，其余系统依赖继续留在 stable。README 同步说明“stable 默认、unstable 显式按需使用”的仓库策略。

**技术栈：** NixOS Flakes, nixpkgs stable/unstable 双输入, NixOS modules, Home Manager, `nix flake lock`, `nix flake check`

---

## 文件结构与职责

| 路径 | 职责 |
| --- | --- |
| `flake.nix` | 将主 `nixpkgs` 切到 `nixos-25.11`，新增 `nixpkgs-unstable` 输入，并保持其它依赖继续 follow 主 `nixpkgs`。 |
| `flake.lock` | 锁定 stable 主输入与新增的 unstable 次输入 revision。 |
| `lib/platform/default.nix` | 在 `mkHost` 中构造 `pkgsUnstable`，并通过 `specialArgs` 与 `home-manager.extraSpecialArgs` 传给模块。 |
| `modules/nixos/services/cockpit.nix` | 只让 Cockpit 本体与插件改用 `pkgsUnstable`，保持 origin 与 slice 限制逻辑不变。 |
| `README.md` | 将仓库默认频道描述改成 stable，并说明 `pkgsUnstable` 与 Cockpit 的 selective unstable 策略。 |

## 全局执行规则

- 每个会改代码的任务，先运行该任务的失败验证，再改代码，再运行通过验证。
- 最终收尾任务只做格式化、全量校验与差异核对，不要求先制造失败。
- 每个任务开始前运行 `git status --short`，只确认当前工作树状态，不回滚用户或其他代理的改动。
- 所有 Nix 文件改动完成后运行 `nix fmt`，确认格式化没有引入无关变更。
- 所有评估命令默认使用本地 flake：`builtins.getFlake (toString ./.)`。
- 文档与注释保持中文；命令、路径、标识符保持原样。
- 本计划不包含自动提交；只有用户明确要求时，才在全部验证通过后使用 `git-commit` skill 提交。

---

### 任务 1：切换主输入并建立 `pkgsUnstable` 透传

**文件：**
- 修改：`flake.nix`
- 修改：`lib/platform/default.nix`
- 修改：`flake.lock`

- [ ] **步骤 1：运行失败验证，确认当前 lock 还不是 stable + dual-input 结构**

运行：

```bash
test "$(nix eval --impure --raw --expr '
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  hasUnstable = builtins.hasAttr "nixpkgs-unstable" lock.nodes;
  nixpkgsRef = lock.nodes.nixpkgs.original.ref or "";
in
  if hasUnstable && nixpkgsRef == "nixos-25.11" then "true" else "false"
')" = "true"
```

预期：FAIL，因为当前 `flake.lock` 里还没有 `nixpkgs-unstable` 节点，且 `nixpkgs` 仍锁在 unstable 分支。

- [ ] **步骤 2：运行失败验证，确认当前模块链路还拿不到 `pkgsUnstable`**

运行：

```bash
nix eval --impure --show-trace --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  user = {
    name = "example";
    fullName = "Example User";
    email = "example@example.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
  };
  host = flake.lib.mkHost {
    hostname = "pkgs-unstable-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "server-base" ];
    roles = [ ];
    stateVersion = "25.11";
    machine.boot.mode = "uefi";
    secrets.sops.enable = false;
    extraModules = [
      ({ pkgsUnstable, config, ... }: {
        environment.etc."pkgs-unstable-probe".text = pkgsUnstable.cockpit.pname;
        home-manager.users.${config.platform.user.name} = { pkgsUnstable, ... }: {
          home.sessionVariables.PKGS_UNSTABLE_PROBE = pkgsUnstable.cockpit.pname;
        };
      })
      {
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      }
    ];
  };
in
{
  nixos = host.config.environment.etc."pkgs-unstable-probe".text;
  home = host.config.home-manager.users.${user.name}.home.sessionVariables.PKGS_UNSTABLE_PROBE;
}
'
```

预期：FAIL，错误包含 `attribute 'pkgsUnstable' missing` 或等价的缺少模块参数信息。

- [ ] **步骤 3：把 `flake.nix` 改成 stable 主输入 + unstable 次输入**

将 `flake.nix` 的 `inputs` 段改为：

```nix
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode-config = {
      url = "github:Chikage0o0/opencode";
      flake = false;
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
```

- [ ] **步骤 4：在 `mkHost` 中构造并透传 `pkgsUnstable`**

将 `lib/platform/default.nix` 的 `homeManagerBridgeModule` 签名从：

```nix
  homeManagerBridgeModule =
    host:
    { config, ... }:
    {
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
```

改为：

```nix
  homeManagerBridgeModule =
    host: pkgsUnstable:
    { config, ... }:
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        inherit inputs pkgsUnstable;
        hostname = host.hostname;
      };
      home-manager.users.${config.platform.user.name} = {
        imports = [ self.homeModules.default ];
        platform = config.platform;
      };
    };
```

然后将 `mkHost` 的 `let` 与 `specialArgs/modules` 段从：

```nix
    let
      host = normalizeHost hostInput;
      profileModules = resolveProfiles host.profiles;
      roleModules = resolveRoles host.roles;
      wslModules = lib.optionals (host.machine.wsl.enable or false) [
        inputs.nixos-wsl.nixosModules.default
      ];
    in
    inputs.nixpkgs.lib.nixosSystem {
      system = host.system;
      specialArgs = {
        inherit inputs;
        hostname = host.hostname;
      };
      modules = [
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
```

改为：

```nix
    let
      host = normalizeHost hostInput;
      profileModules = resolveProfiles host.profiles;
      roleModules = resolveRoles host.roles;
      pkgsUnstable = import inputs.nixpkgs-unstable {
        system = host.system;
        config.allowUnfree = true;
        overlays = [ self.overlays.default ];
      };
      wslModules = lib.optionals (host.machine.wsl.enable or false) [
        inputs.nixos-wsl.nixosModules.default
      ];
    in
    inputs.nixpkgs.lib.nixosSystem {
      system = host.system;
      specialArgs = {
        inherit inputs pkgsUnstable;
        hostname = host.hostname;
      };
      modules = [
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
      ++ [ (homeManagerBridgeModule host pkgsUnstable) ];
    };
```

- [ ] **步骤 5：刷新 `flake.lock`**

运行：

```bash
nix flake lock --update-input nixpkgs --update-input nixpkgs-unstable
```

预期：PASS，`flake.lock` 新增 `nixpkgs-unstable` 节点，并把 `nixpkgs` 更新到 `nixos-25.11`。

- [ ] **步骤 6：格式化 Nix 文件**

运行：

```bash
nix fmt
```

预期：PASS，`flake.nix` 与 `lib/platform/default.nix` 仅出现格式化后的目标变更。

- [ ] **步骤 7：运行通过验证，确认 lock 已切到 stable + dual-input**

运行：

```bash
nix eval --impure --json --expr '
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
in {
  nixpkgsRef = lock.nodes.nixpkgs.original.ref or "";
  unstableRef = lock.nodes."nixpkgs-unstable".original.ref or "";
}
'
```

预期：PASS，输出：

```json
{"nixpkgsRef":"nixos-25.11","unstableRef":"nixos-unstable"}
```

- [ ] **步骤 8：运行通过验证，确认 NixOS 与 Home Manager 模块都能显式消费 `pkgsUnstable`**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  user = {
    name = "example";
    fullName = "Example User";
    email = "example@example.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
  };
  host = flake.lib.mkHost {
    hostname = "pkgs-unstable-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "server-base" ];
    roles = [ ];
    stateVersion = "25.11";
    machine.boot.mode = "uefi";
    secrets.sops.enable = false;
    extraModules = [
      ({ pkgsUnstable, config, ... }: {
        environment.etc."pkgs-unstable-probe".text = pkgsUnstable.cockpit.pname;
        home-manager.users.${config.platform.user.name} = { pkgsUnstable, ... }: {
          home.sessionVariables.PKGS_UNSTABLE_PROBE = pkgsUnstable.cockpit.pname;
        };
      })
      {
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      }
    ];
  };
in
{
  nixos = host.config.environment.etc."pkgs-unstable-probe".text;
  home = host.config.home-manager.users.${user.name}.home.sessionVariables.PKGS_UNSTABLE_PROBE;
}
'
```

预期：PASS，输出：

```json
{"home":"cockpit","nixos":"cockpit"}
```

---

### 任务 2：让 Cockpit 整组显式使用 `pkgsUnstable`

**文件：**
- 修改：`modules/nixos/services/cockpit.nix`

- [ ] **步骤 1：运行失败验证，确认模块当前仍然读取 stable 包集参数**

运行：

```bash
test "$(nix eval --impure --raw --expr '
let
  flake = builtins.getFlake (toString ./.);
  lib = (import flake.inputs.nixpkgs { system = "x86_64-linux"; }).lib;
  mkPkg = name: { outPath = "/${name}"; };
  result = import ./modules/nixos/services/cockpit.nix {
    inherit lib;
    config = {
      platform.services.cockpit = {
        enable = true;
        extraOrigins = [ ];
      };
      networking.hostName = "example";
      services.cockpit.port = 9090;
    };
    pkgs = {
      cockpit = mkPkg "stable-cockpit";
      "cockpit-files" = mkPkg "stable-files";
      "cockpit-podman" = mkPkg "stable-podman";
    };
    pkgsUnstable = {
      cockpit = mkPkg "unstable-cockpit";
      "cockpit-files" = mkPkg "unstable-files";
      "cockpit-podman" = mkPkg "unstable-podman";
    };
  };
in
  if result.config.services.cockpit.package.outPath == "/unstable-cockpit"
    && (builtins.elemAt result.config.services.cockpit.plugins 0).outPath == "/unstable-files"
    && (builtins.elemAt result.config.services.cockpit.plugins 1).outPath == "/unstable-podman"
  then "true" else "false"
')" = "true"
```

预期：FAIL，因为当前模块还会命中 `pkgs` 中的 stable sentinel。

- [ ] **步骤 2：将 Cockpit 包来源整体切到 `pkgsUnstable`**

将 `modules/nixos/services/cockpit.nix` 从：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
```

改为：

```nix
{
  config,
  lib,
  pkgsUnstable,
  ...
}:
```

并将 `services.cockpit` 包定义从：

```nix
    services.cockpit = {
      enable = true;
      openFirewall = true;
      package = pkgs.cockpit;
      plugins = [
        pkgs."cockpit-files"
        pkgs."cockpit-podman"
      ];

      # NixOS 上游默认只允许 localhost，会让用主机名或额外域名直连 9090 的浏览器握手失败。
      allowed-origins = cockpitExtraOrigins;
    };
```

改为：

```nix
    services.cockpit = {
      enable = true;
      openFirewall = true;
      package = pkgsUnstable.cockpit;
      plugins = [
        pkgsUnstable."cockpit-files"
        pkgsUnstable."cockpit-podman"
      ];

      # NixOS 上游默认只允许 localhost，会让用主机名或额外域名直连 9090 的浏览器握手失败。
      allowed-origins = cockpitExtraOrigins;
    };
```

- [ ] **步骤 3：格式化 Nix 文件**

运行：

```bash
nix fmt
```

预期：PASS，`modules/nixos/services/cockpit.nix` 仅出现参数与包来源切换相关变更。

- [ ] **步骤 4：运行通过验证，确认模块语义已改为读取 `pkgsUnstable`**

运行与步骤 1 相同的命令。

预期：PASS。

- [ ] **步骤 5：运行通过验证，确认真实 `mkHost` 路径下的 Cockpit 模块仍可求值**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  user = {
    name = "example";
    fullName = "Example User";
    email = "example@example.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
  };
  host = flake.lib.mkHost {
    hostname = "cockpit-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "server-base" ];
    roles = [ "remote-admin" ];
    stateVersion = "25.11";
    machine.boot.mode = "uefi";
    secrets.sops.enable = false;
    extraModules = [
      {
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      }
    ];
  };
in
{
  packageName = host.config.services.cockpit.package.pname;
  pluginCount = builtins.length host.config.services.cockpit.plugins;
  origins = host.config.services.cockpit.allowed-origins;
}
'
```

预期：PASS，输出：

```json
{"origins":["https://cockpit-probe:9090"],"packageName":"cockpit","pluginCount":2}
```

---

### 任务 3：更新 README 的 stable 默认与 selective unstable 策略说明

**文件：**
- 修改：`README.md`

- [ ] **步骤 1：运行失败验证，确认 README 还没切换到新策略文案**

运行：

```bash
test "$(rg -c 'NixOS-stable|pkgsUnstable' README.md)" -ge 2
```

预期：FAIL，因为当前 README 只有 `NixOS-unstable` badge，且没有 `pkgsUnstable` 文案。

- [ ] **步骤 2：把顶部 badge、简介与 `remote-admin` 描述改成新策略**

将 README 顶部与简介改为：

```md
# NixOS Config Library

[![NixOS](https://img.shields.io/badge/NixOS-stable-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![CUDA](https://img.shields.io/badge/CUDA-12.x-green.svg?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

基于 **NixOS Flakes** 的可复用模块库，为 **KDE Plasma 日常工作站**、**AI 研发**、**CUDA 加速**和**全栈开发**场景提供开箱即用的配置。

仓库默认以当前 stable `nixpkgs` 作为系统基线；对确实需要追新的少数应用，模块可显式使用 `pkgsUnstable`。当前 `remote-admin` 中的 Cockpit 就采用这种 selective unstable 策略，以便在不牵动整套系统频道的前提下追踪新版。
```

再将 `Role 列表` 中的 `remote-admin` 行改为：

```md
| `remote-admin`          | Cockpit 远程管理面板（Cockpit 走 selective unstable 以便追新） |
```

- [ ] **步骤 3：运行通过验证，确认 README 已包含 stable 与 `pkgsUnstable` 说明**

运行：

```bash
rg -n 'NixOS-stable|pkgsUnstable|selective unstable' README.md
```

预期：PASS，至少命中以下内容片段：

```text
[![NixOS](https://img.shields.io/badge/NixOS-stable-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
仓库默认以当前 stable `nixpkgs` 作为系统基线；对确实需要追新的少数应用，模块可显式使用 `pkgsUnstable`。
| `remote-admin`          | Cockpit 远程管理面板（Cockpit 走 selective unstable 以便追新） |
```

---

### 任务 4：执行最终格式化与全量验证

**文件：**
- 修改：`flake.nix`
- 修改：`flake.lock`
- 修改：`lib/platform/default.nix`
- 修改：`modules/nixos/services/cockpit.nix`
- 修改：`README.md`

- [ ] **步骤 1：查看最终工作树，确认没有意外文件被纳入本次变更**

运行：

```bash
git status --short
```

预期：PASS，只看到本计划涉及的目标文件，以及工作树中原本就存在但与本任务无关的改动；不要回滚非本任务改动。

- [ ] **步骤 2：运行仓库格式化**

运行：

```bash
nix fmt
```

预期：PASS，仓库中的 Nix 文件格式统一，且不会引入额外逻辑改动。

- [ ] **步骤 3：运行全量 flake 校验**

运行：

```bash
nix flake check
```

预期：PASS，现有 `checks.x86_64-linux.example-server` 会覆盖 `remote-admin -> cockpit` 的 eval 链路，确保 stable 主输入、`pkgsUnstable` 透传和 Cockpit 模块切换没有回归。

- [ ] **步骤 4：核对最终差异范围**

运行：

```bash
git diff --stat -- flake.nix flake.lock lib/platform/default.nix modules/nixos/services/cockpit.nix README.md docs/specs/active/2026-04-29-stable-base-unstable-apps-design.md docs/plans/active/2026-04-29-stable-base-unstable-apps.md
```

预期：PASS，只出现本任务设计文档、计划文档和 5 个实现文件的差异统计。
