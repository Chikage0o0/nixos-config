# OpenClaw role 与用户级服务接入 实施计划

> **给代理执行者：** REQUIRED SUB-SKILL: 使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务执行本计划。步骤使用复选框 `- [ ]` 语法追踪。

**目标：** 为仓库新增 `openclaw` role、可追新本地包、Home Manager 用户级 `systemd` 服务和对应文档/checks，同时保持 `~/.openclaw/openclaw.json` 继续由用户手动维护。

**架构：** 保持现有 `role -> platform 选项 -> modules/` 分层：`roles/openclaw.nix` 只打开 `platform.home.openclaw.enable`；`modules/shared/options.nix` 暴露 `platform.home.openclaw.*`；`modules/home/openclaw/default.nix` 负责安装包和声明 `systemd --user` 服务；`pkgs/openclaw/default.nix` 基于 nixpkgs recipe 自维护版本以缩短追新路径。服务只注入 `OPENCLAW_NIX_MODE`、`OPENCLAW_STATE_DIR`、`OPENCLAW_CONFIG_PATH`，不生成也不覆盖 `openclaw.json`。

**技术栈：** NixOS Flakes, Home Manager, Nix modules, `systemd --user`, nixpkgs `fetchFromGitHub` + `fetchPnpmDeps`, `pnpm_10`, `nodejs_22`

---

## 文件结构与职责

| 路径 | 职责 |
| --- | --- |
| `roles/openclaw.nix` | 薄 role，只负责 `platform.home.openclaw.enable = lib.mkDefault true;`。 |
| `roles/default.nix` | 暴露 `openclaw` role 名称到 `resolveRoles`。 |
| `modules/shared/options.nix` | 新增 `platform.home.openclaw.{enable,package,configPath,stateDir}` 选项，并让 `package` 默认指向 `pkgs.openclaw`。 |
| `pkgs/openclaw/default.nix` | 本仓库自维护的 OpenClaw 包，版本固定到 `2026.4.26`，构建方式贴近 nixpkgs recipe。 |
| `flake.nix` | 在 `defaultOverlay` 中导出 `openclaw` 包。 |
| `modules/home/openclaw/default.nix` | 安装 `cfg.package`，声明 `systemd.user.services.openclaw`，并解析默认 `stateDir/configPath`。 |
| `modules/home/default.nix` | 导入新的 `./openclaw` Home 模块。 |
| `lib/platform/checks.nix` | 新增启用 `openclaw` role 的 eval-only host，覆盖 role 解析、选项求值和 Home 模块导入链路。 |
| `README.md` | 更新 Role 列表、`platform.home.openclaw.*` 选项说明、首次初始化步骤和项目结构。 |

## 全局执行规则

- 每个任务开始前运行 `git status --short`，只确认当前工作树状态，不回滚用户或其他代理的改动。
- 每个 Nix 文件改动后运行 `nix fmt`，确认格式化没有引入无关变更。
- 每个任务先执行该任务的失败验证，再改代码，再执行通过验证。
- 新增或修改的注释、文档均使用中文；Nix 标识符、命令、路径保持原样。
- 本计划不要求自动提交；只有在用户明确要求提交时，才在全部验证通过后使用 `git-commit` skill 创建提交。

---

### 任务 1：接入 `openclaw` role 与共享选项

**文件：**
- 新增：`roles/openclaw.nix`
- 修改：`roles/default.nix`
- 修改：`modules/shared/options.nix`

- [ ] **步骤 1：运行失败验证，确认当前 role 还不存在**

运行：

```bash
nix eval --impure --show-trace --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "openclaw-role-probe";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "server-base" ];
    roles = [ "openclaw" ];
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
  host.config.platform.home.openclaw.enable
'
```

预期：FAIL，错误包含 `Unknown role 'openclaw'`。

- [ ] **步骤 2：新增薄 role 文件**

新建 `roles/openclaw.nix`：

```nix
{ lib, ... }:
{
  platform.home.openclaw.enable = lib.mkDefault true;
}
```

- [ ] **步骤 3：在 role 索引中注册 `openclaw`**

将 `roles/default.nix` 改为：

```nix
{
  development = ./development.nix;
  fullstack-development = ./fullstack-development.nix;
  ai-tooling = ./ai-tooling.nix;
  openclaw = ./openclaw.nix;
  container-host = ./container-host.nix;
  remote-admin = ./remote-admin.nix;
  ai-accelerated = ./ai-accelerated.nix;
}
```

- [ ] **步骤 4：在共享 options 中新增 `platform.home.openclaw.*`**

先把 `modules/shared/options.nix` 的文件头从：

```nix
{
  lib,
  ...
}:
```

改为：

```nix
{
  lib,
  pkgs,
  ...
}:
```

然后在 `platform.home` 下、紧跟现有 `opencode` 选项块之后插入：

```nix
      openclaw = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 OpenClaw 用户级网关服务。";
        };

        package = mkOption {
          type = types.package;
          default = pkgs.openclaw;
          description = "OpenClaw 包，默认使用本仓库 overlay 导出的 pkgs.openclaw。";
        };

        configPath = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "OpenClaw 配置文件路径；为 null 时默认使用 ~/.openclaw/openclaw.json。";
        };

        stateDir = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "OpenClaw 状态目录；为 null 时默认使用 ~/.openclaw。";
        };
      };
```

- [ ] **步骤 5：运行通过验证，确认 role 默认打开 `platform.home.openclaw.enable`**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "openclaw-role-probe";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "server-base" ];
    roles = [ "openclaw" ];
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
  enable = host.config.platform.home.openclaw.enable;
  configPath = host.config.platform.home.openclaw.configPath;
  stateDir = host.config.platform.home.openclaw.stateDir;
}
'
```

预期：PASS，输出：

```json
{"configPath":null,"enable":true,"stateDir":null}
```

---

### 任务 2：提供本仓库自维护的 `pkgs.openclaw`

**文件：**
- 新增：`pkgs/openclaw/default.nix`
- 修改：`flake.nix`

- [ ] **步骤 1：运行失败验证，确认当前 overlay 仍然暴露旧版本 OpenClaw**

运行：

```bash
test "$(nix eval --raw --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = [ flake.overlays.default ];
    config.allowUnfree = true;
  };
in
  pkgs.openclaw.version
')" = "2026.4.26"
```

预期：FAIL，因为当前 overlay 还没有覆盖到 `2026.4.26`。

- [ ] **步骤 2：新增本地 OpenClaw package 文件**

新建 `pkgs/openclaw/default.nix`，先使用已确认的源码 hash 和 `lib.fakeHash` 的 `pnpmDepsHash` 起步：

```nix
{
  lib,
  stdenvNoCC,
  buildPackages,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs_22,
  makeWrapper,
  versionCheckHook,
  rolldown,
  installShellFiles,
  version ? "2026.4.26",
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "openclaw";
  version = version;

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    tag = "v${finalAttrs.version}";
    hash = "sha256-AzhcS9lkJwlGfv/boGe6KJv9xQYI+l2VdzeqCRJGEIE=";
  };

  pnpmDepsHash = lib.fakeHash;

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = finalAttrs.pnpmDepsHash;
  };

  buildInputs = [ rolldown ];

  nativeBuildInputs = [
    pnpmConfigHook
    pnpm_10
    nodejs_22
    makeWrapper
    installShellFiles
  ];

  buildPhase = ''
    runHook preBuild

    pnpm install --frozen-lockfile

    # 用 Nix 构建的 rolldown 替换 pnpm 下载产物，避免平台二进制漂移。
    rm -rf node_modules/rolldown node_modules/@rolldown/pluginutils
    mkdir -p node_modules/@rolldown node_modules/.pnpm/node_modules/@rolldown
    cp -r ${rolldown}/lib/node_modules/rolldown node_modules/rolldown
    cp -r ${rolldown}/lib/node_modules/@rolldown/pluginutils node_modules/@rolldown/pluginutils
    cp -r ${rolldown}/lib/node_modules/rolldown node_modules/.pnpm/node_modules/rolldown
    cp -r ${rolldown}/lib/node_modules/@rolldown/pluginutils node_modules/.pnpm/node_modules/@rolldown/pluginutils
    chmod -R u+w node_modules/rolldown node_modules/@rolldown/pluginutils \
      node_modules/.pnpm/node_modules/rolldown node_modules/.pnpm/node_modules/@rolldown/pluginutils

    # Nix sandbox 中没有网络；这里直接跳过 fallback npm install 路径。
    substituteInPlace scripts/stage-bundled-plugin-runtime-deps.mjs \
      --replace-fail \
        'if (installedVersion === null || !dependencyVersionSatisfied(spec, installedVersion)) {
          return null;
        }' \
        'if (installedVersion === null || !dependencyVersionSatisfied(spec, installedVersion)) {
          continue;
        }' \
      --replace-fail \
        '    if (
          stageInstalledRootRuntimeDeps({
            directDependencyPackageRoot,
            fingerprint,
            packageJson,
            pluginDir,
            pruneConfig,
            repoRoot,
          })
        ) {
          continue;
        }' \
        '    if (
          stageInstalledRootRuntimeDeps({
            directDependencyPackageRoot,
            fingerprint,
            packageJson,
            pluginDir,
            pruneConfig,
            repoRoot,
          })
        ) {
          continue;
        }
        continue; // nix: sandbox has no npm'

    pnpm build
    pnpm ui:build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    libdir=$out/lib/openclaw
    mkdir -p $libdir $out/bin

    cp --reflink=auto -r package.json dist node_modules $libdir/
    cp --reflink=auto -r assets docs skills patches extensions qa $libdir/

    rm -f $libdir/node_modules/.pnpm/node_modules/clawdbot \
      $libdir/node_modules/.pnpm/node_modules/moltbot \
      $libdir/node_modules/.pnpm/node_modules/openclaw-control-ui

    find $libdir/extensions -xtype l -delete
    find $libdir/dist/extensions -type l -lname "$NIX_BUILD_TOP/*" -delete

    makeWrapper ${lib.getExe nodejs_22} $out/bin/openclaw \
      --add-flags "$libdir/dist/index.js" \
      --set NODE_PATH "$libdir/node_modules"
    ln -s $out/bin/openclaw $out/bin/moltbot
    ln -s $out/bin/openclaw $out/bin/clawdbot

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenvNoCC.hostPlatform.emulatorAvailable buildPackages) (
    let
      emulator = stdenvNoCC.hostPlatform.emulator buildPackages;
    in
    ''
      installShellCompletion --cmd openclaw \
        --bash <(${emulator} $out/bin/openclaw completion --shell bash) \
        --fish <(${emulator} $out/bin/openclaw completion --shell fish) \
        --zsh <(${emulator} $out/bin/openclaw completion --shell zsh)
    ''
  );

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  meta = {
    description = "Self-hosted, open-source AI assistant/agent";
    longDescription = ''
      Self-hosted AI assistant/agent connected to all your apps on your Linux
      or macOS machine and controlled via your choice of chat app.

      Note: Project is in early/rapid development and uses LLMs to parse untrusted
      content while having full access to system by default.

      Parsing untrusted input with LLMs leaves them vulnerable to prompt injection.

      (Originally known as Moltbot and ClawdBot)
    '';
    homepage = "https://openclaw.ai";
    changelog = "https://github.com/openclaw/openclaw/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    mainProgram = "openclaw";
    platforms = with lib.platforms; linux ++ darwin;
    knownVulnerabilities = [
      "Project uses LLMs to parse untrusted content, making it vulnerable to prompt injection, while having full access to system by default."
    ];
  };
})
```

- [ ] **步骤 3：在 overlay 中导出本地 `openclaw` 包**

将 `flake.nix` 的 `defaultOverlay` 改为：

```nix
      defaultOverlay = final: prev: {
        v2ray-rules-dat = final.callPackage ./pkgs/v2ray-rules-dat { };
        opencode = final.callPackage ./pkgs/opencode { };
        openclaw = final.callPackage ./pkgs/openclaw { };
      };
```

- [ ] **步骤 4：运行一次构建，拿到真实 `pnpmDepsHash`**

运行：

```bash
nix build --no-link --print-out-paths --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = [ flake.overlays.default ];
    config.allowUnfree = true;
  };
in
  pkgs.openclaw
'
```

预期：第一次 FAIL，错误包含 `hash mismatch in fixed-output derivation`，并打印 `got: sha256-...`。

- [ ] **步骤 5：把上一步输出的 `got:` 值精确回填到 `pnpmDepsHash`**

把 `pkgs/openclaw/default.nix` 中这一行：

```nix
  pnpmDepsHash = lib.fakeHash;
```

替换成步骤 4 日志里 `got:` 返回的完整 SRI 值，最终这一行必须保持如下格式：

```nix
  pnpmDepsHash = "sha256-...";
```

这里不要手写、不要猜测，必须逐字使用步骤 4 打印出的完整值。

- [ ] **步骤 6：运行通过验证，确认 overlay 已切到 `2026.4.26`**

运行：

```bash
test "$(nix eval --raw --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = [ flake.overlays.default ];
    config.allowUnfree = true;
  };
in
  pkgs.openclaw.version
')" = "2026.4.26"
```

预期：PASS。

- [ ] **步骤 7：再跑一次 package 构建，确认 derivation 可完成**

运行：

```bash
nix build --no-link --print-out-paths --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  pkgs = import flake.inputs.nixpkgs {
    system = "x86_64-linux";
    overlays = [ flake.overlays.default ];
    config.allowUnfree = true;
  };
in
  pkgs.openclaw
'
```

预期：PASS，输出一个 `/nix/store/...-openclaw-2026.4.26` 路径。

---

### 任务 3：新增 Home Manager OpenClaw 模块与用户级服务

**文件：**
- 新增：`modules/home/openclaw/default.nix`
- 修改：`modules/home/default.nix`

- [ ] **步骤 1：运行失败验证，确认当前 Home Manager 侧还没有 OpenClaw 服务**

运行：

```bash
nix eval --impure --show-trace --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "openclaw-home-probe";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "server-base" ];
    roles = [ "openclaw" ];
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
  host.config.home-manager.users.example.systemd.user.services.openclaw
'
```

预期：FAIL，错误包含 `attribute 'openclaw' missing` 或等价的服务缺失信息。

- [ ] **步骤 2：新增 OpenClaw Home 模块**

新建 `modules/home/openclaw/default.nix`：

```nix
{
  config,
  lib,
  ...
}:
let
  cfg = config.platform.home.openclaw;
  resolvedStateDir =
    if cfg.stateDir != null then cfg.stateDir else "${config.home.homeDirectory}/.openclaw";
  resolvedConfigPath =
    if cfg.configPath != null then cfg.configPath else "${resolvedStateDir}/openclaw.json";
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services.openclaw = {
      Unit = {
        Description = "OpenClaw gateway";
        ConditionPathExists = resolvedConfigPath;
      };

      Service = {
        ExecStart = "${lib.getExe cfg.package} gateway";
        Restart = "on-failure";
        Environment = [
          "OPENCLAW_NIX_MODE=1"
          "OPENCLAW_STATE_DIR=${resolvedStateDir}"
          "OPENCLAW_CONFIG_PATH=${resolvedConfigPath}"
        ];
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
```

- [ ] **步骤 3：把新模块接入 Home 模块聚合入口**

将 `modules/home/default.nix` 改为：

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
    ./development/mirrors.nix
    ./opencode
    ./openclaw
    ./desktop
  ];
}
```

- [ ] **步骤 4：运行通过验证，确认 Home 包与用户级服务都已生成**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "openclaw-home-probe";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "server-base" ];
    roles = [ "openclaw" ];
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
  hm = host.config.home-manager.users.example;
  service = hm.systemd.user.services.openclaw;
in
{
  packageInstalled = builtins.elem "openclaw" (map (pkg: pkg.pname or pkg.name) hm.home.packages);
  execStartMatches = builtins.match ".*/bin/openclaw gateway" service.Service.ExecStart != null;
  restart = service.Service.Restart;
  condition = service.Unit.ConditionPathExists;
  wantedBy = service.Install.WantedBy;
  hasNixMode = builtins.elem "OPENCLAW_NIX_MODE=1" service.Service.Environment;
  hasStateDir = builtins.elem "OPENCLAW_STATE_DIR=/home/example/.openclaw" service.Service.Environment;
  hasConfigPath = builtins.elem "OPENCLAW_CONFIG_PATH=/home/example/.openclaw/openclaw.json" service.Service.Environment;
}
'
```

预期：PASS，输出：

```json
{
  "condition":"/home/example/.openclaw/openclaw.json",
  "execStartMatches":true,
  "hasConfigPath":true,
  "hasNixMode":true,
  "hasStateDir":true,
  "packageInstalled":true,
  "restart":"on-failure",
  "wantedBy":["default.target"]
}
```

- [ ] **步骤 5：运行自定义路径验证，确认 `configPath/stateDir` 覆盖生效**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "openclaw-home-custom-paths";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "server-base" ];
    roles = [ ];
    machine.boot.mode = "uefi";
    home.openclaw = {
      enable = true;
      stateDir = "/var/lib/openclaw-user";
      configPath = "/run/user/1000/openclaw.json";
    };
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
  service = host.config.home-manager.users.example.systemd.user.services.openclaw;
in
{
  condition = service.Unit.ConditionPathExists;
  hasStateDir = builtins.elem "OPENCLAW_STATE_DIR=/var/lib/openclaw-user" service.Service.Environment;
  hasConfigPath = builtins.elem "OPENCLAW_CONFIG_PATH=/run/user/1000/openclaw.json" service.Service.Environment;
}
'
```

预期：PASS，输出：

```json
{
  "condition":"/run/user/1000/openclaw.json",
  "hasConfigPath":true,
  "hasStateDir":true
}
```

---

### 任务 4：把 OpenClaw 纳入 `lib/platform/checks.nix`

**文件：**
- 修改：`lib/platform/checks.nix`

- [ ] **步骤 1：运行失败验证，确认当前 checks 里还没有 OpenClaw host**

运行：

```bash
nix eval --json .#checks.x86_64-linux.example-workstation-openclaw.drvPath
```

预期：FAIL，错误包含 `attribute 'example-workstation-openclaw' missing`。

- [ ] **步骤 2：在 checks host 集合中加入 OpenClaw 场景**

将 `lib/platform/checks.nix` 的 `hosts` attrset 中新增：

```nix
    example-workstation-openclaw = base // {
      hostname = "example-workstation-openclaw";
      profiles = [ "workstation-base" ];
      roles = [ "openclaw" ];
      machine.boot.mode = "uefi";
    };
```

把它放在现有 `example-workstation` 附近，保持 host 分类可读。

- [ ] **步骤 3：运行通过验证，确认 check derivation 已导出**

运行：

```bash
nix eval --raw .#checks.x86_64-linux.example-workstation-openclaw.drvPath
```

预期：PASS，输出一个 `/nix/store/...-example-workstation-openclaw-eval.drv` 路径。

---

### 任务 5：同步 README 中的 Role、选项、初始化步骤与项目结构

**文件：**
- 修改：`README.md`

- [ ] **步骤 1：运行失败验证，确认 README 还未记录 OpenClaw**

运行：

```bash
rg -n "openclaw|OpenClaw" README.md
```

预期：FAIL，退出码为 1。

- [ ] **步骤 2：在 Role 列表中加入 `openclaw`**

把 README 的 Role 表更新为：

```md
| Role                    | 描述                                              |
| ----------------------- | ------------------------------------------------- |
| `development`           | 基础开发工具链                                    |
| `fullstack-development` | 全栈开发工具（Go、Rust、数据库 CLI 工具；桌面启用时含 VS Code、dbgate） |
| `ai-tooling`            | OpenCode AI 助手与开发 Shell 环境                 |
| `openclaw`              | OpenClaw 用户级网关服务                           |
| `container-host`        | Podman 容器宿主                                    |
| `ai-accelerated`        | NVIDIA/CUDA 加速（配合 `machine.nvidia.enable`）  |
| `remote-admin`          | Cockpit 远程管理面板                              |
```

- [ ] **步骤 3：在 `platform 选项参考` 中加入 OpenClaw 选项**

在 `platform.home.opencode.*` 之后加入：

```md
| `platform.home.openclaw.enable`                 | bool                     | `false`     | 启用 OpenClaw 用户级网关服务         |
| `platform.home.openclaw.package`                | package                  | `pkgs.openclaw` | OpenClaw 包，默认使用仓库 overlay 导出版本 |
| `platform.home.openclaw.configPath`             | nullOr string            | `null`      | OpenClaw 配置文件路径，默认 `~/.openclaw/openclaw.json` |
| `platform.home.openclaw.stateDir`               | nullOr string            | `null`      | OpenClaw 状态目录，默认 `~/.openclaw` |
```

- [ ] **步骤 4：补充首次初始化与“手动配置为主”的边界说明**

在 README 高级用法之前增加一个简短小节：

```md
### OpenClaw 初始化

启用 `openclaw` role 或 `platform.home.openclaw.enable = true` 之后，仓库只负责安装 `openclaw` 包并声明 `systemd --user` 服务，不会生成或覆盖 `~/.openclaw/openclaw.json`。

首次使用步骤：

1. 执行 `home-manager switch`，使包和用户级 service 定义生效。
2. 手动执行 `openclaw onboard`，或以其他方式生成 `~/.openclaw/openclaw.json`。
3. 执行 `systemctl --user restart openclaw`。

如果配置文件不存在，服务会因 `ConditionPathExists` 保持未启动状态，而不是进入失败重启循环。
```

- [ ] **步骤 5：更新项目结构树，反映新增模块和包**

把 README 项目结构中的相关行更新为：

```md
│   │   ├── desktop/       # Kitty 与 mpv 桌面用户配置
│   │   ├── opencode/      # OpenCode AI 助手
│   │   └── openclaw/      # OpenClaw 用户级服务
│   └── shared/
│       └── options.nix    # platform 选项定义
├── profiles/              # 机器形态定义
├── roles/                 # 功能角色定义
└── pkgs/
    ├── opencode/          # OpenCode 自定义包
    ├── openclaw/          # OpenClaw 自维护包
    └── v2ray-rules-dat/   # GeoIP/GeoSite 规则包
```

- [ ] **步骤 6：运行通过验证，确认 README 已包含 OpenClaw 文档**

运行：

```bash
rg -n "openclaw|OpenClaw" README.md
```

预期：PASS，至少命中 Role 行、4 个 `platform.home.openclaw.*` 选项行，以及 `OpenClaw 初始化` 小节。

---

### 任务 6：格式化并执行最终验证

**文件：**
- 修改：本计划涉及的全部 Nix/Markdown 文件

- [ ] **步骤 1：运行 `nix fmt` 统一格式**

运行：

```bash
nix fmt
```

预期：PASS。

- [ ] **步骤 2：再次检查关键点，避免把 README 成功误当成实现完成**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "openclaw-final-probe";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "server-base" ];
    roles = [ "openclaw" ];
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
  hm = host.config.home-manager.users.example;
  openclawPkg = builtins.head (builtins.filter (pkg: (pkg.pname or pkg.name) == "openclaw") hm.home.packages);
in
{
  roleEnabled = host.config.platform.home.openclaw.enable;
  packageVersion = openclawPkg.version or null;
  condition = hm.systemd.user.services.openclaw.Unit.ConditionPathExists;
}
'
```

预期：PASS，并满足：

```json
{"condition":"/home/example/.openclaw/openclaw.json","packageVersion":"2026.4.26","roleEnabled":true}
```

- [ ] **步骤 3：运行完整 flake 检查**

运行：

```bash
nix flake check
```

预期：PASS，至少覆盖：

- `pkgs.openclaw` 可求值并参与相关 host 求值。
- `checks.x86_64-linux.example-workstation-openclaw` 可成功生成 derivation。
- 新增 Home Manager 模块不会破坏现有 host/checks。

- [ ] **步骤 4：记录未自动执行的运行时手动验证项**

在任务完成说明中附带以下人工验证命令，但不要把它们伪装成已执行：

```bash
openclaw --version
systemctl --user status openclaw
systemctl --user restart openclaw
```

说明：这些命令只在真实主机上验证运行态行为；计划内的自动验证以 `nix fmt` 和 `nix flake check` 为准。
