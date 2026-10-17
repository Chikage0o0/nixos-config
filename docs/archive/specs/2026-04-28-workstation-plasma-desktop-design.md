# workstation-base KDE Plasma 桌面与预置软件设计

## 背景

`profiles/workstation-base.nix` 当前只声明工作站机器形态和少量服务默认值，没有桌面环境。目标是让所有使用 `workstation-base` profile 的 NixOS 工作站默认获得可直接使用的 KDE Plasma 日常桌面，同时保持现有平台分层：profile 只给平台选项默认值，NixOS/Home Manager 模块负责落地服务、软件包和用户配置。

## 目标

- 所有 `workstation-base` 主机默认启用 KDE Plasma 6 桌面环境。
- 桌面范围采用“日常完整”：不仅启用桌面壳，还预装常用 GUI 应用、字体、输入法、硬件管理 GUI 和应用分发工具。
- 支持 Microsoft Edge、WPS Office CN、Windows 兼容字体和其他已确认的 unfree 软件；仓库当前 `mkHost` 已启用 `nixpkgs.config.allowUnfree = true`。
- 将 Kitty 和 mpv 的用户配置放入 Home Manager，而不是只安装裸包。
- 将 VS Code 和 dbgate 放入开发相关 role/module，不放入 `workstation-base` 基础桌面。
- 保持 WSL/server/generic profile 不默认启用桌面。

## 非目标

- 不支持 GNOME、Xfce 或多桌面环境切换；第一版 `platform.desktop.environment` 只支持 `"plasma"`。
- 不预装聊天通讯软件、游戏/Wine/Proton 工具、同步云盘客户端、专用 PDF 查看器。
- 不做自动登录、主题、壁纸、面板布局、账户同步等个人化桌面定制。
- 不把数据库 GUI、IDE、容器 GUI、AI 客户端等开发工具塞进 `workstation-base`。

## 平台选项设计

新增 `platform.desktop` 选项组：

- `platform.desktop.enable`: bool，默认 `false`。
- `platform.desktop.environment`: enum，第一版只允许 `"plasma"`，默认 `"plasma"`。
- `platform.desktop.apps.enable`: bool，默认 `false`，控制是否启用日常完整桌面软件集，包括 GUI 应用、字体、输入法、硬件管理 GUI、应用分发工具、KDE Connect 以及 Kitty/mpv 的 Home Manager 配置。

`profiles/workstation-base.nix` 使用现有 `profileDefault = lib.mkOverride 1200` 设置：

- `platform.machine.class = "workstation"`
- `platform.machine.wsl.enable = false`
- `platform.desktop.enable = true`
- `platform.desktop.environment = "plasma"`
- `platform.desktop.apps.enable = true`

这样所有 workstation 默认获得 KDE Plasma 与预置软件；具体主机仍可通过更高优先级配置关闭桌面或应用集。

## NixOS 模块设计

新增 desktop NixOS 模块并由 `modules/nixos/default.nix` 导入。`platform.desktop.enable = true` 时启用桌面会话和基础硬件/音频能力；`platform.desktop.apps.enable = true` 时再启用日常完整应用集。模块职责包括：

- 启用 `services.xserver.enable`。
- 启用 `services.desktopManager.plasma6.enable`。
- 启用 `services.displayManager.sddm.enable` 和 `services.displayManager.sddm.wayland.enable`。
- 启用 `services.libinput.enable`。
- 启用 `xdg.portal.enable`。
- 启用 PipeWire 音频：`services.pipewire.enable`、ALSA、PulseAudio、JACK 兼容、WirePlumber、`security.rtkit.enable`。
- 启用蓝牙：`hardware.bluetooth.enable` 和 `hardware.bluetooth.powerOnBoot`。
- 启用打印：`services.printing.enable`。
- 在 `platform.desktop.apps.enable = true` 时启用 Flatpak：`services.flatpak.enable`。
- 在 `platform.desktop.apps.enable = true` 时启用 KDE Connect：`programs.kdeconnect.enable`，使用 NixOS 模块自动处理所需防火墙端口。
- 在 `platform.desktop.apps.enable = true` 时启用 Fcitx5 拼音输入法：`i18n.inputMethod.enable = true`、`i18n.inputMethod.type = "fcitx5"`，addons 包含 `kdePackages.fcitx5-chinese-addons` 和 `kdePackages.fcitx5-configtool`。
- 在 `platform.desktop.apps.enable = true` 时安装系统级 GUI 应用、字体和辅助工具。
- 使用 `environment.plasma6.excludePackages` 做 KDE 默认应用“适度瘦身”，第一版只排除已明确不需要或被替代的默认应用：`kdePackages.konsole`、`kdePackages.okular`、`kdePackages.elisa`、`kdePackages.dragon`。

## 预置系统软件清单

系统级预装软件包：

- 浏览器：`microsoft-edge`。
- 办公：`wpsoffice-cn`。
- 图像与截图：`kdePackages.gwenview`、`kdePackages.spectacle`、`gimp`。
- 基础工具：`kdePackages.dolphin`、`kdePackages.kate`、`kdePackages.ark`、`kdePackages.kcalc`。
- 压缩后端：`p7zip`、`unrar`。
- 密码管理：`bitwarden-desktop`。
- 网络与设备：通过 `programs.kdeconnect.enable` 启用 KDE Connect。
- 远程桌面：`remmina`。
- 系统工具：`kdePackages.plasma-systemmonitor`、`kdePackages.partitionmanager`、`kdePackages.filelight`。
- 硬件管理 GUI：`kdePackages.print-manager`、`kdePackages.bluedevil`、`kdePackages.plasma-nm`。
- 应用分发：`kdePackages.discover`、`appimage-run`，并启用 Flatpak 服务。
- 笔记写作：`obsidian`。
- 邮件：`thunderbird`。
- mpv 辅助工具：`yt-dlp`、`ffmpeg-full`、`mediainfo`。

不预装：微信、QQ、Telegram Desktop、Discord、VLC、Haruna、Elisa、OBS Studio、Okular、Steam、Lutris、Heroic、Bottles、Nextcloud Client、Syncthing Tray、OneDrive GUI、Insync。

## 字体设计

系统字体包：

- `noto-fonts-cjk-sans`
- `noto-fonts-cjk-serif`
- `noto-fonts-color-emoji`
- `sarasa-gothic`
- `nerd-fonts.fira-code`
- `corefonts`
- `vista-fonts`
- `vista-fonts-chs`

用途：

- Noto CJK 覆盖中文、日文、韩文基础显示。
- Noto Color Emoji 提供彩色 emoji。
- Sarasa Gothic 与 FiraCode Nerd Font 作为编程字体候选。
- corefonts、vista-fonts、vista-fonts-chs 提供 WPS/Office 文档常见 Windows 字体兼容，包括 Arial、Times New Roman、Calibri、Cambria、Consolas、Microsoft YaHei 等。

## Home Manager 桌面配置设计

新增 Home Manager desktop 模块并由 `modules/home/default.nix` 导入。该模块在 `platform.desktop.enable = true` 且 `platform.desktop.apps.enable = true` 时，为 `platform.user.name` 主用户配置 Kitty 和 mpv。

Kitty 配置：

- 启用 `programs.kitty.enable`。
- 默认字体使用 FiraCode Nerd Font。
- 保留 Sarasa Gothic 作为已安装编程/CJK 混排字体，供用户在编辑器或终端中手动切换。
- 配置保持克制，不做激进快捷键重映射。

mpv 配置：

- 启用 `programs.mpv.enable`。
- 安装脚本：`mpvScripts.uosc`、`mpvScripts.thumbfast`、`mpvScripts.mpris`、`mpvScripts.mpv-cheatsheet-ng`。
- 启用硬件解码自动安全模式、保存播放位置、现代 OSD、缩略图预览、媒体键集成。
- 配置常用字幕、音轨、倍速、章节、截图、逐帧、媒体信息快捷键。
- 键位以 mpv 默认习惯为基础增强：方向键快退快进，上下大步进，`[`/`]` 调倍速，`a` 切音轨，`s` 切字幕，`v` 开关字幕，`i` 显示媒体信息，`q` 保存退出。

## 开发 GUI 边界

`workstation-base` 不安装 VS Code 和 dbgate。开发 GUI 归属开发相关 role/module：

- 当 `platform.development.fullstack.enable = true` 时，在 `modules/home/development/packages.nix` 的 fullstack Home packages 中加入 `vscode` 和 `dbgate`。
- VS Code 和 dbgate 由 `fullstack-development` role 间接启用，而不是基础桌面包集合。

这样普通日常工作站不会因为基础桌面 profile 获得开发全家桶；开发主机通过 role 组合获得 IDE 和数据库客户端。

## NVIDIA 冲突处理

现有 `modules/nixos/hardware/nvidia.nix` 在启用 NVIDIA 时设置：

```nix
services.xserver = {
  enable = false;
  videoDrivers = [ "nvidia" ];
};
```

这会和 Plasma 桌面需要的 `services.xserver.enable = true` 冲突。设计改为 NVIDIA 模块只设置 `services.xserver.videoDrivers = [ "nvidia" ];` 以及 NVIDIA/CUDA 相关硬件能力，不再强制关闭 X server。没有桌面时，`services.xserver.enable` 仍保持 NixOS 默认 `false`。

## 断言与错误处理

新增或调整断言：

- WSL 主机不能启用 `platform.desktop.enable`。
- `platform.desktop.enable = true` 时，`platform.desktop.environment` 必须为 `"plasma"`。
- 透明代理、boot、NVIDIA/WSL 等现有断言保持不变。

这些断言在 eval 阶段失败，错误信息需要明确指出应关闭桌面或改用非 WSL profile。

## README 与示例更新

README 更新内容：

- `workstation-base` 描述改为物理工作站基础配置，默认包含 KDE Plasma 日常桌面。
- `platform` 选项表新增 `platform.desktop.enable`、`platform.desktop.environment`、`platform.desktop.apps.enable`。
- 增加日常预置软件摘要和开发 GUI 边界说明。

现有 example workstation 不需要显式添加桌面选项；通过 `profiles = [ "workstation-base" ]` 自动获得桌面。

## 验证计划

实现后运行：

```bash
nix fmt
nix flake check
```

现有 checks 覆盖：

- `example-workstation`：验证普通 Plasma 工作站、日常软件、字体、输入法、Home Manager 桌面配置。
- `example-gpu-workstation`：验证 Plasma 与 NVIDIA 模块不冲突。
- `example-wsl` 和 `example-wsl-dev-container`：验证 WSL 不默认启用桌面。
- `example-server` 和 `example-server-dev-container`：验证 server profile 不默认启用桌面。

## 验收标准

- 使用 `workstation-base` 的主机 eval 成功，并默认启用 KDE Plasma 6、SDDM Wayland、PipeWire、Bluetooth、CUPS、Flatpak、KDE Connect、Fcitx5 拼音。
- 预置软件和字体按本 spec 清单安装。
- 主用户获得 Kitty 和重度定制 mpv 配置。
- `ai-accelerated`/NVIDIA 工作站不再因为 `services.xserver.enable` 冲突而 eval 失败。
- WSL 主机不会被 workstation 桌面配置污染。
- README 与平台选项定义一致。
