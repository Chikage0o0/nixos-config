# OpenClaw role 与用户级服务接入设计

## 背景

当前仓库已经有 `role -> platform 选项 -> modules/` 的分层结构，`roles/` 只负责表达能力组合与默认开关，真正的功能落地放在 `modules/`。仓库已经集成 OpenCode，但还没有 OpenClaw 对应的 role、Home Manager 模块或用户级服务封装。

用户已经确认本次目标不是系统级服务，也不是完全声明式托管 OpenClaw 配置，而是：

- 新增一个 `openclaw` role。
- role 默认带 OpenClaw 用户级服务。
- `~/.openclaw/openclaw.json` 继续以手动维护为主，不由 Nix 写入或覆盖。
- 尽可能拿到更新的 OpenClaw，而不是完全受当前 `flake.lock` 中 `nixpkgs` 版本滞后影响。

结合 OpenClaw 上游文档与仓库现状，第一版需要同时解决两个问题：

- 如何在本仓库风格下接入 Linux `systemd --user` 服务。
- 如何把 OpenClaw 包版本控制从 `nixpkgs` 迁移到本仓库自维护，以缩短追新路径。

## 决策摘要

本设计采用以下固定决策：

- 新增 `openclaw` role，但 role 仍保持轻量，只负责开启 `platform.home.openclaw.enable`。
- 新增 Home Manager 模块 `modules/home/openclaw/default.nix`，负责安装包、声明用户级 `systemd` 服务、注入 OpenClaw 运行环境变量。
- 第一版不使用上游 `nix-openclaw` 作为 flake input，也不直接复用其模块。
- 第一版不让 Nix 生成、管理或覆盖 `~/.openclaw/openclaw.json`。
- 第一版服务启动依赖现有配置文件，若配置文件不存在，则通过 `ConditionPathExists` 阻止服务进入失败重启循环。
- OpenClaw 程序包改为仓库内自维护：在 `pkgs/openclaw/default.nix` 中提供本地 package，并通过 overlay 暴露为 `pkgs.openclaw`。
- 本地 package 以 nixpkgs 现有 `openclaw` recipe 为基础裁剪和跟进，而不是第一版直接发明新的 npm/tarball 打包方式。

## 目标

- 用户可通过 `roles = [ "openclaw" ]` 或直接开启 `platform.home.openclaw.enable` 获得 OpenClaw 用户态能力。
- OpenClaw 作为 `systemd --user` 服务运行，符合上游推荐的 Linux 用户级 daemon 模式。
- OpenClaw 运行在 `OPENCLAW_NIX_MODE=1` 下，避免运行时自修改安装流破坏声明式环境。
- 显式设置 `OPENCLAW_STATE_DIR` 与 `OPENCLAW_CONFIG_PATH`，让运行时状态和配置保持在用户目录，而不是意外落入 Nix store。
- 手动维护 `~/.openclaw/openclaw.json` 的工作流保持成立，`home-manager switch` 不覆盖该文件。
- 仓库可通过更新本地 `pkgs/openclaw/default.nix` 中的版本与 hash，较快跟进上游 OpenClaw release。
- README 和 checks 同步更新，保证 role、选项与验证链路一致。

## 非目标

- 第一版不引入 `openclaw/nix-openclaw` flake input。
- 第一版不支持声明式 `settings` attrset 合成 `openclaw.json`。
- 第一版不支持 `configFile` 外链或 `sops.templates` 自动生成 OpenClaw 配置。
- 第一版不内建 OpenClaw provider、bot token、plugin 或 documents 的声明式配置。
- 第一版不接入系统级 `services.openclaw-gateway`。
- 第一版不为 macOS `launchd` 设计仓库级集成；当前仓库目标仍是 NixOS/Linux 主机。
- 第一版不增加自动化更新脚本；OpenClaw 版本升级先以手动 bump 为主。

## 任务规模判断

该任务预计至少修改或新增以下文件：

- `roles/default.nix`
- `roles/openclaw.nix`
- `modules/shared/options.nix`
- `modules/home/default.nix`
- `modules/home/openclaw/default.nix`
- `pkgs/openclaw/default.nix`
- `flake.nix`
- `README.md`
- `lib/platform/checks.nix`

不含规格文档本身，已超过 3 个文件，属于大任务，应先落书面 spec，再进入实施计划阶段。

## 文件与模块边界

### role 层

新增 `roles/openclaw.nix`，职责只有一项：

- 设置 `platform.home.openclaw.enable = lib.mkDefault true;`

`roles/default.nix` 增加 `openclaw = ./openclaw.nix;` 映射。

role 不负责：

- 写配置文件。
- 注入 secrets。
- 直接声明 `systemd` service。
- 关心 OpenClaw 的上游版本来源。

这样保持与 `roles/ai-tooling.nix`、`roles/ai-accelerated.nix` 一致的“薄 role”风格。

### 选项层

在 `modules/shared/options.nix` 新增 `platform.home.openclaw` 选项组：

- `enable`: `bool`，默认 `false`，控制是否启用 OpenClaw Home Manager 集成。
- `package`: `package`，默认 `pkgs.openclaw`，允许未来按主机覆盖为别的 OpenClaw 构建来源。
- `configPath`: `nullOr string`，默认 `null`。当为 `null` 时，模块自动使用 `${config.home.homeDirectory}/.openclaw/openclaw.json`。
- `stateDir`: `nullOr string`，默认 `null`。当为 `null` 时，模块自动使用 `${config.home.homeDirectory}/.openclaw`。

这里保留 `package` 覆盖点，但不引入 `settings`、`configFile` 双模式，以避免第一版出现“手动配置为主”与“声明式配置为主”并存导致的真源混乱。

### Home 模块层

新增 `modules/home/openclaw/default.nix`，由 `modules/home/default.nix` 导入。该模块是第一版 OpenClaw 接入的核心实现层，职责包括：

- 当 `platform.home.openclaw.enable = true` 时，把 `cfg.package` 安装到用户环境。
- 声明 `systemd.user.services.openclaw`。
- 计算实际使用的 `configPath` 和 `stateDir`。
- 为服务注入 OpenClaw 运行所需环境变量。
- 在配置文件不存在时阻止服务启动，避免 crash loop。

该模块不负责生成 `openclaw.json`。如果用户手动修改该文件，`home-manager switch` 不应覆盖或回滚它。

## 本地 OpenClaw package 设计

### 目标

本地包的目标不是与 nixpkgs 完全分叉，而是缩短“上游 release -> 本仓库可用”的更新时间。

### 方案

新增 `pkgs/openclaw/default.nix`，并在 `flake.nix` 的 `defaultOverlay` 中导出：

- `openclaw = final.callPackage ./pkgs/openclaw { };`

本地 `pkgs/openclaw/default.nix` 设计原则：

- 结构尽量贴近 nixpkgs 当前 `pkgs/by-name/op/openclaw/package.nix`。
- 第一版直接复用 nixpkgs 已验证的 PNPM 构建思路，包括其对 sandbox 与依赖 staging 的处理。
- 版本号默认跟到本次确认时的上游最新稳定 release，例如 `2026.4.26`。
- 后续升级主要维护三类字段：`version`、源码 hash、`pnpmDepsHash`。

### 为什么不使用 npm tarball 方案

虽然 `npm view openclaw` 可见已发布 tarball，但第一版不采用 tarball 直装，原因如下：

- nixpkgs 现成 recipe 已经处理了 OpenClaw 复杂的 PNPM workspace 构建细节。
- 上游 release 资产主要是 macOS GUI 包，不是现成的 Linux CLI 二进制分发。
- 直接基于 tarball 重新设计 runtime 布局的成本更高，也更容易偏离 nixpkgs 已经验证过的安装结构。

因此第一版的“尽可能新”策略是：保留 nixpkgs recipe 的构建方式，但把版本追踪权放回本仓库。

### 更新路径

OpenClaw 更新路径分为两层：

- 公共模块仓库更新 `pkgs/openclaw/default.nix`。
- 实际主机配置仓库如果以 flake input 形式引用本仓库，还需要更新自己的 `flake.lock` 才能拿到新的 OpenClaw 版本。

这意味着“尽可能新”不再依赖 `nixpkgs` 是否已经 bump 到最新 OpenClaw，而只依赖本仓库是否跟进上游 release。

## 用户级服务设计

### 服务名称与启动命令

第一版使用 `systemd.user.services.openclaw`，启动命令为：

```nix
${lib.getExe cfg.package} gateway
```

不调用 `openclaw onboard --install-daemon`，因为：

- 仓库已经有 Home Manager，服务应由声明式配置管理。
- `--install-daemon` 会让 OpenClaw 进入自安装或自修改路径，不符合 `OPENCLAW_NIX_MODE=1` 的目标。

### 服务环境变量

服务固定注入：

- `OPENCLAW_NIX_MODE=1`
- `OPENCLAW_STATE_DIR=<resolvedStateDir>`
- `OPENCLAW_CONFIG_PATH=<resolvedConfigPath>`

其中：

- `resolvedStateDir` 默认为 `${config.home.homeDirectory}/.openclaw`
- `resolvedConfigPath` 默认为 `${resolvedStateDir}/openclaw.json`

这样既符合上游 Nix mode 要求，也明确了配置与状态目录的唯一位置。

### 服务行为

服务单元应具备以下行为：

- `WantedBy = [ "default.target" ]`，登录后自动拉起。
- `Restart = "on-failure"`，服务意外退出时自动恢复。
- 通过 `ConditionPathExists=<resolvedConfigPath>` 阻止配置缺失时启动。

第一版不主动创建空的 `openclaw.json`，原因是：

- 空文件不一定是 OpenClaw 可接受的合法配置。
- 自动写入最小配置会把“配置真源”从手动文件隐式迁回 Nix。
- 使用 `ConditionPathExists` 可以在不覆盖用户意图的前提下避免失败重启循环。

### 首次初始化流程

首次使用 OpenClaw 的推荐流程固定为：

1. 启用 `openclaw` role 或 `platform.home.openclaw.enable = true`。
2. `home-manager switch` 后获得 OpenClaw 包与用户级 service 定义。
3. 手动执行 `openclaw onboard`，或以其他手动方式生成 `~/.openclaw/openclaw.json`。
4. 执行 `systemctl --user restart openclaw`。
5. 之后继续通过手动编辑 `~/.openclaw/openclaw.json` 或 OpenClaw 自身 CLI/UI 进行配置维护。

### 手动配置与声明式环境的边界

第一版明确规定：

- `openclaw.json` 的真源是用户目录中的运行时文件。
- Nix 只负责安装程序与声明服务，不管理配置内容。
- 如果用户通过 OpenClaw UI/CLI 修改配置，下一次 `home-manager switch` 不应覆盖这些修改。

这样可以最大程度保留 OpenClaw 原生工作流，同时避免用户误以为本仓库已经提供了完整声明式配置模型。

## README 更新设计

README 需要同步以下内容：

- `Role 列表` 新增 `openclaw`，描述为 OpenClaw 用户级网关服务。
- `platform 选项参考` 新增：
  - `platform.home.openclaw.enable`
  - `platform.home.openclaw.package`
  - `platform.home.openclaw.configPath`
  - `platform.home.openclaw.stateDir`
- 在适当位置补充首次初始化说明：role 启用后仍需先生成 `~/.openclaw/openclaw.json`，服务才会真正启动。
- 说明本仓库默认不声明式管理 OpenClaw 配置文件，避免用户误把 `home-manager switch` 当作配置写入手段。

README 第一版不需要展开完整的 OpenClaw 配置教程，只需讲清仓库边界和初始化步骤。

## Checks 设计

`lib/platform/checks.nix` 需要新增至少一个启用 OpenClaw 的 eval host，用于覆盖：

- role 能被 `mkHost` 正确解析。
- `modules/shared/options.nix` 新增选项不会引发 eval 冲突。
- Home 模块导入后，启用 OpenClaw 的主机仍可成功 eval。

建议新增一个轻量 Linux host，例如：

- `example-workstation-openclaw`

它可以基于现有 `base` mock，只启用：

- `profiles = [ "workstation-base" ]` 或 `profiles = [ "server-base" ]`
- `roles = [ "openclaw" ]`

不需要在 check 中准备真实 `openclaw.json` 文件，因为第一版服务使用 `ConditionPathExists`，该条件不会阻止 Nix eval 本身。

## 错误处理与约束

第一版的错误处理策略如下：

- 如果 `openclaw.json` 不存在，服务保持未启动，而不是持续失败重启。
- 如果用户提供了自定义 `configPath` 或 `stateDir`，模块只负责把路径传递给 OpenClaw，不负责验证 JSON 内容是否有效。
- 如果本地 `pkgs/openclaw` 构建失败，应优先修复 package recipe，而不是退回 `nixpkgs.openclaw`，以保持“尽可能新”的设计目标成立。
- 如果未来需要引入 secrets、provider config 或 plugins 的声明式管理，应作为新的独立设计任务，而不是在本任务中顺手扩展。

## 实施影响文件

本设计预计影响以下文件：

- 新增 `roles/openclaw.nix`
- 修改 `roles/default.nix`
- 修改 `modules/shared/options.nix`
- 修改 `modules/home/default.nix`
- 新增 `modules/home/openclaw/default.nix`
- 新增 `pkgs/openclaw/default.nix`
- 修改 `flake.nix`
- 修改 `README.md`
- 修改 `lib/platform/checks.nix`

第一版不修改 `example/my-host`，因为该 example 当前主要承担公开仓库模板角色，不应在没有用户真实配置文件的前提下预设 OpenClaw 初始化状态。

## 验证计划

实现完成后至少运行：

```bash
nix fmt
nix flake check
```

验证重点：

- overlay 导出的 `pkgs.openclaw` 可以被 eval。
- 启用 `openclaw` role 的示例 host 可以成功 eval。
- `modules/home/openclaw/default.nix` 生成的 `systemd.user.services.openclaw` 不依赖 Nix 生成配置文件。
- README 中 role 与选项描述和实际导出的选项一致。

如果需要额外手动确认运行时行为，可在真实主机上补做：

- `systemctl --user status openclaw`
- `openclaw --version`

但这些不是 `flake check` 的前置要求。

## 验收标准

- `roles = [ "openclaw" ]` 能通过现有 `mkHost` 机制生效。
- 启用 OpenClaw 后，用户环境中安装本仓库 overlay 提供的 `openclaw` 包，而不是被动依赖当前 lock 住的 `nixpkgs.openclaw` 版本。
- 用户级 `systemd` 服务以 `openclaw gateway` 启动，并显式设置 `OPENCLAW_NIX_MODE`、`OPENCLAW_STATE_DIR`、`OPENCLAW_CONFIG_PATH`。
- `home-manager switch` 不生成、不覆盖 `~/.openclaw/openclaw.json`。
- 缺失配置文件时，服务不会 crash loop。
- README 与 `platform.home.openclaw.*` 选项文档同步更新。
- `nix flake check` 能覆盖至少一个启用 OpenClaw 的 host eval 场景。
