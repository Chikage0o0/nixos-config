# Example - 私有配置仓库模板

这是 [nixos-config](https://github.com/Chikage0o0/nixos-config) 公共模块库的配套私有仓库模板。

本模板预置了三台主机示例：

- **wsl-dev** — WSL 开发环境，含全栈开发工具、AI 工具和 Podman
- **server** — 服务器，含远程管理和 Podman
- **workstation** — 物理工作站，含全栈开发、AI 工具、Podman、NVIDIA/CUDA

所有主机使用 `public.lib.mkHost` 声明式定义，profile + role 自由组合。

## 快速开始

### 1. 初始化仓库

```bash
# 复制整个 example 目录为你的私有仓库
cp -r example/my-host ~/my-nixos-config
cd ~/my-nixos-config

# 初始化 git
git init
git add .
git commit -m "init: from nixos-config example"
```

### 2. 生成 age 密钥

```bash
# 进入包含所需工具的 shell
nix shell nixpkgs#age nixpkgs#ssh-to-age nixpkgs#sops

# 生成管理员 age 密钥对
age-keygen -o ~/.config/sops/age/keys.txt
# 查看公钥，稍后填入 .sops.yaml
age-keygen -y ~/.config/sops/age/keys.txt
```

### 3. 获取主机 age 公钥

在目标主机（要部署 NixOS 的机器）上执行：

```bash
# 方法一：通过 ssh-keyscan
ssh-keyscan localhost 2>/dev/null | ssh-to-age

# 方法二：直接读取 host key
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```

将输出的 age 公钥填入 `.sops.yaml` 对应主机的密钥位置。

### 4. 编辑配置

1. 编辑 `.sops.yaml` - 填入管理员和主机公钥
2. 编辑 `flake.nix` - 修改 `commonUser` 中的用户名、邮箱、SSH 公钥等，或调整 profile/role 组合
3. 编辑 `hosts/<hostname>/secrets.yaml` - 填写真实密码和密钥
4. 编辑 `templates/opencode-config.template.json` - 自定义 AI 模型配置

#### 主机声明示例

```nix
public.lib.mkHost {
  hostname = "workstation";
  system = "x86_64-linux";
  user = commonUser;
  profiles = [ "workstation-base" ];
  roles = [
    "development"
    "fullstack-development"
    "ai-tooling"
    "container-host"
    "ai-accelerated"
  ];
  machine = {
    boot.mode = "uefi";
    nvidia.enable = true;
  };
  # ... sops, extraModules, hardwareModules
}
```

### 5. 加密机密文件

```bash
# 加密 secrets.yaml（.sops.yaml 配置正确后）
sops -e --input-type yaml --output-type yaml \
  hosts/workstation/secrets.yaml > /tmp/secrets.yaml
mv /tmp/secrets.yaml hosts/workstation/secrets.yaml

# 验证加密成功
cat hosts/workstation/secrets.yaml
# 应看到 sops metadata 和加密后的内容
```

### 6. 部署

```bash
# 确保当前主机名与 nixosConfigurations 中的键一致
hostname

./deploy.sh
```

如果当前主机是物理机（非 WSL），确保已复制 `hardware-configuration.nix` 到对应主机目录。

## 添加新主机

1. 在 `flake.nix` 的 `nixosConfigurations` 中添加新的 `mkHost` 声明
2. 在 `hosts/` 下创建新目录，如 `hosts/laptop/`
3. 非 WSL 环境需要将 `hardware-configuration.nix` 放入主机目录
4. 在 `.sops.yaml` 中添加新主机密钥和加密规则
5. 为新主机创建并加密 `secrets.yaml`
6. 如果使用传统 BIOS，在 `machine.boot` 中设置 `mode = "bios"` 和 `grubDevice`

## 目录结构

```
.
├── flake.nix          # Flake 入口，含 mkHost 主机声明
├── .sops.yaml         # sops 密钥配置
├── deploy.sh          # 部署脚本
├── hosts/
│   ├── wsl-dev/
│   │   ├── default.nix            # 主机特定配置
│   │   └── secrets.yaml           # sops 加密的机密文件
│   ├── server/
│   │   ├── default.nix
│   │   ├── hardware-configuration.nix
│   │   └── secrets.yaml
│   └── workstation/
│       ├── default.nix
│       ├── hardware-configuration.nix
│       └── secrets.yaml
├── templates/
│   └── opencode-config.template.json   # OpenCode 配置模板
└── README.md
```

## 注意事项

- `secrets.yaml` **必须**用 sops 加密后才能提交到 git
- `hardware-configuration.nix` 由 `nixos-generate-config` 自动生成，不要手动编辑
- 修改 `flake.nix` 中的 `nixos-config-public.url` 可以指向你自己的 fork
- 如果目标机器是传统 BIOS，在 `mkHost` 的 `machine.boot` 中设置 `mode = "bios"` 并指定 `grubDevice`
