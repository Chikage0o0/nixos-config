# 从 myConfig 迁移到 platform.*

本仓库已完成平台化重写，旧 `myConfig` 选项模块（`lib/options.nix`、`lib/home-options.nix`）已被删除。所有主机配置改由 `mkHost` host 声明 + `config.platform.*` 结构化选项管理。

## 核心变化

- **旧方式：** 在 `default.nix` 中写 `myConfig = { ... }` 扁平选项块
- **新方式：** 在 `flake.nix` 中用 `public.lib.mkHost { ... }` 声明式定义主机，所有字段通过 `mkHost` 参数传入，内部规范化到 `config.platform.*`

## 字段映射表

| 旧 myConfig 字段                        | 新 platform 字段 / mkHost 参数                         |
| --------------------------------------- | ------------------------------------------------------ |
| `myConfig.username`                     | `platform.user.name`                                   |
| `myConfig.userFullName`                 | `platform.user.fullName`                               |
| `myConfig.userEmail`                    | `platform.user.email`                                  |
| `myConfig.sshPublicKey`                 | `platform.user.sshPublicKey`                           |
| `myConfig.nixMaxJobs`                   | `platform.nix.maxJobs`                                 |
| `myConfig.isWSL`                        | `platform.machine.wsl.enable`                          |
| `myConfig.bootMode`                     | `platform.machine.boot.mode`                           |
| `myConfig.grubDevice`                   | `platform.machine.boot.grubDevice`                     |
| `myConfig.isNvidia`                     | `platform.machine.nvidia.enable`（或 `ai-accelerated` role） |
| `myConfig.enableDae`                    | `platform.networking.transparentProxy.enable`          |
| `myConfig.daeConfigFile`                | `platform.networking.transparentProxy.configFile`      |
| `myConfig.enableCockpit`                | `platform.services.cockpit.enable`（或 `remote-admin` role） |
| `myConfig.cockpitExtraOrigins`          | `platform.services.cockpit.extraOrigins`               |
| `myConfig.extraHosts`                   | `platform.networking.extraHosts`                       |
| `myConfig.opencodeSettings`             | `platform.home.opencode.settings`                      |
| `myConfig.opencodeConfigFile`           | `platform.home.opencode.configFile`                    |
| `myConfig.sshSopsSecrets`               | `platform.home.sshAgent.sopsSecrets`                   |
| `myConfig.enableSshAgent`               | `platform.home.sshAgent.enable`                        |
| `myConfig.isWSL` + enableCockpit 默认逻辑 | `platform.services.cockpit.enable`（不再有 WSL 隐含规则） |

## 迁移示例

### 旧 myConfig 写法

```nix
# hosts/my-host/default.nix
{ lib, ... }:
let
  isWSL = false;
  isNvidia = true;
in
{
  imports = [ ./hardware-configuration.nix ];

  myConfig = {
    username = "chikage";
    userFullName = "Chikage";
    userEmail = "user@example.com";
    sshPublicKey = "ssh-ed25519 ...";
    isWSL = isWSL;
    bootMode = "uefi";
    isNvidia = isNvidia;
    enableDae = true;
  };
}
```

### 新 mkHost 写法

```nix
# flake.nix
let
  commonUser = {
    name = "chikage";
    fullName = "Chikage";
    email = "user@example.com";
    sshPublicKey = "ssh-ed25519 ...";
  };
in
{
  nixosConfigurations.workstation = public.lib.mkHost {
    hostname = "workstation";
    system = "x86_64-linux";
    user = commonUser;
    profiles = [ "workstation-base" ];
    roles = [
      "development"
      "ai-tooling"
      "ai-accelerated"
      "container-host"
    ];
    machine = {
      boot.mode = "uefi";
      nvidia.enable = true;
    };
    networking.transparentProxy.enable = true;
    home.opencode.enable = true;
    secrets.sops = {
      enable = true;
      defaultFile = ./hosts/workstation/secrets.yaml;
      ageKeyFile = "/home/chikage/.config/sops/age/keys.txt";
      secrets."dae/config" = { };
    };
    hardwareModules = [ ./hosts/workstation/hardware-configuration.nix ];
    extraModules = [ ./hosts/workstation ];
  };
}
```

## 主机特定模块的变化

旧的主机特定 `default.nix` 由 `extraModules` 替代。主机模块中不再用 `config.myConfig`，改为读取 `config.platform`。

### 旧写法

```nix
# hosts/my-host/default.nix
{ config, lib, ... }:
{
  users.users.${config.myConfig.username}.hashedPasswordFile =
    lib.mkIf (config ? sops) config.sops.secrets."user/hashedPassword".path;
}
```

### 新写法

```nix
# hosts/workstation/default.nix
{ config, lib, ... }:
{
  users.users.${config.platform.user.name}.hashedPasswordFile =
    lib.mkIf (config ? sops) config.sops.secrets."user/hashedPassword".path;
}
```

## 常见问题

### Q: 如何同时启用 Cockpit？

A: 将 `remote-admin` role 加入 `roles` 列表，或在 `services.cockpit.enable = true`。

### Q: 旧的 `enableCockpit` 默认排除 WSL 的逻辑还在吗？

A: 不再保留。新版本中 Cockpit 默认关闭，需要显式启用。这与旧版 `enableCockpit` 默认值为 `!isWSL` 的行为不同——如果你原本在 WSL 上意外启用了 Cockpit，迁移后它会自动关闭；如果你在物理机上需要它，必须显式启用。

### Q: 在哪里配置 sops？

A: 在 `mkHost` 的 `secrets.sops` 参数中集中管理，不再分散在主机 `default.nix` 中。

### Q: 我还能用 `config.myConfig` 吗？

A: 不能。`lib/options.nix` 和 `lib/home-options.nix` 已被删除，尝试引用 `config.myConfig` 会导致 eval 错误。所有字段已迁移到 `config.platform.*`。
