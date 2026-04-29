# workstation-base KDE Plasma 桌面 实施计划

> **给代理执行者：** REQUIRED SUB-SKILL: 使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务执行本计划。步骤使用复选框 `- [ ]` 语法追踪。

**目标：** 让所有使用 `workstation-base` profile 的 NixOS 工作站默认获得 KDE Plasma 6 日常桌面、常用 GUI 软件、字体、输入法、Kitty/mpv Home Manager 配置，并保持 WSL/server/generic profile 不默认启用桌面。

**架构：** 新增共享 `platform.desktop.*` 选项，`workstation-base` 只设置 profile 默认值；NixOS `desktop/plasma.nix` 模块负责系统服务、Plasma、字体、输入法和系统级 GUI 包；Home Manager `desktop/default.nix` 模块只在完整桌面应用集启用时配置主用户 Kitty 与 mpv。开发 GUI（VS Code、dbgate）归入 `platform.development.fullstack.enable` 对应的 Home packages，NVIDIA 模块只声明驱动能力，不再关闭 X server。

**技术栈：** NixOS Flakes, Nix modules, Home Manager, KDE Plasma 6, SDDM Wayland, PipeWire, Fcitx5, Flatpak, KDE Connect, Kitty, mpv

---

## 文件结构与职责

| 路径 | 职责 |
| --- | --- |
| `modules/shared/options.nix` | 新增共享 `platform.desktop.enable`、`platform.desktop.environment`、`platform.desktop.apps.enable` 选项，供 NixOS 与 Home Manager 模块读取。 |
| `lib/platform/default.nix` | 让 `mkHost` 接受并透传可选 `host.desktop` 覆盖项，使具体主机能关闭桌面或完整应用集。 |
| `profiles/workstation-base.nix` | 使用现有 `profileDefault = lib.mkOverride 1200` 默认启用 Plasma 桌面和完整日常应用集。 |
| `modules/nixos/desktop/plasma.nix` | 新增 NixOS 桌面落地模块：Plasma 6、SDDM Wayland、PipeWire、蓝牙、打印、Flatpak、KDE Connect、Fcitx5、系统 GUI 包、字体、KDE 默认应用瘦身。 |
| `modules/nixos/default.nix` | 导入 `./desktop/plasma.nix`。 |
| `modules/home/desktop/default.nix` | 新增 Home Manager 桌面模块：Kitty 字体与克制配置、mpv 脚本与快捷键。 |
| `modules/home/default.nix` | 导入 `./desktop`。 |
| `modules/home/development/packages.nix` | 将 `vscode` 和 `dbgate` 放入 `fullstackPackages`，不放入基础桌面。 |
| `modules/nixos/hardware/nvidia.nix` | 删除 `services.xserver.enable = false`，保留 `services.xserver.videoDrivers = [ "nvidia" ];` 和 NVIDIA/CUDA 能力。 |
| `modules/nixos/core/assertions.nix` | 增加 WSL 禁止桌面、桌面环境仅支持 Plasma 的断言。 |
| `README.md` | 更新 `workstation-base` 描述、platform 选项表、日常预置软件摘要、开发 GUI 边界、项目结构。 |

## 全局执行规则

- 每个任务开始前运行 `git status --short`，只确认当前变更范围，不回滚用户或其他代理的改动。
- 每个 Nix 文件改动后运行 `nix fmt`，并确认格式化没有引入无关改动。
- 每个任务先运行本任务的失败验证，再改代码，再运行本任务的通过验证。
- 如果执行会话已获得用户明确授权提交，任务完成后使用 `git-commit` skill 提交该任务相关文件；没有授权时跳过提交并记录未提交状态。
- 所有新文档和代码注释使用中文；Nix 标识符、路径、命令保持原样。
- 所有 eval 命令使用当前分支的本地 flake：`builtins.getFlake (toString ./.)`。

---

### 任务 1：新增 `platform.desktop.*` 选项与 workstation 默认值

**文件：**
- 修改：`modules/shared/options.nix`
- 修改：`lib/platform/default.nix`
- 修改：`profiles/workstation-base.nix`

- [ ] **步骤 1：运行失败验证**

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
    hostname = "desktop-options-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
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
  host.config.platform.desktop
'
```

预期：FAIL，错误包含 `platform.desktop` 不存在或属性缺失。

- [ ] **步骤 2：在共享 options 中新增 desktop 选项组**

修改 `modules/shared/options.nix`，在 `machine` 选项组之后、`nix.maxJobs` 之前加入：

```nix
    desktop = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用图形桌面环境。";
      };

      environment = mkOption {
        type = types.enum [ "plasma" ];
        default = "plasma";
        description = "桌面环境。第一版只支持 KDE Plasma。";
      };

      apps.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用日常完整桌面应用集、字体、输入法、应用分发工具，以及 Kitty/mpv Home Manager 配置。";
      };
    };
```

- [ ] **步骤 3：让 `workstation-base` 默认启用 Plasma 桌面**

将 `profiles/workstation-base.nix` 改为：

```nix
{ lib, ... }:
let
  # 使用低于 role 默认值（lib.mkOverride 1000）的优先级，
  # 使 role 的 lib.mkDefault 能覆盖 profile 默认值。
  profileDefault = lib.mkOverride 1200;
in
{
  platform.machine.class = profileDefault "workstation";
  platform.machine.wsl.enable = profileDefault false;
  platform.desktop.enable = profileDefault true;
  platform.desktop.environment = profileDefault "plasma";
  platform.desktop.apps.enable = profileDefault true;
  platform.services.openssh.enable = profileDefault false;
  platform.services.cockpit.enable = profileDefault false;
}
```

- [ ] **步骤 4：让 `mkHost` 透传主机级 desktop 覆盖项**

修改 `lib/platform/default.nix` 的 `normalizeHost` 默认字段块，加入 `desktop = host.desktop or { };`：

```nix
        host
        // {
          system = host.system or "x86_64-linux";
          profiles = host.profiles or [ "generic-linux" ];
          roles = host.roles or [ ];
          machine = host.machine or { };
          desktop = host.desktop or { };
          networking = host.networking or { };
          services = host.services or { };
          home = host.home or { };
          secrets = host.secrets or { };
          extraModules = host.extraModules or [ ];
          hardwareModules = host.hardwareModules or [ ];
        }
```

修改同一文件的 `platformHostModule` 中 `compactNulls` 字段块，加入 `desktop = host.desktop or null;`：

```nix
        (compactNulls {
          stateVersion = host.stateVersion or null;
          machine = host.machine or null;
          desktop = host.desktop or null;
          nix = host.nix or null;
          networking = host.networking or null;
          services = host.services or null;
          containers = host.containers or null;
          home = host.home or null;
          development = host.development or null;
          packages = host.packages or null;
        })
```

- [ ] **步骤 5：运行默认值通过验证**

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
    hostname = "desktop-options-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
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
  enable = host.config.platform.desktop.enable;
  environment = host.config.platform.desktop.environment;
  appsEnable = host.config.platform.desktop.apps.enable;
}
'
```

预期：PASS，输出：

```json
{"appsEnable":true,"enable":true,"environment":"plasma"}
```

- [ ] **步骤 6：运行主机级覆盖通过验证**

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
    hostname = "desktop-override-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
    machine.boot.mode = "uefi";
    desktop = {
      enable = false;
      apps.enable = false;
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
in
{
  enable = host.config.platform.desktop.enable;
  appsEnable = host.config.platform.desktop.apps.enable;
}
'
```

预期：PASS，输出：

```json
{"appsEnable":false,"enable":false}
```

- [ ] **步骤 7：运行格式化**

运行：`nix fmt`

预期：PASS，命令退出码为 `0`。

- [ ] **步骤 8：提交本任务变更**

如果已获用户授权提交，使用 `git-commit` skill 提交：

```text
feat: add desktop platform defaults
```

---

### 任务 2：实现 NixOS Plasma 桌面模块

**文件：**
- 新增：`modules/nixos/desktop/plasma.nix`
- 修改：`modules/nixos/default.nix`

- [ ] **步骤 1：运行失败验证**

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
    hostname = "desktop-services-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
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
  cfg = host.config;
in
{
  plasma = cfg.services.desktopManager.plasma6.enable;
  sddm = cfg.services.displayManager.sddm.enable;
  pipewire = cfg.services.pipewire.enable;
  flatpak = cfg.services.flatpak.enable;
  kdeconnect = cfg.programs.kdeconnect.enable;
}
'
```

预期：FAIL 或输出包含 `false`，因为 `platform.desktop.enable` 尚未落地到 NixOS 桌面服务。

- [ ] **步骤 2：新增 Plasma 桌面模块**

创建 `modules/nixos/desktop/plasma.nix`：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;

  desktopPackages = with pkgs; [
    microsoft-edge
    wpsoffice-cn
    kdePackages.gwenview
    kdePackages.spectacle
    gimp
    kdePackages.dolphin
    kdePackages.kate
    kdePackages.ark
    kdePackages.kcalc
    p7zip
    unrar
    bitwarden-desktop
    remmina
    kdePackages.plasma-systemmonitor
    kdePackages.partitionmanager
    kdePackages.filelight
    kdePackages.print-manager
    kdePackages.bluedevil
    kdePackages.plasma-nm
    kdePackages.discover
    appimage-run
    obsidian
    thunderbird
    yt-dlp
    ffmpeg-full
    mediainfo
  ];

  desktopFonts = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    sarasa-gothic
    nerd-fonts.fira-code
    corefonts
    vista-fonts
    vista-fonts-chs
  ];
in
{
  config = lib.mkIf cfg.desktop.enable (lib.mkMerge [
    {
      services.xserver.enable = true;
      services.desktopManager.plasma6.enable = true;
      services.displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
      services.libinput.enable = true;
      xdg.portal.enable = true;

      services.pipewire = {
        enable = true;
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        jack.enable = true;
        wireplumber.enable = true;
      };
      security.rtkit.enable = true;

      hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;
      };

      services.printing.enable = true;

      environment.plasma6.excludePackages = with pkgs; [
        kdePackages.konsole
        kdePackages.okular
        kdePackages.elisa
        kdePackages.dragon
      ];
    }

    (lib.mkIf cfg.desktop.apps.enable {
      services.flatpak.enable = true;
      programs.kdeconnect.enable = true;

      i18n.inputMethod = {
        enable = true;
        type = "fcitx5";
        fcitx5.addons = with pkgs; [
          kdePackages.fcitx5-chinese-addons
          kdePackages.fcitx5-configtool
        ];
      };

      environment.systemPackages = desktopPackages;
      fonts.packages = desktopFonts;
    })
  ]);
}
```

- [ ] **步骤 3：导入 NixOS desktop 模块**

修改 `modules/nixos/default.nix` 为：

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
    ./desktop/plasma.nix
  ];
}
```

- [ ] **步骤 4：运行服务与能力通过验证**

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
    hostname = "desktop-services-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
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
  cfg = host.config;
in
{
  xserver = cfg.services.xserver.enable;
  plasma = cfg.services.desktopManager.plasma6.enable;
  sddm = cfg.services.displayManager.sddm.enable;
  sddmWayland = cfg.services.displayManager.sddm.wayland.enable;
  libinput = cfg.services.libinput.enable;
  portal = cfg.xdg.portal.enable;
  pipewire = cfg.services.pipewire.enable;
  pipewireAlsa = cfg.services.pipewire.alsa.enable;
  pipewirePulse = cfg.services.pipewire.pulse.enable;
  pipewireJack = cfg.services.pipewire.jack.enable;
  wireplumber = cfg.services.pipewire.wireplumber.enable;
  rtkit = cfg.security.rtkit.enable;
  bluetooth = cfg.hardware.bluetooth.enable;
  bluetoothPowerOnBoot = cfg.hardware.bluetooth.powerOnBoot;
  printing = cfg.services.printing.enable;
  flatpak = cfg.services.flatpak.enable;
  kdeconnect = cfg.programs.kdeconnect.enable;
  fcitxEnable = cfg.i18n.inputMethod.enable;
  fcitxType = cfg.i18n.inputMethod.type;
}
'
```

预期：PASS，输出所有布尔字段均为 `true`，并且 `fcitxType` 为 `"fcitx5"`。

- [ ] **步骤 5：运行包与字体通过验证**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  lib = flake.inputs.nixpkgs.lib;
  user = {
    name = "example";
    fullName = "Example User";
    email = "example@example.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
  };
  host = flake.lib.mkHost {
    hostname = "desktop-packages-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
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
  packageIds = packages: builtins.map (pkg: {
    pname = pkg.pname or "";
    name = pkg.name or "";
  }) packages;
  hasPackage = wanted: packages:
    builtins.any (pkg: pkg.pname == wanted || lib.hasPrefix "${wanted}-" pkg.name) (packageIds packages);
  hasAll = required: packages: builtins.all (name: hasPackage name packages) required;
in
{
  desktopPackages = hasAll [
    "microsoft-edge"
    "wpsoffice-cn"
    "gwenview"
    "spectacle"
    "gimp"
    "dolphin"
    "kate"
    "ark"
    "kcalc"
    "p7zip"
    "unrar"
    "bitwarden-desktop"
    "remmina"
    "plasma-systemmonitor"
    "partitionmanager"
    "filelight"
    "print-manager"
    "bluedevil"
    "plasma-nm"
    "discover"
    "appimage-run"
    "obsidian"
    "thunderbird"
    "yt-dlp"
    "ffmpeg"
    "mediainfo"
  ] host.config.environment.systemPackages;
  fonts = hasAll [
    "noto-fonts-cjk-sans"
    "noto-fonts-cjk-serif"
    "noto-fonts-color-emoji"
    "sarasa-gothic"
    "nerd-fonts-fira-code"
    "corefonts"
    "vista-fonts"
    "vista-fonts-chs"
  ] host.config.fonts.packages;
  excludedDefaults = hasAll [
    "konsole"
    "okular"
    "elisa"
    "dragon"
  ] host.config.environment.plasma6.excludePackages;
  noDevGuiInDesktopPackages =
    !(hasPackage "vscode" host.config.environment.systemPackages)
    && !(hasPackage "dbgate" host.config.environment.systemPackages);
}
'
```

预期：PASS，输出：

```json
{"desktopPackages":true,"excludedDefaults":true,"fonts":true,"noDevGuiInDesktopPackages":true}
```

- [ ] **步骤 6：验证关闭 apps 时只保留桌面壳**

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
    hostname = "desktop-apps-disabled-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
    machine.boot.mode = "uefi";
    desktop.apps.enable = false;
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
  cfg = host.config;
in
{
  plasma = cfg.services.desktopManager.plasma6.enable;
  flatpak = cfg.services.flatpak.enable;
  kdeconnect = cfg.programs.kdeconnect.enable;
  fcitx = cfg.i18n.inputMethod.enable;
}
'
```

预期：PASS，输出：

```json
{"fcitx":false,"flatpak":false,"kdeconnect":false,"plasma":true}
```

- [ ] **步骤 7：运行格式化**

运行：`nix fmt`

预期：PASS，命令退出码为 `0`。

- [ ] **步骤 8：提交本任务变更**

如果已获用户授权提交，使用 `git-commit` skill 提交：

```text
feat: add plasma desktop system module
```

---

### 任务 3：实现 Home Manager Kitty 与 mpv 桌面配置

**文件：**
- 新增：`modules/home/desktop/default.nix`
- 修改：`modules/home/default.nix`

- [ ] **步骤 1：运行失败验证**

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
    hostname = "desktop-home-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
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
in
{
  kitty = hm.programs.kitty.enable;
  mpv = hm.programs.mpv.enable;
}
'
```

预期：FAIL 或输出 `kitty = false`、`mpv = false`，因为 Home Manager 桌面模块尚未导入。

- [ ] **步骤 2：新增 Home Manager desktop 模块**

创建 `modules/home/desktop/default.nix`：

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
  config = lib.mkIf (cfg.desktop.enable && cfg.desktop.apps.enable) {
    programs.kitty = {
      enable = true;
      font = {
        name = "FiraCode Nerd Font";
        package = pkgs.nerd-fonts.fira-code;
        size = 12;
      };
      settings = {
        confirm_os_window_close = 0;
        enable_audio_bell = false;
        scrollback_lines = 10000;
      };
    };

    programs.mpv = {
      enable = true;
      scripts = with pkgs.mpvScripts; [
        uosc
        thumbfast
        mpris
        mpv-cheatsheet-ng
      ];
      config = {
        hwdec = "auto-safe";
        save-position-on-quit = true;
        osd-bar = false;
        osc = false;
        sub-auto = "fuzzy";
        slang = "chi,chs,sc,zh-Hans,zh-CN,zh,eng,en";
        alang = "jpn,ja,eng,en,chi,zh";
        screenshot-format = "png";
        screenshot-png-compression = 3;
        ytdl-format = "bestvideo[height<=?2160]+bestaudio/best";
      };
      scriptOpts = {
        uosc = {
          timeline_style = "bar";
          timeline_size = 40;
          controls = "menu,gap,subtitles,audio,space,fullscreen";
          top_bar = "yes";
        };
        thumbfast = {
          network = true;
          spawn_first = true;
        };
      };
      bindings = {
        RIGHT = "seek 5";
        LEFT = "seek -5";
        UP = "seek 60";
        DOWN = "seek -60";
        "]" = "add speed 0.1";
        "[" = "add speed -0.1";
        "\\" = "set speed 1.0";
        a = "cycle audio";
        s = "cycle sub";
        v = "cycle sub-visibility";
        i = "script-binding stats/display-stats-toggle";
        q = "quit-watch-later";
        S = "screenshot";
        "." = "frame-step";
        "," = "frame-back-step";
        PGUP = "add chapter 1";
        PGDWN = "add chapter -1";
        SPACE = "cycle pause";
        m = "cycle mute";
      };
    };
  };
}
```

- [ ] **步骤 3：导入 Home Manager desktop 模块**

修改 `modules/home/default.nix` 为：

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
    ./desktop
  ];
}
```

- [ ] **步骤 4：运行 Home Manager 通过验证**

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
    hostname = "desktop-home-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
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
  scriptNames = builtins.map (pkg: pkg.pname or pkg.name) hm.programs.mpv.scripts;
in
{
  kitty = hm.programs.kitty.enable;
  kittyFont = hm.programs.kitty.font.name;
  kittyFontPackage = hm.programs.kitty.font.package.pname or hm.programs.kitty.font.package.name;
  mpv = hm.programs.mpv.enable;
  mpvHwdec = hm.programs.mpv.config.hwdec;
  mpvSavePosition = hm.programs.mpv.config.save-position-on-quit;
  mpvScripts = builtins.all (name: builtins.elem name scriptNames) [
    "uosc"
    "mpv-thumbfast"
    "mpv-mpris"
    "mpv-cheatsheet-ng"
  ];
  mpvQuitBinding = hm.programs.mpv.bindings.q;
  mpvInfoBinding = hm.programs.mpv.bindings.i;
}
'
```

预期：PASS，输出包含：

```json
{"kitty":true,"kittyFont":"FiraCode Nerd Font","kittyFontPackage":"nerd-fonts-fira-code","mpv":true,"mpvHwdec":"auto-safe","mpvInfoBinding":"script-binding stats/display-stats-toggle","mpvQuitBinding":"quit-watch-later","mpvSavePosition":true,"mpvScripts":true}
```

- [ ] **步骤 5：验证关闭 apps 时不写 Kitty/mpv 配置**

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
    hostname = "desktop-home-disabled-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ ];
    machine.boot.mode = "uefi";
    desktop.apps.enable = false;
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
in
{
  kitty = hm.programs.kitty.enable;
  mpv = hm.programs.mpv.enable;
}
'
```

预期：PASS，输出：

```json
{"kitty":false,"mpv":false}
```

- [ ] **步骤 6：运行格式化**

运行：`nix fmt`

预期：PASS，命令退出码为 `0`。

- [ ] **步骤 7：提交本任务变更**

如果已获用户授权提交，使用 `git-commit` skill 提交：

```text
feat: configure desktop home apps
```

---

### 任务 4：将 VS Code 与 dbgate 放入 fullstack 开发包

**文件：**
- 修改：`modules/home/development/packages.nix`

- [ ] **步骤 1：运行失败验证**

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
    hostname = "fullstack-gui-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ "fullstack-development" ];
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
  names = builtins.map (pkg: pkg.pname or pkg.name) host.config.home-manager.users.example.home.packages;
in
{
  vscode = builtins.elem "vscode" names;
  dbgate = builtins.elem "dbgate" names;
}
'
```

预期：FAIL 或输出：

```json
{"dbgate":false,"vscode":false}
```

- [ ] **步骤 2：更新 fullstack Home packages**

修改 `modules/home/development/packages.nix` 中的 `fullstackPackages` 为：

```nix
  fullstackPackages = with pkgs; [
    go
    rustc
    cargo
    sqlite
    postgresql
    just
    gnumake
    vscode
    dbgate
  ];
```

- [ ] **步骤 3：运行 fullstack 通过验证**

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
    hostname = "fullstack-gui-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ "fullstack-development" ];
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
  names = builtins.map (pkg: pkg.pname or pkg.name) host.config.home-manager.users.example.home.packages;
in
{
  vscode = builtins.elem "vscode" names;
  dbgate = builtins.elem "dbgate" names;
}
'
```

预期：PASS，输出：

```json
{"dbgate":true,"vscode":true}
```

- [ ] **步骤 4：验证非 fullstack 工作站不获得开发 GUI**

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
    hostname = "daily-workstation-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ "development" ];
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
  names = builtins.map (pkg: pkg.pname or pkg.name) host.config.home-manager.users.example.home.packages;
in
{
  vscode = builtins.elem "vscode" names;
  dbgate = builtins.elem "dbgate" names;
}
'
```

预期：PASS，输出：

```json
{"dbgate":false,"vscode":false}
```

- [ ] **步骤 5：运行格式化**

运行：`nix fmt`

预期：PASS，命令退出码为 `0`。

- [ ] **步骤 6：提交本任务变更**

如果已获用户授权提交，使用 `git-commit` skill 提交：

```text
feat: add fullstack desktop development apps
```

---

### 任务 5：修复 NVIDIA 与桌面的 X server 冲突并新增断言

**文件：**
- 修改：`modules/nixos/hardware/nvidia.nix`
- 修改：`modules/nixos/core/assertions.nix`

- [ ] **步骤 1：运行 NVIDIA 冲突失败验证**

运行：

```bash
nix eval --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  user = {
    name = "example";
    fullName = "Example User";
    email = "example@example.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
  };
  host = flake.lib.mkHost {
    hostname = "gpu-desktop-conflict-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ "ai-accelerated" ];
    machine = {
      boot.mode = "uefi";
      nvidia.enable = true;
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
in
  host.config.system.build.toplevel.drvPath
'
```

预期：FAIL，错误包含 `services.xserver.enable` 定义冲突，冲突来源包含桌面模块启用和 NVIDIA 模块禁用。

- [ ] **步骤 2：调整 NVIDIA 模块不再关闭 X server**

将 `modules/nixos/hardware/nvidia.nix` 改为：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.platform.machine.nvidia.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

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

- [ ] **步骤 3：新增桌面断言**

将 `modules/nixos/core/assertions.nix` 改为：

```nix
{ config, lib, ... }:
let
  cfg = config.platform;
in
{
  assertions = [
    {
      assertion =
        cfg.machine.wsl.enable || cfg.machine.boot.mode != "uefi" || cfg.machine.boot.grubDevice == null;
      message = "使用 UEFI 启动时不要设置 platform.machine.boot.grubDevice；GRUB 会以 EFI 方式安装并使用 device = \"nodev\"。";
    }
    {
      assertion =
        cfg.machine.wsl.enable || cfg.machine.boot.mode != "bios" || cfg.machine.boot.grubDevice != null;
      message = "使用传统 BIOS 启动时必须设置 platform.machine.boot.grubDevice，例如 /dev/disk/by-id/...。";
    }
    {
      assertion =
        !cfg.networking.transparentProxy.enable || cfg.networking.transparentProxy.configFile != null;
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
    {
      assertion = !(cfg.machine.wsl.enable && cfg.desktop.enable);
      message = "WSL 主机不能启用 platform.desktop.enable；请关闭桌面配置或改用非 WSL profile。";
    }
    {
      assertion = !cfg.desktop.enable || cfg.desktop.environment == "plasma";
      message = "platform.desktop.environment 第一版只支持 plasma；请设置为 \"plasma\" 或关闭 platform.desktop.enable。";
    }
  ];
}
```

- [ ] **步骤 4：运行 NVIDIA 通过验证**

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
    hostname = "gpu-desktop-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ "ai-accelerated" ];
    machine = {
      boot.mode = "uefi";
      nvidia.enable = true;
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
in
{
  xserver = host.config.services.xserver.enable;
  drivers = host.config.services.xserver.videoDrivers;
  nvidia = host.config.hardware.nvidia-container-toolkit.enable;
}
'
```

预期：PASS，输出：

```json
{"drivers":["nvidia"],"nvidia":true,"xserver":true}
```

- [ ] **步骤 5：验证无桌面 NVIDIA 主机不启用 X server**

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
    hostname = "nvidia-server-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "server-base" ];
    roles = [ "ai-accelerated" ];
    machine = {
      boot.mode = "uefi";
      nvidia.enable = true;
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
in
{
  desktop = host.config.platform.desktop.enable;
  xserver = host.config.services.xserver.enable;
  drivers = host.config.services.xserver.videoDrivers;
}
'
```

预期：PASS，输出：

```json
{"desktop":false,"drivers":["nvidia"],"xserver":false}
```

- [ ] **步骤 6：验证 WSL 禁止桌面断言**

运行：

```bash
nix eval --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  user = {
    name = "example";
    fullName = "Example User";
    email = "example@example.com";
    sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
  };
  host = flake.lib.mkHost {
    hostname = "wsl-desktop-forbidden-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "wsl-base" ];
    roles = [ ];
    machine.wsl.enable = true;
    desktop.enable = true;
    secrets.sops.enable = false;
  };
in
  host.config.system.build.toplevel.drvPath
'
```

预期：FAIL，错误包含：

```text
WSL 主机不能启用 platform.desktop.enable；请关闭桌面配置或改用非 WSL profile。
```

- [ ] **步骤 7：运行格式化**

运行：`nix fmt`

预期：PASS，命令退出码为 `0`。

- [ ] **步骤 8：提交本任务变更**

如果已获用户授权提交，使用 `git-commit` skill 提交：

```text
fix: allow plasma with nvidia workstations
```

---

### 任务 6：更新 README 并运行最终验证

**文件：**
- 修改：`README.md`

- [ ] **步骤 1：运行文档失败检查**

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
  workstation = flake.lib.mkHost {
    hostname = "readme-workstation-probe";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "workstation-base" ];
    roles = [ "development" ];
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
  readmeNeedsDesktopDocs = workstation.config.platform.desktop.enable;
}
'
```

预期：PASS，输出 `{"readmeNeedsDesktopDocs":true}`，说明 README 必须描述 `workstation-base` 默认桌面行为。

- [ ] **步骤 2：更新 README 开头描述**

将 `README.md` 第 7 行附近改为：

```markdown
基于 **NixOS Flakes** 的可复用模块库，为 **KDE Plasma 日常工作站**、**AI 研发**、**CUDA 加速**和**全栈开发**场景提供开箱即用的配置。
```

- [ ] **步骤 3：更新 Profile 设计规则与列表**

将 `README.md` 的 `Profile / Role 设计规则` 小节改为：

```markdown
### Profile / Role 设计规则

- **profile** 只描述机器形态：`wsl-base`、`workstation-base`、`server-base`、`generic-linux`。
- `workstation-base` 默认启用 KDE Plasma 6 日常桌面；主机仍可通过更高优先级配置关闭 `platform.desktop.enable` 或 `platform.desktop.apps.enable`。
- OpenCode、全栈开发工具和 Podman 由 role/feature 组合，不绑定到某个 profile。
- VS Code 和 dbgate 属于 `fullstack-development`，不属于基础桌面包集合。
- dae 是本机透明代理 feature：`platform.networking.transparentProxy`，不是代理网关 role。
```

将 `Profile 列表` 表格改为：

```markdown
| Profile              | 描述                                          |
| -------------------- | --------------------------------------------- |
| `wsl-base`           | WSL 环境基础配置                              |
| `workstation-base`   | 物理工作站基础配置，默认包含 KDE Plasma 日常桌面 |
| `server-base`        | 服务器基础配置                                |
| `generic-linux`      | 通用 Linux（默认，不附加特定形态约束）        |
```

- [ ] **步骤 4：更新 Role 列表中的 fullstack 描述**

将 `Role 列表` 表格中的 `fullstack-development` 行改为：

```markdown
| `fullstack-development` | 全栈开发工具（Go/Rust/数据库工具、VS Code、dbgate 等） |
```

- [ ] **步骤 5：更新 platform 选项参考表**

在 `platform.machine.nvidia.enable` 行后插入：

```markdown
| `platform.desktop.enable`                      | bool                     | `false`     | 启用图形桌面环境                    |
| `platform.desktop.environment`                 | enum                     | `"plasma"` | 桌面环境；第一版只支持 Plasma       |
| `platform.desktop.apps.enable`                 | bool                     | `false`     | 启用日常桌面应用集、字体、输入法与 Kitty/mpv 配置 |
```

在表格已有 Home/Development 项附近确保存在这些行：

```markdown
| `platform.home.cliTools.enable`                | bool                     | `false`     | 启用现代 CLI 工具                   |
| `platform.development.fullstack.enable`        | bool                     | `false`     | 启用全栈开发工具包                  |
```

- [ ] **步骤 6：新增日常桌面摘要**

在 `platform 选项参考` 表格后、`高级用法` 前插入：

```markdown
### workstation-base 默认桌面

`workstation-base` 使用 profile 默认值启用：

- `platform.desktop.enable = true`
- `platform.desktop.environment = "plasma"`
- `platform.desktop.apps.enable = true`

默认桌面能力包括 KDE Plasma 6、SDDM Wayland、PipeWire、蓝牙、打印、Flatpak、KDE Connect 和 Fcitx5 拼音输入法。

日常预置软件包括 Microsoft Edge、WPS Office CN、Gwenview、Spectacle、GIMP、Dolphin、Kate、Ark、KCalc、Bitwarden、Remmina、Plasma System Monitor、KDE Partition Manager、Filelight、Discover、AppImage 支持、Obsidian、Thunderbird、yt-dlp、ffmpeg-full 和 mediainfo。

字体包含 Noto CJK、Noto Color Emoji、Sarasa Gothic、FiraCode Nerd Font、corefonts、vista-fonts 和 vista-fonts-chs，用于中文显示、emoji、编程字体候选和 WPS/Office 文档常见 Windows 字体兼容。

基础桌面不包含聊天通讯软件、游戏/Wine/Proton 工具、同步云盘客户端、专用 PDF 查看器、IDE 或数据库 GUI。VS Code 与 dbgate 只在启用 `fullstack-development` role 时通过 Home Manager 安装。
```

- [ ] **步骤 7：更新项目结构**

将 `README.md` 项目结构中的 NixOS 与 Home Manager 模块目录段落改为包含 `desktop`：

```markdown
│   ├── nixos/
│   │   ├── default.nix    # 系统模块聚合
│   │   ├── core/          # 基础系统配置与断言
│   │   ├── boot/          # 启动引导
│   │   ├── users/         # 用户管理
│   │   ├── networking/    # 网络 + 透明代理
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
│   │   ├── development/   # CLI 工具、开发包、VS Code、dbgate
│   │   ├── desktop/       # Kitty 与 mpv 桌面用户配置
│   │   └── opencode/      # OpenCode AI 助手
```

- [ ] **步骤 8：运行最终格式化**

运行：`nix fmt`

预期：PASS，命令退出码为 `0`。

- [ ] **步骤 9：运行 flake 检查**

运行：`nix flake check`

预期：PASS，所有 checks 成功，包括：

- `checks.x86_64-linux.example-workstation`
- `checks.x86_64-linux.example-gpu-workstation`
- `checks.x86_64-linux.example-wsl`
- `checks.x86_64-linux.example-wsl-dev-container`
- `checks.x86_64-linux.example-server`
- `checks.x86_64-linux.example-server-dev-container`

- [ ] **步骤 10：运行验收 eval 汇总**

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
  baseModule = {
    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
    };
  };
  mk = args: flake.lib.mkHost ({
    system = "x86_64-linux";
    inherit user;
    secrets.sops.enable = false;
    extraModules = [ baseModule ];
  } // args);
  workstation = mk {
    hostname = "acceptance-workstation";
    profiles = [ "workstation-base" ];
    roles = [ "development" ];
    machine.boot.mode = "uefi";
  };
  gpuWorkstation = mk {
    hostname = "acceptance-gpu-workstation";
    profiles = [ "workstation-base" ];
    roles = [ "ai-accelerated" ];
    machine = {
      boot.mode = "uefi";
      nvidia.enable = true;
    };
  };
  server = mk {
    hostname = "acceptance-server";
    profiles = [ "server-base" ];
    roles = [ ];
    machine.boot.mode = "uefi";
  };
  wsl = flake.lib.mkHost {
    hostname = "acceptance-wsl";
    system = "x86_64-linux";
    inherit user;
    profiles = [ "wsl-base" ];
    roles = [ ];
    machine.wsl.enable = true;
    secrets.sops.enable = false;
  };
in
{
  workstationDesktop = workstation.config.platform.desktop.enable;
  workstationPlasma = workstation.config.services.desktopManager.plasma6.enable;
  workstationKitty = workstation.config.home-manager.users.example.programs.kitty.enable;
  workstationMpv = workstation.config.home-manager.users.example.programs.mpv.enable;
  gpuDesktopXserver = gpuWorkstation.config.services.xserver.enable;
  gpuDrivers = gpuWorkstation.config.services.xserver.videoDrivers;
  serverDesktop = server.config.platform.desktop.enable;
  wslDesktop = wsl.config.platform.desktop.enable;
}
'
```

预期：PASS，输出：

```json
{"gpuDesktopXserver":true,"gpuDrivers":["nvidia"],"serverDesktop":false,"workstationDesktop":true,"workstationKitty":true,"workstationMpv":true,"workstationPlasma":true,"wslDesktop":false}
```

- [ ] **步骤 11：提交文档与最终验证变更**

如果已获用户授权提交，使用 `git-commit` skill 提交：

```text
docs: document plasma workstation defaults
```

---

## 验收映射

| spec 验收标准 | 覆盖任务 |
| --- | --- |
| 使用 `workstation-base` 的主机默认启用 KDE Plasma 6、SDDM Wayland、PipeWire、Bluetooth、CUPS、Flatpak、KDE Connect、Fcitx5 拼音 | 任务 1、任务 2、任务 6 |
| 预置软件和字体按 spec 清单安装 | 任务 2 |
| 主用户获得 Kitty 和重度定制 mpv 配置 | 任务 3 |
| `ai-accelerated`/NVIDIA 工作站不再因为 `services.xserver.enable` 冲突而 eval 失败 | 任务 5、任务 6 |
| WSL 主机不会被 workstation 桌面配置污染 | 任务 1、任务 5、任务 6 |
| README 与平台选项定义一致 | 任务 6 |
| VS Code 和 dbgate 归属 fullstack 开发能力而非基础桌面 | 任务 2、任务 4、任务 6 |

## 最终交付检查

- `modules/shared/options.nix` 存在 `platform.desktop.enable`、`platform.desktop.environment`、`platform.desktop.apps.enable`。
- `profiles/workstation-base.nix` 使用 `profileDefault` 默认启用 Plasma 与完整应用集。
- `modules/nixos/desktop/plasma.nix` 被 `modules/nixos/default.nix` 导入。
- `modules/home/desktop/default.nix` 被 `modules/home/default.nix` 导入。
- `modules/home/development/packages.nix` 的 `fullstackPackages` 包含 `vscode` 和 `dbgate`。
- `modules/nixos/hardware/nvidia.nix` 没有设置 `services.xserver.enable = false`。
- `modules/nixos/core/assertions.nix` 包含 WSL 禁止桌面断言。
- `README.md` 说明 `workstation-base` 默认 KDE Plasma 桌面和开发 GUI 边界。
- `nix fmt` 通过。
- `nix flake check` 通过。
