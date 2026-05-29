# Example - 私有 NixOS 配置仓库模板

这是 [nixos-config](https://github.com/Chikage0o0/nixos-config) 公共模块库的配套私有仓库模板。建议把整个 `nixos-config/example/my-host` 复制成自己的私有仓库，然后只在私有仓库里保存主机差异和加密后的 secrets。

模板预置三类主机，覆盖最常见起步场景：

| 主机 | 用途 | 重点展示 |
| --- | --- | --- |
| `wsl-dev` | NixOS-WSL 开发环境 | `wsl-base`、开发/AI/容器 role、OpenCode、ssh-agent secret、WSL age key 注入 |
| `server` | VPS/家用服务器 | `server-base`、Cockpit 远程管理、Podman、硬件配置 |
| `workstation` | 物理桌面工作站 | KDE Plasma、开发/AI/容器、OpenCode、ssh-agent secret、NVIDIA/CUDA |

所有主机都通过 `public.lib.mkHost` 声明：`profile` 描述机器形态，`role` 叠加功能能力，`hosts/<hostname>/default.nix` 只保存该主机自己的差异。

## 目录结构

```text
.
├── flake.nix                         # 私有仓库入口，定义 nixosConfigurations
├── .gitignore                         # 忽略 result、nixos.wsl 与明文 age key
├── .sops.yaml                        # sops recipient 与加密规则
├── deploy.sh                         # 本机部署脚本：switch / boot 二选一
├── scripts/
│   ├── add-host.sh                   # 生成 hosts/<hostname>/ 脚手架
│   ├── remote-deploy.sh              # 通过 SSH 远程 nixos-rebuild boot
│   ├── reinstall.sh                  # 通过 nixos-anywhere 重装远端主机（破坏性）
│   └── build-wsl.sh                  # 构建 NixOS-WSL 导入包 nixos.wsl
├── hosts/
│   ├── wsl-dev/
│   │   ├── default.nix               # WSL 专属配置
│   │   └── secrets.yaml              # 示例明文；实际使用前要用 sops 加密
│   ├── server/
│   │   ├── default.nix               # 服务器差异配置
│   │   ├── hardware-configuration.nix# 目标机生成的硬件配置占位
│   │   └── secrets.yaml
│   └── workstation/
│       ├── default.nix               # 桌面工作站差异配置
│       ├── hardware-configuration.nix
│       └── secrets.yaml
└── templates/
    └── opencode-config.template.json # OpenCode 配置模板，__OPENCODE_API_KEY__ 由 sops 注入
```

## 快速开始

### 1. 复制模板并初始化私有仓库

```bash
git clone https://github.com/Chikage0o0/nixos-config.git
cp -r nixos-config/example/my-host ~/my-nixos-config
cd ~/my-nixos-config
git init
```

如果你 fork 了公共模块库，修改 `flake.nix`：

```nix
inputs.nixos-config-public.url = "github:<you>/nixos-config";
```

### 2. 准备工具

```bash
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#age nixpkgs#ssh-to-age nixpkgs#sops nixpkgs#mkpasswd
```

### 3. 生成管理员 age key

管理员 key 用来在你的维护机器上编辑 secrets。

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

把输出的 `age1...` 公钥填到 `.sops.yaml` 的 `&admin`。

### 4. 准备主机 recipient

普通 NixOS 主机通常使用 SSH host key 派生 age recipient：

```bash
ssh-keyscan <target-host> 2>/dev/null | ssh-to-age
# 或在目标机本地执行：
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```

把输出填到 `.sops.yaml` 中对应主机的 `&server`、`&workstation` 等位置。

WSL 没有稳定的 SSH host key 启动流程，建议为每个 WSL host 单独生成 host age key：

```bash
age-keygen -o hosts/wsl-dev/age-key.txt
age-keygen -y hosts/wsl-dev/age-key.txt
```

- 将公钥填入 `.sops.yaml` 的 `&wsl-dev`。
- `hosts/wsl-dev/age-key.txt` 是明文私钥，模板已在 `.gitignore` 忽略；不要强行提交。
- 如要让 `scripts/build-wsl.sh` 自动注入 key，可用管理员公钥加密后托管：

  ```bash
  age -e -r <admin-age-public-key> \
    -o hosts/wsl-dev/age-key.txt.age \
    hosts/wsl-dev/age-key.txt
  ```

### 5. 编辑 `flake.nix`

至少修改 `commonUser`：

```nix
commonUser = {
  name = "your_username";
  fullName = "Your Name";
  email = "your@email.com";
  sshPublicKey = "ssh-ed25519 AAAA... user@host";
};
```

然后保留你需要的主机，删除暂时不用的 `nixosConfigurations`。常见组合：

- WSL：`profiles = [ "wsl-base" ];`，`machine.wsl.enable = true;`
- 服务器：`profiles = [ "server-base" ];`，按需加 `remote-admin`、`container-host`
- 桌面：`profiles = [ "workstation-base" ];`，按需加 `development`、`fullstack-development`、`ai-tooling`
- NVIDIA/CUDA：同时启用 `gpu-nvidia` 与 `ai-accelerated`

### 6. 填写并加密 secrets

模板中的 `hosts/*/secrets.yaml` 是占位明文，只用于说明结构。填入真实值后立即加密：

```bash
sops -e -i hosts/workstation/secrets.yaml
sops -e -i hosts/server/secrets.yaml
sops -e -i hosts/wsl-dev/secrets.yaml
```

以后编辑 secrets 用：

```bash
sops hosts/workstation/secrets.yaml
```

不要提交明文密码、API key、SSH 私钥或未加密的 `age-key.txt`。

### 7. 生成硬件配置

物理机和服务器需要在目标机上生成硬件配置，再替换模板占位文件：

```bash
sudo nixos-generate-config --show-hardware-config \
  > hosts/workstation/hardware-configuration.nix
```

WSL 主机不需要 `hardware-configuration.nix`。

### 8. 评估配置

新文件尚未提交时，先让 flake 能看到它们：

```bash
git add --intent-to-add .
nix eval .#nixosConfigurations.workstation.config.networking.hostName
nix eval .#nixosConfigurations.wsl-dev.config.networking.hostName
```

## 脚本用法

### `./deploy.sh [hostname]` - 本机部署

适合在当前机器已经是 NixOS、且要部署的 `hostname` 与 flake 中主机名一致时使用。

```bash
./deploy.sh workstation
# 不传参数时默认使用当前 hostname：
./deploy.sh
```

脚本会检查 `hosts/<hostname>/` 是否存在，然后询问：

- `switch`：立即切换到新系统
- `boot`：只设置为下次启动生效，更适合远程或高风险变更

### `scripts/add-host.sh <hostname> [system] [kind]` - 添加主机脚手架

```bash
scripts/add-host.sh laptop x86_64-linux linux
scripts/add-host.sh wsl-work x86_64-linux wsl
```

脚本会创建：

- `hosts/<hostname>/default.nix`
- `hosts/<hostname>/secrets.yaml`
- 非 WSL 主机额外创建 `hosts/<hostname>/hardware-configuration.nix`

脚本不会自动修改 `flake.nix` 或 `.sops.yaml`，因为这两处通常需要人工决定 profile/role、recipient 和加密规则。运行后按输出的 `mkHost` 片段补到 `flake.nix`。

### `scripts/remote-deploy.sh [选项] <ssh-target>` - 远程部署

```bash
scripts/remote-deploy.sh root@1.2.3.4
scripts/remote-deploy.sh -u admin -p 2222 1.2.3.4
scripts/remote-deploy.sh --dry-run root@server.example.com
```

脚本流程：

1. SSH 到目标机执行 `hostname`
2. 检查该 hostname 是否存在于 `nixosConfigurations`
3. 本地 dry-run 构建目标系统
4. 执行 `nixos-rebuild boot --target-host ... --use-remote-sudo`

默认使用 `boot` 而不是 `switch`，避免远程网络/SSH 立刻中断。确认构建成功后再重启远端机器。

### `scripts/build-wsl.sh <hostname>` - 构建 WSL 导入包

```bash
scripts/build-wsl.sh wsl-dev
```

输出当前目录下的 `nixos.wsl`。如果存在以下任一文件，脚本会把 host age key 注入到镜像的 `/var/lib/sops-nix/age/keys.txt`：

- `hosts/<hostname>/age-key.txt.age`：用管理员 age key 加密后的 host key，可提交
- `hosts/<hostname>/age-key.txt`：明文 host key，不要提交

导入示例：

```powershell
wsl --import NixOS .\NixOS .\nixos.wsl --version 2
wsl -d NixOS
```

### `scripts/reinstall.sh <flake-host> <target-host> [disk-device]` - 远程重装

这是破坏性脚本，只在你已经确认目标机器、磁盘设备和 disko 配置后使用：

```bash
scripts/reinstall.sh server root@1.2.3.4 /dev/disk/by-id/<disk-id>
```

注意：

- 目标主机配置通常需要包含 disko。
- 提供 `disk-device` 时，脚本会先在远端确认它是整盘而不是分区。
- 脚本会要求输入 `flake-host` 再继续，避免误触。
- 执行前确认 `.sops.yaml` 和对应 `secrets.yaml` 已包含目标机 recipient，否则安装后可能无法解密 secrets。

## OpenCode 配置模板

`templates/opencode-config.template.json` 中的 `__OPENCODE_API_KEY__` 会由 `hosts/wsl-dev/default.nix` 和 `hosts/workstation/default.nix` 通过 `sops.templates` 替换为 `opencode/apiKey` secret，并把生成文件路径传给 `platform.home.opencode.configFile`。

如果你不使用 OpenCode：

1. 从对应主机的 `roles` 中删除 `ai-tooling`（按需）。
2. 删除 `home.opencode.enable = true;`。
3. 删除 `secrets.sops.secrets."opencode/apiKey"` 和 secrets 文件中的 `opencode.apiKey`。
4. 删除主机 `default.nix` 里的 `sops.templates."opencode-config.json"` 与 `platform.home.opencode.configFile`。

## 添加新主机检查清单

1. 运行 `scripts/add-host.sh <hostname> [system] [linux|wsl]`。
2. 在 `flake.nix` 添加 `public.lib.mkHost` 声明。
3. 为非 WSL 主机替换 `hardware-configuration.nix`。
4. 在 `.sops.yaml` 添加主机 age recipient 和 `hosts/<hostname>/secrets.yaml` 规则。
5. 编辑并加密 `hosts/<hostname>/secrets.yaml`。
6. 运行 `git add --intent-to-add .`，再执行 `nix eval .#nixosConfigurations.<hostname>.config.networking.hostName`。
7. 本机部署用 `./deploy.sh <hostname>`；远程部署用 `scripts/remote-deploy.sh <ssh-target>`。

## 注意事项

- `secrets.yaml` 必须用 sops 加密后再提交。
- 明文 `hosts/<hostname>/age-key.txt`、SSH 私钥、API key 和密码哈希不要提交。
- `hardware-configuration.nix` 应由目标机器生成；模板中的空文件只保证 flake 可评估。
- 如果目标机器是传统 BIOS，在 `mkHost.machine.boot` 中设置 `mode = "bios"` 并指定 `grubDevice`。
- 高风险操作（远程重装、磁盘设备覆盖）执行前先确认 SSH 目标、flake host、磁盘路径和 secrets recipient。
