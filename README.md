# NixOS Config

[![NixOS](https://img.shields.io/badge/NixOS-unstable-blue.svg?logo=nixos&logoColor=white)](https://nixos.org)
[![CUDA](https://img.shields.io/badge/CUDA-12.x-green.svg?logo=nvidia&logoColor=white)](https://developer.nvidia.com/cuda-toolkit)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

这是一个基于 **NixOS Flakes** 构建的高度定制化、生产力导向的开发环境配置。它专为 **AI 研发**、**CUDA 加速** 以及 **全栈开发** 场景设计，集成了透明代理、自动化 Git 工作流及现代化终端工具。

---

## ✨ 核心亮点

- 🚀 **AI/CUDA 赋能**: 一键开启 NVIDIA 闭源驱动与 CUDA Toolkit 环境，支持 TensorRT 开发。
- 🛠️ **声明式变量管理**: 通过 `vars.nix` 统一管理个人配置（用户名、SSH、代理、硬件开关），实现逻辑与数据分离。
- 🌐 **透明网络体验**: 基于 **dae (eBPF)** 的系统级透明代理，配合内核态分流，海外资源访问如丝般顺滑。
- ⚡ **现代化 CLI**: 预装 `eza`, `zoxide`, `fzf`, `bat`, `lazygit` 等工具，配合 `zsh` + `starship` 打造极致终端体验。
- 🔐 **安全第一**: 强制 SSH 密钥登录，集成 `nix-ld` 以兼容运行非原生二进制程序（如 VSCode Server）。
- 🐳 **全栈就绪**: 内置 Docker 容器环境、`uv` (Python)、`bun` (JS/TS) 等现代开发工具链。

---

## 📂 项目结构

```bash
nixos-config/
├── flake.nix             # Flakes 入口，定义依赖与系统节点
├── vars.nix.example      # vars 模板 (可复制为本地 vars.nix)
├── vars.nix              # 本地私有配置 (建议放入 .gitignore，不提交)
├── configuration.nix     # 系统级配置 (内核、网络、基础服务)
├── home.nix              # 用户级配置 (Home Manager, CLI, Git)
├── modules/
│   └── nvidia.nix        # NVIDIA 显卡与 CUDA 驱动模块
├── dae/
│   └── config.nix        # dae 透明代理分流逻辑
└── pkgs/
    └── v2ray-rules-dat/  # 自动更新的 GeoIP/GeoSite 规则
```

---

## 🛠️ 快速开始

### 1. 首次安装：必须放置到固定路径（默认）

本配置默认会从真实文件系统读取 `vars.nix`，并自动推导路径为：

- `/home/<真实用户>/nixos-config/vars.nix`

因此首次安装请把仓库克隆到 `~/nixos-config`：

```bash
git clone https://github.com/your-username/nixos-config.git ~/nixos-config
cd ~/nixos-config
```

如果你不想放在 `~/nixos-config`，也可以用环境变量覆盖（见第 3 步）。

### 2. 自定义 `vars.nix`

`vars.nix` 建议保持为本地私有文件（可被 `.gitignore` 忽略）。请从模板创建并填写你的个人信息：

```bash
cp vars.nix.example vars.nix
```

```nix
{
  username = "your_name";         # 登录用户名
  sshPublicKey = "ssh-ed25519..."; # SSH 公钥 (用于登录与 Git 签名)
  isNvidia = true;                # 是否启用 NVIDIA/CUDA 环境
  daeNodes = {
    my_node = "vless://...";      # 你的代理节点
  };
}
```

> 说明：本项目的 `flake.nix` 会直接从文件系统读取 `vars.nix`，因此即使 `vars.nix` 被 `.gitignore` 忽略也不会影响使用。

### 3. 应用并部署

执行以下命令应用配置（首次执行需 `sudo`）：

```bash
# 部署系统 (节点名为 dev-machine)
sudo nixos-rebuild switch --flake .#dev-machine --impure
```

如果你的仓库不在 `~/nixos-config`，请用 `NIXOS_CONFIG_DIR` 覆盖 `vars.nix` 所在目录（并保留环境变量给 sudo）：

```bash
NIXOS_CONFIG_DIR="/path/to/nixos-config" \
  sudo --preserve-env=NIXOS_CONFIG_DIR \
  nixos-rebuild switch --flake /path/to/nixos-config#dev-machine --impure
```

---

## ⌨️ 常用快捷指令

系统内置了多个简化日常维护的别名：

| 指令           | 作用                                    |
| :------------- | :-------------------------------------- |
| `update`       | 更新系统配置并同步最新的 GeoIP 代理规则 |
| `update-geoip` | 仅更新 dae 的分流规则数据               |
| `clean`        | 清理旧版本的 Nix 生成产物，释放磁盘空间 |
| `ll` / `la`    | 使用 `eza` 展示增强型文件列表           |
| `lg`           | 打开 `lazygit` 终端界面                 |

---

## 🔧 常见问题排查 (FAQ)

**Q: 如何在 NixOS 上运行下载的二进制文件？**
A: 本配置已启用 `nix-ld`。大部分预编译程序（如 VSCode Server, Github Copilot）可直接运行。

**Q: NVIDIA 显卡没有生效？**
A: 请确保 `vars.nix` 中 `isNvidia = true;`，并重启系统以加载内核模块。使用 `nvidia-smi` 验证。

**Q: 代理无法连接？**
A: 检查 `dae` 服务状态：`systemctl status dae`。确保 `vars.nix` 中的节点链接格式正确。

---

## 📜 许可证

基于 [MIT License](LICENSE) 开源。欢迎 Fork 并定制属于你的 NixOS 环境！
