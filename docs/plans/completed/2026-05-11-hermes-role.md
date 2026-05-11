# Hermes 用户级 Role 实施计划

> **给代理执行者：** REQUIRED SUB-SKILL: 使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务执行本计划。步骤使用复选框 `- [ ]` 语法追踪。

**目标：** 新增 `hermes` role，让用户可通过 Home Manager 安装 Hermes CLI、`agent-browser`、视频下载工具、Playwright/Chromium 浏览器自动化环境、中文字体、较完整依赖集合，并获得用户级 `hermes-agent.service` gateway 服务。

**架构：** 在 `flake.nix` 中接入官方 Hermes Agent flake，并通过默认 overlay 导出本仓库打包的 `agent-browser` npm 预编译 CLI。通过 `platform.home.hermes.*` 选项暴露用户态能力，由新增 Home Manager 模块安装包、配置 Playwright/Chromium 环境变量、启用 fontconfig，并声明 `systemd --user` 服务；role 只设置默认选项，不直接实现服务逻辑。README 与 eval checks 同步更新，确保 role 可发现、可求值。

**技术栈：** Nix flakes、NixOS module system、Home Manager、systemd user services、Nous Research Hermes Agent flake、npm tarball binary packaging、Playwright、Chromium、fontconfig。

---

## 文件结构

- 修改：`flake.nix`，新增 `hermes-agent` input，跟随 `nixpkgs-unstable`。
- 修改：`flake.lock`，由 `nix flake lock --update-input hermes-agent` 或等价命令生成。
- 新增：`pkgs/agent-browser/default.nix`，从 npm tarball 打包 `agent-browser@0.27.0` 预编译 CLI。
- 修改：`flake.nix`，默认 overlay 增加 `agent-browser`。
- 修改：`modules/shared/options.nix`，新增 `platform.home.hermes` 选项树。
- 新增：`modules/home/hermes/default.nix`，实现 Hermes 包安装、`agent-browser`、视频下载、Playwright/Chromium、中文字体、默认依赖集合、用户环境变量和用户级服务。
- 修改：`modules/home/default.nix`，导入 `./hermes`。
- 新增：`roles/hermes.nix`，声明薄 role 默认值。
- 修改：`roles/default.nix`，导出 `hermes` role。
- 修改：`lib/platform/checks.nix`，给一个 example host 增加 `hermes` role 以覆盖 eval。
- 修改：`README.md`，新增 role、选项和使用说明。
- 保留：`docs/specs/active/2026-05-11-hermes-role-design.md`，作为实施依据。

---

### 任务 1：接入 Hermes flake input、agent-browser overlay 与平台选项

**文件：**
- 修改：`flake.nix:24-28`
- 修改：`flake.nix:37-40`
- 修改：`flake.lock`
- 修改：`modules/shared/options.nix:230-249`

- [ ] **步骤 1：在 `flake.nix` 增加 Hermes Agent input**

在 `inputs` 中、`sops-nix` 之后加入：

```nix
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
```

保持现有 `outputs = inputs@{ ... }:` 结构不变；`inputs` 已经通过 `specialArgs` 和 `home-manager.extraSpecialArgs` 传给 NixOS/Home Manager 模块。

- [ ] **步骤 2：在默认 overlay 导出 `agent-browser`**

修改 `flake.nix` 的 `defaultOverlay`：

```nix
      defaultOverlay = final: prev: {
        v2ray-rules-dat = final.callPackage ./pkgs/v2ray-rules-dat { };
        opencode = final.callPackage ./pkgs/opencode { };
        agent-browser = final.callPackage ./pkgs/agent-browser { };
      };
```

- [ ] **步骤 3：更新 lock file**

运行：

```bash
nix flake lock --update-input hermes-agent
```

预期：`flake.lock` 新增 `hermes-agent` 及其上游输入；命令不应修改除 lock 更新外的源文件。

- [ ] **步骤 4：在 `modules/shared/options.nix` 添加 `platform.home.hermes` 选项**

在 `platform.home.opencode` 选项块之后、`platform.development` 之前添加：

```nix
      hermes = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 Hermes Agent 用户态 CLI、依赖和用户服务。";
        };

        package = mkOption {
          type = types.nullOr types.package;
          default = null;
          description = "Hermes Agent package；为 null 时使用官方 flake 的默认包。";
        };

        extraPackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
          description = "追加安装到 Hermes 用户环境的额外包；默认依赖集合由 Hermes Home 模块固定提供。";
        };

        service = {
          enable = mkOption {
            type = types.bool;
            default = true;
            description = "是否声明用户级 hermes-agent gateway 服务。";
          };

          extraArgs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "追加传给 `hermes gateway` 的命令行参数。";
          };
        };
      };
```

- [ ] **步骤 5：运行格式化**

运行：

```bash
nix fmt
```

预期：Nix 文件格式化完成；如 formatter 需要下载，允许 Nix 正常拉取。

- [ ] **步骤 6：运行最小求值检查并确认当前失败点只来自未实现模块**

运行：

```bash
nix eval .#lib.roleNames --json
```

预期：命令成功输出当前 role 名称 JSON 数组；本任务尚未新增 role，因此输出中不需要包含 `hermes`。

---

### 任务 2：实现 Home Manager Hermes 模块

**文件：**
- 新增：`pkgs/agent-browser/default.nix`
- 新增：`modules/home/hermes/default.nix`
- 修改：`modules/home/default.nix:3-13`

- [ ] **步骤 1：创建 `pkgs/agent-browser/default.nix`**

新增文件内容：

```nix
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  nodejs_24,
}:

let
  version = "0.27.0";
  release =
    {
      x86_64-linux = "agent-browser-linux-x64";
      aarch64-linux = "agent-browser-linux-arm64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "Unsupported system for agent-browser release binary: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "agent-browser";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/agent-browser/-/agent-browser-${version}.tgz";
    hash = "sha512-mmHzVsYFVA6nshNNGJzg83aVMgKpf4h98ytY3pvtJB1Cot0ZyA2bfnkbSngGD56Azkj+GlhVH6qx9DfKOVE0yg==";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/agent-browser/bin
    cp -R package/skill-data package/skills $out/lib/agent-browser/
    install -Dm755 package/bin/${release} $out/lib/agent-browser/bin/${release}
    install -Dm755 package/bin/agent-browser.js $out/lib/agent-browser/bin/agent-browser.js

    makeWrapper ${nodejs_24}/bin/node $out/bin/agent-browser \
      --add-flags $out/lib/agent-browser/bin/agent-browser.js

    runHook postInstall
  '';

  meta = with lib; {
    description = "Browser automation CLI for AI agents";
    homepage = "https://agent-browser.dev";
    license = licenses.asl20;
    mainProgram = "agent-browser";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
```

实现意图：npm 包自带 Linux native binary，wrapper 通过 Node 选择同目录下的平台二进制；`autoPatchelfHook` 修复 `/lib64/ld-linux-x86-64.so.2` 这类 FHS 动态链接器路径。

- [ ] **步骤 2：创建 `modules/home/hermes/default.nix`**

新增文件内容：

```nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.platform.home.hermes;
  hermesPackage =
    if cfg.package != null then
      cfg.package
    else
      inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  playwrightBrowsers = pkgs.playwright-driver.browsers;
  chromiumBinary = "${pkgs.chromium}/bin/chromium";
  defaultPackages = with pkgs; [
    hermesPackage
    agent-browser
    uv
    nodejs
    pnpm
    yarn
    ripgrep
    ffmpeg
    yt-dlp
    streamlink
    aria2
    mpv
    git
    python3
    python3Packages.pip
    gcc
    gnumake
    pkg-config
    cmake
    curl
    wget
    unzip
    zip
    gnutar
    gzip
    jq
    yq-go
    fd
    tree
    playwright
    playwright-mcp
    playwrightBrowsers
    chromium
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    source-han-sans
    sarasa-gothic
    wqy_zenhei
  ];
in
{
  config = lib.mkIf cfg.enable {
    home.packages = defaultPackages ++ cfg.extraPackages;

    fonts.fontconfig.enable = true;

    home.sessionVariables = {
      PLAYWRIGHT_BROWSERS_PATH = "${playwrightBrowsers}";
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      CHROME_PATH = chromiumBinary;
      BROWSER = chromiumBinary;
    };

    systemd.user.services.hermes-agent = lib.mkIf cfg.service.enable {
      Unit = {
        Description = "Hermes Agent gateway";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = lib.escapeShellArgs (
          [
            "${hermesPackage}/bin/hermes"
            "gateway"
          ]
          ++ cfg.service.extraArgs
        );
        Restart = "on-failure";
        RestartSec = 5;
        WorkingDirectory = "%h";
        Environment = [
          "HOME=%h"
          "HERMES_HOME=%h/.hermes"
          "MESSAGING_CWD=%h"
          "PLAYWRIGHT_BROWSERS_PATH=${playwrightBrowsers}"
          "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1"
          "CHROME_PATH=${chromiumBinary}"
          "BROWSER=${chromiumBinary}"
        ];
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
```

关键约束：不要设置 `HERMES_MANAGED`；不要创建或管理 `~/.hermes/config.yaml`、`~/.hermes/.env`。默认依赖必须包含 `agent-browser`、`yt-dlp`、`playwright`、`playwright-mcp`、`playwright-driver.browsers`、`chromium` 和中文字体集合。

- [ ] **步骤 3：导入 Home 模块**

在 `modules/home/default.nix` 的 imports 中加入 `./hermes`，结果应类似：

```nix
  imports = [
    ../shared/options.nix
    ./core/base.nix
    ./git
    ./shell
    ./development/cli-tools.nix
    ./development/packages.nix
    ./development/mirrors.nix
    ./opencode
    ./hermes
    ./desktop
  ];
```

- [ ] **步骤 4：运行格式化**

运行：

```bash
nix fmt
```

预期：新增模块和 imports 格式化完成。

- [ ] **步骤 5：验证 `agent-browser` 包可求值**

运行：

```bash
nix eval --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; overlays = [ flake.overlays.default ]; }; in pkgs.agent-browser.name'
```

预期：输出 `"agent-browser-0.27.0"`。

- [ ] **步骤 6：运行 eval 确认模块可解析**

运行：

```bash
nix eval .#checks.x86_64-linux.example-wsl.drvPath
```

预期：命令成功输出一个 `.drv` 路径；此时 example host 尚未启用 Hermes，但 Home 模块导入和选项声明必须可求值。

---

### 任务 3：新增 Hermes role 并接入 eval check

**文件：**
- 新增：`roles/hermes.nix`
- 修改：`roles/default.nix:1-8`
- 修改：`lib/platform/checks.nix:55-66`

- [ ] **步骤 1：创建薄 role**

新增 `roles/hermes.nix`：

```nix
{ lib, ... }:
{
  platform.home.hermes.enable = lib.mkDefault true;
  platform.home.hermes.service.enable = lib.mkDefault true;
  platform.home.shell.enable = lib.mkDefault true;
  platform.home.git.enable = lib.mkDefault true;
}
```

- [ ] **步骤 2：导出 role**

修改 `roles/default.nix`，加入：

```nix
  hermes = ./hermes.nix;
```

完整文件应保持 attrset 风格，例如：

```nix
{
  development = ./development.nix;
  fullstack-development = ./fullstack-development.nix;
  ai-tooling = ./ai-tooling.nix;
  container-host = ./container-host.nix;
  remote-admin = ./remote-admin.nix;
  ai-accelerated = ./ai-accelerated.nix;
  hermes = ./hermes.nix;
}
```

- [ ] **步骤 3：把 Hermes role 加入 eval check 示例 host**

在 `lib/platform/checks.nix` 的 `example-wsl-dev-container.roles` 列表中追加 `"hermes"`：

```nix
      roles = [
        "development"
        "fullstack-development"
        "ai-tooling"
        "container-host"
        "hermes"
      ];
```

该 host 已启用 WSL 和用户态 Home Manager，适合覆盖 Hermes role 的选项合并、包解析和用户服务求值。

- [ ] **步骤 4：运行格式化**

运行：

```bash
nix fmt
```

预期：role 和 checks 文件格式化完成。

- [ ] **步骤 5：验证 role 名称导出**

运行：

```bash
nix eval .#lib.roleNames --json
```

预期：输出 JSON 数组包含 `"hermes"`。

- [ ] **步骤 6：验证 Hermes role 覆盖的 example host 可求值**

运行：

```bash
nix eval .#checks.x86_64-linux.example-wsl-dev-container.drvPath
```

预期：命令成功输出一个 `.drv` 路径；如果失败，错误不得是找不到 `inputs.hermes-agent`、找不到 `nodejs_24`、找不到 `pnpm`、找不到 `yq-go`、找不到 `agent-browser`、找不到 `playwright-mcp`、找不到 `playwright-driver.browsers`、找不到 `chromium`、找不到中文字体包或找不到 `systemd.user.services.hermes-agent` 相关 option。

---

### 任务 4：更新 README 用户文档

**文件：**
- 修改：`README.md:95-100`
- 修改：`README.md:139-149`
- 修改：`README.md:181-189`
- 修改：`README.md:213-252`
- 修改：`README.md:290-297`

- [ ] **步骤 1：在快速开始示例 roles 中加入 Hermes**

把快速开始示例改为：

```nix
  roles = [
    "development"
    "fullstack-development"
    "ai-tooling"
    "container-host"
    "hermes"
  ];
```

- [ ] **步骤 2：更新 Role 列表**

在 `ai-tooling` 或 `container-host` 附近加入 Hermes 行：

```markdown
| `hermes`                | Hermes Agent CLI、agent-browser、视频下载、Playwright/Chromium、中文字体和用户级 gateway 服务 |
```

- [ ] **步骤 3：更新 platform 选项表**

在 `platform.home.opencode.*` 之后加入：

```markdown
| `platform.home.hermes.enable`                 | bool                     | `false`     | 启用 Hermes Agent 用户态环境         |
| `platform.home.hermes.package`                | nullOr package           | `null`      | Hermes 包；null 时使用官方 flake 默认包 |
| `platform.home.hermes.extraPackages`          | listOf package           | `[ ]`       | 追加安装到 Hermes 用户环境的额外包   |
| `platform.home.hermes.service.enable`         | bool                     | `true`      | 声明用户级 Hermes gateway 服务        |
| `platform.home.hermes.service.extraArgs`      | listOf string            | `[ ]`       | 追加传给 `hermes gateway` 的参数      |
```

- [ ] **步骤 4：新增 Hermes 使用章节**

在“高级用法”下、现有“物理机 + NVIDIA + 透明代理”之前新增：

```markdown
### Hermes Agent 用户级服务

启用 `hermes` role 后，主用户会获得 Hermes CLI、`agent-browser`、`yt-dlp`、`streamlink`、`playwright`、`playwright-mcp`、Chromium、Playwright browsers、中文/CJK/emoji 字体、较完整的 Python/Node/构建/媒体/搜索依赖，以及用户级 `hermes-agent.service`。本仓库不管理 `~/.hermes/config.yaml` 或 `~/.hermes/.env`，provider token 和 gateway token 仍由用户通过 Hermes CLI 写入自己的 home 目录。

```nix
public.lib.mkHost {
  hostname = "ai-workstation";
  system = "x86_64-linux";
  user = commonUser;
  profiles = [ "workstation-base" ];
  roles = [
    "development"
    "ai-tooling"
    "hermes"
  ];
}
```

首次部署后先配置 Hermes：

```bash
hermes setup
```

配置完成后启动 gateway：

```bash
systemctl --user start hermes-agent.service
```

如需随用户会话自动启动：

```bash
systemctl --user enable hermes-agent.service
```

查看日志：

```bash
journalctl --user -u hermes-agent.service -f
```

常用工具检查：

```bash
agent-browser --version
yt-dlp --version
playwright --version
chromium --version
```
```

注意：添加上面内容时，外层 Markdown 不能被内层三反引号截断；如果手动编辑不方便，可把本章节的内部代码块保留为普通 fenced block，并确认渲染正确。

- [ ] **步骤 5：更新项目结构**

把 `modules/home` 树中的 OpenCode 行附近改为：

```markdown
│   │   ├── opencode/      # OpenCode AI 助手
│   │   ├── hermes/        # Hermes Agent、agent-browser、浏览器自动化与 gateway 服务
│   │   └── desktop/       # Kitty 与 mpv 桌面用户配置
```

- [ ] **步骤 6：运行 README 文本检查**

运行：

```bash
nix eval .#lib.roleNames --json
```

预期：仍成功输出包含 `"hermes"` 的 JSON 数组；README 修改不应影响求值。

---

### 任务 5：最终验证与计划/规格一致性检查

**文件：**
- 验证：`flake.nix`
- 验证：`pkgs/agent-browser/default.nix`
- 验证：`modules/shared/options.nix`
- 验证：`modules/home/hermes/default.nix`
- 验证：`roles/hermes.nix`
- 验证：`lib/platform/checks.nix`
- 验证：`README.md`
- 验证：`docs/specs/active/2026-05-11-hermes-role-design.md`

- [ ] **步骤 1：运行全量格式化**

运行：

```bash
nix fmt
```

预期：成功完成，无未格式化错误。

- [ ] **步骤 2：运行目标 eval check**

运行：

```bash
nix eval .#checks.x86_64-linux.example-wsl-dev-container.drvPath
```

预期：成功输出一个 `.drv` 路径。

- [ ] **步骤 3：验证 `agent-browser` 构建输出**

运行：

```bash
nix build --no-link --print-out-paths --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; overlays = [ flake.overlays.default ]; }; in pkgs.agent-browser'
```

预期：成功输出 `agent-browser-0.27.0` 的 store path。随后运行：

```bash
nix shell --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs { system = "x86_64-linux"; overlays = [ flake.overlays.default ]; }; in pkgs.agent-browser' -c agent-browser --version
```

预期：输出 `agent-browser 0.27.0`。

- [ ] **步骤 4：运行 flake check**

运行：

```bash
nix flake check
```

预期：所有 checks 通过。若因 Hermes 上游 flake 下载、网络或构建成本失败，记录完整失败原因；然后至少保留步骤 2 的目标 eval check 作为新 role 的 fresh verification evidence。

- [ ] **步骤 5：检查不应出现 managed mode**

运行：

```bash
rg "HERMES_MANAGED|\.managed|/var/lib/hermes|services\.hermes-agent" flake.nix modules roles README.md docs/specs/active/2026-05-11-hermes-role-design.md
```

预期：只允许在 spec/README 的解释性文字中出现“不使用上游 managed/system service”的说明；`modules/` 和 `roles/` 中不得出现 `HERMES_MANAGED`、`.managed`、`/var/lib/hermes` 或 `services.hermes-agent`。

- [ ] **步骤 6：检查文档中的用户命令完整性**

运行：

```bash
rg "hermes setup|systemctl --user start hermes-agent\.service|journalctl --user -u hermes-agent\.service" README.md
```

预期：三类命令均能匹配到，说明 README 覆盖首次配置、启动和日志查看。

- [ ] **步骤 7：检查新增工具文档完整性**

运行：

```bash
rg "agent-browser --version|yt-dlp --version|playwright --version|chromium --version|中文|Playwright|Chromium" README.md docs/specs/active/2026-05-11-hermes-role-design.md
```

预期：README 和 spec 均覆盖 `agent-browser`、视频下载、Playwright/Chromium 和中文字体能力。

- [ ] **步骤 8：查看 git diff 并确认范围**

运行：

```bash
git diff -- flake.nix flake.lock pkgs/agent-browser/default.nix modules/shared/options.nix modules/home/default.nix modules/home/hermes/default.nix roles/hermes.nix roles/default.nix lib/platform/checks.nix README.md docs/specs/active/2026-05-11-hermes-role-design.md docs/plans/active/2026-05-11-hermes-role.md
```

预期：diff 只包含 Hermes role、spec/plan 和相关文档/check 更新；不得包含无关重构。

---

## 自检结果

- 规格覆盖：计划任务覆盖 flake input、`agent-browser` 包装、platform options、Home module、role、README、eval checks、Playwright/Chromium、视频下载、中文字体、非 managed mode 约束和验证命令。
- 占位符扫描：计划中没有 TBD/TODO/“稍后实现”占位步骤；每个代码变更步骤提供了具体文件和代码片段。
- 类型一致性：`platform.home.hermes.package` 在 options 中为 `nullOr package`，Home 模块用 `cfg.package != null` 决定是否取 `inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default`；`extraPackages` 始终是追加列表；用户服务名统一为 `hermes-agent`；Playwright 变量统一使用 `playwright-driver.browsers` 和 `chromium`。
