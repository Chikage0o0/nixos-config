# Hermes 用户级 Role 设计

## 背景

Nous Research Hermes Agent 官方提供 `github:NousResearch/hermes-agent` flake，并支持 `nix run`、`nix profile install`、NixOS native module 和 NixOS container module。官方 NixOS module 面向系统级托管服务，会创建 `hermes` 系统用户，使用 `/var/lib/hermes` 作为状态目录，并通过 `HERMES_MANAGED=true` 阻止用户在运行时用 `hermes setup` 修改配置。

本仓库的目标是把 Hermes 作为可选 role 提供给普通用户安装和使用。第一版不接入官方系统级 managed service，而是复用官方 flake 包，在 Home Manager 层安装 CLI、补齐依赖，并声明用户级 gateway 服务。这样用户仍可通过 `hermes setup` 管理自己的 `~/.hermes/config.yaml` 和 `~/.hermes/.env`。

## 目标

- 新增 `hermes` role，用户可在 host 的 `roles = [ "hermes" ];` 中启用。
- 启用 role 后，为主用户安装 Hermes CLI、`agent-browser` CLI、Playwright/Chromium 浏览器自动化环境、网络视频下载工具、中文字体和较完整的运行依赖。
- 启用 role 后，默认声明用户级 `systemd --user` Hermes gateway 服务。
- 保持用户态配置模型：配置和 secret 留在 `~/.hermes/`，不由 Nix 生成或覆盖。
- 遵循现有 `role -> platform.home.* -> modules/home/*` 分层模式。
- 更新 README 和 eval checks，确保新 role 可发现、可求值。

## 非目标

- 不导入或包装官方 `services.hermes-agent` NixOS module。
- 不创建系统用户、系统服务或 `/var/lib/hermes` 状态目录。
- 不设置 `HERMES_MANAGED=true`，不写 `.managed` marker。
- 不在 Nix 配置中声明 provider token、gateway token 或其他 secret。
- 不自动运行 `hermes setup` 或替用户初始化远端 provider。
- 不为容器模式、MCP server、documents、plugins 建立完整上游模块等价接口。

## 架构

### Flake 输入

在 `flake.nix` 中新增 Hermes Agent input，并在默认 overlay 中导出本仓库打包的 `agent-browser`：

```nix
hermes-agent = {
  url = "github:NousResearch/hermes-agent";
  inputs.nixpkgs.follows = "nixpkgs-unstable";
};
```

Home Manager 模块通过现有 `home-manager.extraSpecialArgs.inputs` 访问该 input，并使用当前 host platform 对应的 `inputs.hermes-agent.packages.<system>.default` 作为默认 Hermes 包。

### `agent-browser` 包

`agent-browser` 在 nixpkgs 25.11 中没有可直接使用的 package，但 npm 上存在 `agent-browser@0.27.0`，包含 Linux x86_64/aarch64 预编译二进制和 Node wrapper。新增 `pkgs/agent-browser/default.nix` 从 npm tarball 固定版本与 hash 打包：

- 安装 `agent-browser` 命令到 `$out/bin/agent-browser`。
- 只保留当前 Linux 架构对应的 native binary。
- 使用 `autoPatchelfHook` 修正预编译 ELF 的动态链接器路径。
- 保留 package 内的 `skill-data` 与 `skills` 目录，避免 CLI 查找运行时资源失败。

默认 overlay 增加 `agent-browser = final.callPackage ./pkgs/agent-browser { };`，供 Hermes Home 模块通过 `pkgs.agent-browser` 安装。

### Platform 选项

在 `modules/shared/options.nix` 的 `platform.home` 下新增：

- `platform.home.hermes.enable`：是否安装 Hermes 用户态环境。
- `platform.home.hermes.package`：Hermes package；默认 `null`，表示自动取官方 flake 的 `default` 包。
- `platform.home.hermes.extraPackages`：额外加入用户环境的用户自定义依赖包，默认空列表。
- `platform.home.hermes.service.enable`：是否声明用户级 gateway 服务，默认 `true`。
- `platform.home.hermes.service.extraArgs`：传给 `hermes gateway` 的额外参数，默认空列表。

`package` 的自动选择逻辑需要在 Home 模块中定义，因为它依赖当前 host platform 和 `inputs`。共享 options 中只声明类型和说明。

### Home Manager 模块

新增 `modules/home/hermes/default.nix`，并在 `modules/home/default.nix` 中导入。

当 `platform.home.hermes.enable = true` 时：

- `home.packages` 包含 Hermes 包、默认依赖包和 `extraPackages`。
- `home.sessionVariables` 为 Playwright/Chromium/agent-browser 提供浏览器路径相关默认值。
- `fonts.fontconfig.enable = true`，确保用户级安装的中文字体被 fontconfig 发现。
- 用户服务 `systemd.user.services.hermes-agent` 被声明。
- 服务启动命令为 `${hermesPackage}/bin/hermes gateway` 加 `service.extraArgs`，其中 `hermesPackage` 是用户覆盖包或官方 flake 默认包。
- 服务环境包含：
  - `HOME=%h`
  - `HERMES_HOME=%h/.hermes`
  - `MESSAGING_CWD=%h`
  - `PLAYWRIGHT_BROWSERS_PATH=<nix store playwright browsers>`
  - `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`
  - `CHROME_PATH=<nix store chromium binary>`
- 服务不设置 `HERMES_MANAGED`。
- 服务使用 `Restart=on-failure`，并在 `graphical-session.target` 或 `default.target` 下可由用户启停。

服务不主动创建或改写 `~/.hermes/config.yaml`、`~/.hermes/.env`。用户应先运行 `hermes setup` 或 `hermes model` 完成 provider 配置，再启动服务。

### 依赖范围

Home 模块内置默认依赖集合，以“装全一点”为目标，覆盖官方安装脚本和 agent 常见工作流需要的工具。默认集合：

- Hermes 与 agent CLI：`hermesPackage`、`agent-browser`。
- 官方安装脚本明确或常见需要：`uv`、`nodejs`、`ripgrep`、`ffmpeg`、`git`。
- Python/Node 构建与包管理：`python3`、`python3Packages.pip`、`pnpm`、`yarn`。
- 常见源码与构建工具：`gcc`、`gnumake`、`pkg-config`、`cmake`。
- 常见归档与网络工具：`curl`、`wget`、`unzip`、`zip`、`gnutar`、`gzip`。
- 常用文本/JSON/YAML 处理：`jq`、`yq-go`。
- 用户态 agent 常用搜索与文件工具：`fd`、`tree`。
- 网络视频下载与媒体处理：`yt-dlp`、`streamlink`、`aria2`、`mpv`、`ffmpeg`。
- 浏览器自动化：`playwright`、`playwright-mcp`、`playwright-driver.browsers`、`chromium`。
- 中文、CJK 与 emoji 字体：`noto-fonts-cjk-sans`、`noto-fonts-cjk-serif`、`noto-fonts-color-emoji`、`source-han-sans`、`sarasa-gothic`、`wqy_zenhei`。

如某个包名在当前 nixpkgs 版本中不可用，应在实现时选择同等稳定属性，且必须通过 eval check 验证。用户可以通过 `platform.home.hermes.extraPackages = [ ... ];` 追加依赖；默认依赖始终随 `platform.home.hermes.enable = true` 安装，除非后续另行设计显式关闭选项。

### Role

新增 `roles/hermes.nix`，保持薄 role：

```nix
{ lib, ... }:
{
  platform.home.hermes.enable = lib.mkDefault true;
  platform.home.hermes.service.enable = lib.mkDefault true;
  platform.home.shell.enable = lib.mkDefault true;
  platform.home.git.enable = lib.mkDefault true;
}
```

`platform.home.shell.enable` 保证用户有基础 shell、direnv、SSH 等交互环境；`platform.home.git.enable` 与 Hermes/agent 工作区操作强相关，因此默认启用。用户仍可在 host 配置中覆盖这些默认值。

### 文档

README 更新内容：

- roles 列表新增 `hermes`。
- 增加简短说明：Hermes role 安装 CLI、依赖和用户级 gateway 服务。
- 给出基本使用命令：
  - 启用 role 后 rebuild。
  - 运行 `hermes setup` 配置 provider 和 token。
  - 使用 `systemctl --user start hermes-agent.service` 启动 gateway。
  - 使用 `systemctl --user enable hermes-agent.service` 按需开机自启。

文档必须说明 secret 位于 `~/.hermes/.env`，不由本仓库管理。

## 测试与验证

- 更新 `lib/platform/checks.nix`，在至少一个示例 host 的 roles 中加入 `hermes`。
- 运行 `nix flake check` 或等价 eval check，确认新增 flake input、Home module、包名和用户服务可求值。
- 如完整 `nix flake check` 因上游网络或构建成本不可行，至少执行目标 eval check 并记录限制。

## 风险与约束

- Hermes 上游 flake 可能较重，首次 eval/build 依赖上游锁定和网络。
- 用户级服务启动前若未配置 provider/token，gateway 可能失败；这是预期行为，需在 README 中说明先运行 `hermes setup`。
- 默认依赖集合较大，会增加用户 profile 体积；这是本次“依赖装全一点”的明确取舍。
- Playwright 浏览器、Chromium 与中文字体会显著增加闭包体积；这是为了保证网络视频下载、网页自动化和中文渲染开箱可用的明确取舍。
- `agent-browser` 通过 npm tarball 的预编译二进制打包；实现必须固定版本和 hash，并通过 `agent-browser --version` 或至少 derivation eval 检查验证可用性。
- 不使用 managed mode 意味着 Nix 不负责 Hermes runtime 配置一致性，但换来用户可自助配置。

## 验收标准

- `roles/default.nix` 导出 `hermes` role。
- 启用 `hermes` role 后，Home Manager 用户环境包含 `hermes`、`agent-browser`、`yt-dlp`、`playwright`、`playwright-mcp`、`chromium`、默认依赖集合和用户追加依赖。
- 启用 `hermes` role 后，用户级环境提供 Playwright 浏览器路径变量，并启用 fontconfig 中文字体发现。
- 启用 `hermes` role 后，存在用户级 `hermes-agent.service`，启动命令为 `hermes gateway`。
- 用户配置目录保持 `~/.hermes`，Nix 不覆盖 `.env` 或 `config.yaml`。
- README 能指导用户完成配置和启动。
- eval check 通过。
