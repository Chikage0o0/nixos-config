# stable 主系统与 selective unstable 应用设计

## 背景

当前仓库的 `flake.nix` 将主 `nixpkgs` 输入直接固定到 `nixpkgs-unstable`，因此：

- NixOS 系统本身默认构建在 unstable 上。
- Home Manager、`nixos-wsl`、`sops-nix` 也通过 `inputs.nixpkgs.follows = "nixpkgs"` 跟随 unstable。
- `modules/nixos/services/cockpit.nix` 当前直接使用 `pkgs.cockpit` 与同一包集里的插件。

用户已经明确本次目标是：

- 主系统改为 stable。
- 仍保留一个通用入口，让少数需要追新的应用可以显式使用 unstable。
- 第一批先让 `cockpit` 使用 unstable，以获取更新版本。

这意味着本次设计既要完成主频道切换，也要在模块层建立一个不会污染默认 `pkgs` 的 secondary package set 入口。

## 决策摘要

本设计采用以下固定决策：

- 将主 `nixpkgs` input 从 `nixos-unstable` 改为当前 `stable` 对应的稳定分支，即 `nixos-25.11`。
- 新增独立的 `nixpkgs-unstable` flake input，专门用于少数追新版应用。
- 保持默认模块参数 `pkgs` 代表 stable，不把 unstable 通过 overlay 混入 `pkgs` 命名空间。
- 在 `lib/platform/default.nix` 中构造显式的 `pkgsUnstable` 包集，并通过 `specialArgs` 传给 NixOS 模块，同时通过 `home-manager.extraSpecialArgs` 传给 Home Manager 模块。
- `cockpit` 与其插件必须来自同一个 unstable 包集，避免基础包与插件跨频道混用。
- 第一版不引入新的平台选项，也不做“若 unstable 不可用则回退 stable”的隐式兼容逻辑。

## 目标

- 让整个系统构建基线切到 stable，包括 `nixpkgs`、Home Manager 跟随的主包集、formatter 和 eval checks。
- 为 NixOS 模块和 Home Manager 模块提供统一的 `pkgsUnstable` 入口，供后续少数应用按需显式使用。
- `modules/nixos/services/cockpit.nix` 使用 unstable 的 `cockpit` 与相关插件，同时保持其它系统组件继续使用 stable。
- README 反映仓库默认频道已经从 unstable 切换为 stable，并说明 selective unstable 的使用边界。
- `nix flake check` 继续可通过，且现有 `example-server` 的 `remote-admin` 覆盖能验证 Cockpit 模块没有求值回归。

## 非目标

- 第一版不提供用户可配置的“包名列表 -> 自动从 unstable 安装”的通用平台选项。
- 第一版不把 unstable 以 `pkgs.unstable.*` 或类似方式注入默认 `pkgs`，避免模块无意识漂移到 unstable。
- 第一版不为每个应用增加独立的 `package` 选项；只有已经明确需要追新的模块才直接消费 `pkgsUnstable`。
- 第一版不处理 `home.packages` 或 `environment.systemPackages` 中所有包的频道路由；只建立通用入口，不做全局策略引擎。
- 第一版不新增新的 eval check 主机；优先复用现有 `example-server` 对 Cockpit 的覆盖。

## 任务规模判断

该任务预计至少修改以下文件：

- `flake.nix`
- `flake.lock`
- `lib/platform/default.nix`
- `modules/nixos/services/cockpit.nix`
- `README.md`

不含规格文档本身，已超过 3 个文件，属于大任务，应先落书面 spec，再进入实施计划阶段。

## 频道与输入设计

### 主频道切换

`flake.nix` 中的主输入调整为：

- `inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";`

这样以下能力将默认站到 stable：

- `mkHost` 内部使用的 `inputs.nixpkgs.lib.nixosSystem`
- `formatter = nixpkgs.legacyPackages.${system}.nixfmt-tree`
- `lib/platform/checks.nix` 中的 `inputs.nixpkgs.legacyPackages.${system}`
- `home-manager`、`nixos-wsl`、`sops-nix` 因 `follows = "nixpkgs"` 而跟随 stable

### 新增 unstable 输入

新增：

- `inputs.nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";`

第一版不让其它 inputs follow `nixpkgs-unstable`。它只作为一个显式 secondary package source 存在。

## 通用 `pkgsUnstable` 入口设计

### 为什么不用 overlay 混入默认 `pkgs`

如果把 unstable 通过 overlay 混入 `pkgs`，调用侧虽然更短，但会产生两个问题：

- 模块作者更容易在不自觉的情况下扩大 unstable 使用范围。
- 评审时不容易一眼看出某个包是否故意跨频道。

因此第一版保持“stable 是默认，unstable 必须显式拿”的边界。

### 构造方式

在 `lib/platform/default.nix` 的 `mkHost` 中，基于 `host.system` 显式导入：

- `inputs.nixpkgs-unstable`

导入约束保持与主包集尽量一致：

- `system = host.system`
- `config.allowUnfree = true`
- `overlays = [ self.overlays.default ]`

这样 `pkgsUnstable` 具备两个特性：

- upstream unstable 包可直接使用。
- 本仓库 overlay 导出的自定义包在 unstable 包集里也可见，后续若有需要可以复用同一入口。

### 传递边界

`pkgsUnstable` 需要同时传给两类模块：

- NixOS 模块：通过 `specialArgs` 暴露。
- Home Manager 模块：通过 `home-manager.extraSpecialArgs` 暴露。

这样后续如果某个用户级 GUI/CLI 也需要追新版，不需要再重新设计第二套通道接入方式。

### 约束

第一版维持以下约束：

- 默认 `pkgs` 仍然只代表 stable。
- 只有显式在函数参数中声明 `pkgsUnstable` 的模块，才能使用 unstable。
- 不提供自动回退到 stable 的逻辑；若某模块声明要用 unstable，则失败应直接暴露，而不是静默降级。

## Cockpit 模块设计

### 目标

`modules/nixos/services/cockpit.nix` 是第一批接入 `pkgsUnstable` 的消费方。它需要获取新版 Cockpit，但不能把系统其它服务一起拉到 unstable。

### 包来源约束

Cockpit 相关包必须整组来自 `pkgsUnstable`：

- `services.cockpit.package = pkgsUnstable.cockpit`
- `services.cockpit.plugins = [ pkgsUnstable."cockpit-files" pkgsUnstable."cockpit-podman" ]`

这样做的原因是 Cockpit 本体和插件在版本、前端资源与运行时接口上存在耦合。若本体来自 unstable 而插件仍来自 stable，容易形成跨频道版本错配。

### 非变更范围

以下逻辑保持不变：

- `allowed-origins` 计算逻辑
- `openFirewall = true`
- `system-cockpithttps.slice` 的内存限制

本次只改包来源，不改变服务行为。

## README 更新设计

README 需要同步以下信息：

- 顶部 NixOS badge 从 `unstable` 改为 `stable`。
- 在合适位置明确说明：仓库默认系统基线为 stable，但允许模块按需显式使用 `pkgsUnstable` 获取少数应用的新版本。
- 如果 README 中提到 Cockpit/remote-admin，可补一句其当前采用 selective unstable 策略，以避免用户误以为仓库已整体回到 unstable。

README 第一版不展开通用教程，不列举所有未来可能走 unstable 的应用；只讲清默认策略与当前已知示例。

## 验证设计

实现后执行：

```bash
nix flake check
```

验证点包括：

- `flake.nix` 与 `flake.lock` 在双输入模式下可正常求值。
- `formatter`、`checks` 和 `mkHost` 继续以 stable 为基线工作。
- `example-server` 由于启用了 `remote-admin` role，会覆盖 `platform.services.cockpit.enable = true` 的路径，因此可以验证 Cockpit 模块接入 `pkgsUnstable` 后仍能成功 eval。

第一版不额外增加独立 check 命令，因为现有 `nix flake check` 已覆盖本次最关键的主机路径。

## 验收标准

- 主 `nixpkgs` input 已从 unstable 切换到 stable，Home Manager、`nixos-wsl`、`sops-nix` 默认随之跟到 stable。
- 仓库内部存在统一的 `pkgsUnstable` 入口，并同时对 NixOS 模块和 Home Manager 模块可用。
- `modules/nixos/services/cockpit.nix` 使用 unstable 的 `cockpit`、`cockpit-files`、`cockpit-podman`，其余逻辑不变。
- 默认 `pkgs` 没有被混入 unstable 命名空间，模块仍以 stable 为默认依赖来源。
- README 与实际行为一致，不再把仓库描述为整体运行在 unstable 上。
- `nix flake check` 通过。

## 实施影响文件

本设计预计影响以下文件：

- 修改 `flake.nix`
- 修改 `flake.lock`
- 修改 `lib/platform/default.nix`
- 修改 `modules/nixos/services/cockpit.nix`
- 修改 `README.md`
