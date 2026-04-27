# 从 root Nix 环境切换到本仓库配置

## 适用场景

这篇教程适用于下面这类机器：

- 已经装好了一个最小可启动的 NixOS
- 当前主要还是用 `root` 直接操作系统和 Nix
- 还没有把系统切到 `flake` + `nixos-rebuild --flake` 工作流
- 希望尽快接入本仓库推荐的“私有仓库 + NixOS + Home Manager + sops”结构
- 希望以后重装时，能靠私有仓库和密钥快速恢复

这篇教程**不**覆盖 ISO 制作、分区、安装器操作和磁盘布局设计；它只处理“系统已经装好之后，第一次接到这套配置”的阶段。

## 切换完成后的状态

完成后，你会得到：

- 一个基于 `example/my-host` 初始化出来的私有配置仓库
- 当前主机进入 `nixos-rebuild --flake` 管理
- 普通用户、Home Manager 和常用工具由配置统一接管
- 机密通过 `sops-nix` 管理，不再散落在本地明文文件里
- 以后重装时，只要恢复私有仓库、`hardware-configuration.nix` 和 age 密钥，就能再次切回这套配置

## 路线选择

### 路线 A：系统里只有 `root`

推荐先临时创建你以后要长期使用的普通用户，再以该用户完成后续步骤。

原因很简单：示例配置里默认把 sops 的 age 密钥放在 `/home/<user>/.config/sops/age/keys.txt`。如果你从第一天就用目标用户来放密钥，后面不需要再搬一次。

```bash
TARGET_USER="your_username"

useradd -m -G wheel "$TARGET_USER"
passwd "$TARGET_USER"

su - "$TARGET_USER"
```

后文默认你已经切到这个目标普通用户的 shell。

### 路线 B：系统里已经有普通用户

如果你在安装 NixOS 时已经顺手创建好了长期使用的普通用户，直接切到那个用户继续即可。

后文默认这个普通用户就是未来要在 `mkHost` host 声明中 `user.name` 里填的用户。

## 1. 准备一次性工具环境

首次切换前，先临时拉起一个带工具的 shell。这里直接临时启用 `nix-command` 和 `flakes`，避免你先手改系统全局配置。

```bash
nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#git nixpkgs#gh nixpkgs#age nixpkgs#ssh-to-age nixpkgs#sops nixpkgs#mkpasswd
```

后面的命令默认都在这个 shell 里执行。

## 2. 从 example 初始化你的私有仓库

先拉公共仓库，再把 `example/my-host` 复制成你自己的私有配置目录。

```bash
git clone https://github.com/Chikage0o0/nixos-config.git ~/src/nixos-config-public

cp -r ~/src/nixos-config-public/example/my-host ~/my-nixos-config
cd ~/my-nixos-config

git init
```

如果你已经有自己的私有 Git 仓库，这一步就把 `~/my-nixos-config` 推上去；后面重装时，你恢复的就是它，而不是公开仓库本身。

## 3. 先把示例主机名改成你的机器

example 默认使用 `my-host`。正式接管之前，建议直接换成你的真实主机名，避免后面每次部署都记一个示例名。

```bash
HOSTNAME_FINAL="your-hostname"

mv hosts/my-host "hosts/$HOSTNAME_FINAL"
```

然后同步改这几处：

1. `flake.nix`
   把 `hostConfigs` 里的键从 `"my-host"` 改成 `"$HOSTNAME_FINAL"`，并把路径改成 `./hosts/$HOSTNAME_FINAL`。

2. `.sops.yaml`
   把主机别名 `&my-host` 改成 `&$HOSTNAME_FINAL`，并把加密规则路径从 `hosts/my-host/secrets.yaml` 改成 `hosts/$HOSTNAME_FINAL/secrets.yaml`。

如果你懒得改，也可以保留 `my-host`；那后面所有 `.<hostname>` 的地方都改用 `my-host` 即可。

## 4. 把示例从 WSL 改成真实 NixOS 主机

`example/my-host/hosts/my-host/default.nix` 默认是 WSL 示例。对于刚重装好的真实 NixOS 主机，至少要做下面两件事。

### 4.1 复制硬件配置

```bash
cp /etc/nixos/hardware-configuration.nix "hosts/$HOSTNAME_FINAL/"
```

### 4.2 修改主机配置

编辑 `hosts/$HOSTNAME_FINAL/default.nix`：

1. 把 `isWSL = true;` 改成 `isWSL = false;`
2. 物理机默认走 `grub + UEFI`，一般不需要额外改启动器设置
3. 如果机器是传统 BIOS，再额外设置 `bootMode = "bios";` 和 `grubDevice = "/dev/disk/by-id/...";`
4. 按机器实际情况设置 `isNvidia = true;` 或 `false;`
5. 把 `username`、`userFullName`、`userEmail`、`sshPublicKey` 改成你的真实值
6. 如果你是从“只有 root”的路径进入，这里的 `username` 应该和刚才手动创建的普通用户保持一致

这里不要删除这段导入逻辑：

```nix
imports =
  [ ]
  ++ lib.optionals isWSL [ inputs.nixos-wsl.nixosModules.default ]
  ++ (if isWSL then [ ] else [ ./hardware-configuration.nix ]);
```

因为物理机正是靠 `isWSL = false` 时自动导入 `./hardware-configuration.nix`。

如果 `/boot` 是独立文件系统，NixOS 的 `grub` 仍可能把内核复制到 `/boot`；切到 `grub` 可以减少 `systemd-boot` 对 EFI 分区的压力，但最终效果仍取决于你的分区布局。

## 5. 准备 SSH 密钥

示例配置里既需要公钥填入 `mkHost` host 声明的 `user.sshPublicKey`，也会把私钥通过 sops 注入系统。所以如果你还没有自己的 SSH key，先生成一对。

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "$USER@$(hostname)"
```

然后：

1. 把 `~/.ssh/id_ed25519.pub` 的内容填到 `flake.nix` 中 `mkHost` host 声明的 `user.sshPublicKey`
2. 后面把 `~/.ssh/id_ed25519` 的内容填到 `hosts/$HOSTNAME_FINAL/secrets.yaml` 的 `ssh_private_key`

如果你已经有现成 SSH key，直接复用即可。

## 6. 配置 sops 所需的 age 密钥

### 6.1 生成管理员 age 密钥

```bash
mkdir -p ~/.config/sops/age
chmod 700 ~/.config/sops ~/.config/sops/age

age-keygen -o ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt

age-keygen -y ~/.config/sops/age/keys.txt
```

最后一条命令会打印你的 age 公钥，把它填到 `.sops.yaml` 里的 `&admin`。

### 6.2 读取当前主机的 age 公钥

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
```

把输出填到 `.sops.yaml` 里对应当前主机的公钥位置。

## 7. 填写并加密机密文件

编辑 `hosts/$HOSTNAME_FINAL/secrets.yaml`，至少保证下面三个值已经填上：

```yaml
user:
  hashedPassword: <这里填 sha-512 密码哈希>
opencode:
  apiKey: <这里填真实 key，或先填占位字符串>
ssh_private_key: |
  -----BEGIN OPENSSH PRIVATE KEY-----
  ...
  -----END OPENSSH PRIVATE KEY-----
```

其中密码哈希可以这样生成：

```bash
mkpasswd -m sha-512
```

然后把明文文件加密回去：

```bash
sops -e --input-type yaml --output-type yaml \
  "hosts/$HOSTNAME_FINAL/secrets.yaml" > /tmp/secrets.yaml

mv /tmp/secrets.yaml "hosts/$HOSTNAME_FINAL/secrets.yaml"
```

以后如果要继续编辑这个文件，直接用：

```bash
sops "hosts/$HOSTNAME_FINAL/secrets.yaml"
```

## 8. 第一次切换到 flake 配置

现在已经可以做第一次 `switch`。因为当前系统还没永久开启 flakes，第一次不要直接跑 `./deploy.sh`，而是显式给这次构建注入临时配置。

```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake ".#$HOSTNAME_FINAL"
```

这一步成功后：

- `nix.settings.experimental-features` 会由本仓库配置接管
- 普通用户、Home Manager、zsh、CLI 工具和 opencode 配置会一并落下去
- 后续再部署就可以直接在仓库根目录运行 `./deploy.sh` 了

第一次切换完成后，建议立刻把当前目录提交到你自己的私有仓库。

## 9. 切换后做最小检查

重新登录到目标普通用户后，至少确认下面几件事：

```bash
hostname
id
sudo -n true
test -f ~/.config/sops/age/keys.txt && echo ok
```

如果这些都正常，再执行一次：

```bash
./deploy.sh
```

它应该已经不再需要你手动补 `experimental-features`。

## 10. 以后重装时的最短恢复路径

以后这台机器重装时，最短路径其实很固定：

1. 先装一个最小可启动的 NixOS
2. 如果系统里只有 `root`，先按本文最前面的方式临时创建目标普通用户
3. 恢复你的私有仓库到本地
4. 把 age 私钥恢复到 `~/.config/sops/age/keys.txt`
5. 用当前系统新生成的 `/etc/nixos/hardware-configuration.nix` 覆盖仓库里的同名文件
6. 再跑一次首次切换命令：

```bash
sudo env NIX_CONFIG="experimental-features = nix-command flakes" \
  nixos-rebuild switch --flake ".#$HOSTNAME_FINAL"
```

真正需要妥善备份的东西只有三类：

- 你的私有配置仓库
- `~/.config/sops/age/keys.txt`
- 你想继续使用的 SSH 私钥

只要这三样在，重装后的恢复成本就会非常低。
