# SSH Agent 会话级修复 实施计划

> **给代理执行者：** REQUIRED SUB-SKILL: 使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务执行本计划。步骤使用复选框 `- [ ]` 语法追踪。

**目标：** 把当前 shell 级 `ssh-agent` 改成会话级 OpenSSH agent，让 `SSH_AUTH_SOCK` 稳定进入 GUI 与 shell，并在登录后自动加载配置的 `sops` 私钥，同时清理 Tabby 与 zsh 中已经无效的旧逻辑。

**架构：** 新增一个独立的 Home Manager `ssh-agent` 模块，统一启用 `services.ssh-agent.enable`、写入 `systemd.user.sessionVariables.SSH_AUTH_SOCK`，并通过一次性用户级 service 在 agent 启动后执行 `ssh-add`。`modules/home/shell/default.nix` 只保留 shell/SSH 客户端配置，不再承担 agent 生命周期；`pkgs/tabby/default.nix` 删除无效的 `SSH_AUTH_SOCK` wrapper，把环境传播问题收束到会话层解决。

**技术栈：** NixOS Flakes, Home Manager, `systemd --user`, OpenSSH, sops-nix, Nix eval checks

---

## 文件结构与职责

| 路径 | 职责 |
| --- | --- |
| `lib/platform/checks.nix` | 增加一条 eval 级回归检查，锁定会话级 `ssh-agent`、`SSH_AUTH_SOCK` 传播与自动 `ssh-add` 的期望行为。 |
| `modules/home/default.nix` | 导入新的 `./ssh-agent` Home Manager 模块。 |
| `modules/home/ssh-agent/default.nix` | 会话级 agent 的核心实现：启用 `services.ssh-agent`、设置 `systemd.user.sessionVariables`、声明自动加载私钥的一次性 service。 |
| `modules/home/shell/default.nix` | 删除 shell 内启动 agent / `ssh-add` 的旧逻辑，保留 zsh 与 SSH 客户端配置。 |
| `modules/shared/options.nix` | 保留 `platform.home.sshAgent` 选项结构，但把文案更新为会话级语义。 |
| `pkgs/tabby/default.nix` | 删除无效的 `SSH_AUTH_SOCK` wrapper 代码，只保留 `--no-sandbox` 包装。 |

## 全局执行规则

- 每个任务开始前先运行 `git status --short`，只确认当前工作树状态，不回滚其他代理或用户的改动。
- 所有 Nix 代码改动后运行一次 `nix fmt`，确认格式化没有引入无关变更。
- 先做失败验证，再改代码，再做通过验证；没有 RED，就不要写实现。
- 不在本计划执行过程中自动创建 git commit；只有用户明确要求时，才通过 `git-commit` skill 单独提交。
- 注释、计划说明和变更说明保持中文；命令、路径、选项名和标识符保持原样。

---

### 任务 1：先补一条失败的 ssh-agent 会话级回归检查

**文件：**
- 修改：`lib/platform/checks.nix`

- [ ] **步骤 1：在 checks 中新增 ssh-agent 会话级断言**

在 `mkKsmserverLoginModeCheck` 后插入：

```nix
  mkSshAgentSessionCheck =
    system: name: host:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
      homeCfg = config.config.home-manager.users.${host.user.name};
      addKeysService = homeCfg.systemd.user.services.ssh-add-sops-keys or { };
      after = addKeysService.Unit.After or [ ];
      envLines = addKeysService.Service.Environment or [ ];
      execStart = addKeysService.Service.ExecStart or "MISSING";
      wantedBy = addKeysService.Install.WantedBy or [ ];
      zshInit = homeCfg.programs.zsh.initContent or "";
      pass =
        homeCfg.services.ssh-agent.enable
        && (homeCfg.systemd.user.sessionVariables.SSH_AUTH_SOCK or null) == "$XDG_RUNTIME_DIR/ssh-agent"
        && builtins.hasAttr "ssh-add-sops-keys" homeCfg.systemd.user.services
        && lib.elem "ssh-agent.service" after
        && lib.elem "default.target" wantedBy
        && lib.any (line: lib.hasInfix "SSH_AUTH_SOCK=%t/ssh-agent" line) envLines
        && !(lib.hasInfix "ssh-agent -s" zshInit);
    in
    pkgs.runCommand "${name}-ssh-agent-session"
      {
        pass = if pass then "1" else "0";
        sessionSock = homeCfg.systemd.user.sessionVariables.SSH_AUTH_SOCK or "MISSING";
        sshAgentEnabled = if homeCfg.services.ssh-agent.enable then "1" else "0";
        afterText = lib.concatStringsSep "," after;
        wantedByText = lib.concatStringsSep "," wantedBy;
        envText = lib.concatStringsSep " | " envLines;
        inherit execStart zshInit;
      }
      ''
        if [[ "$pass" != 1 ]]; then
          echo "Expected session-level ssh-agent wiring for ${name}." >&2
          echo "sshAgentEnabled=$sshAgentEnabled" >&2
          echo "sessionSock=$sessionSock" >&2
          echo "after=$afterText" >&2
          echo "wantedBy=$wantedByText" >&2
          echo "env=$envText" >&2
          echo "execStart=$execStart" >&2
          echo "zshInit=$zshInit" >&2
          exit 1
        fi
        touch $out
      '';
```

在 `hosts = { ... };` 中追加一台专用 eval host：

```nix
    example-workstation-ssh-agent = base // {
      hostname = "example-workstation-ssh-agent";
      profiles = [ "workstation-base" ];
      roles = [ "development" ];
      machine.boot.mode = "uefi";
      home.sshAgent.sopsSecrets = [ "ssh_private_key" ];
      secrets.sops = {
        enable = true;
        defaultFile = ../../example/my-host/hosts/workstation/secrets.yaml;
        ageKeyFile = "/tmp/example-age-key";
        secrets.ssh_private_key = {
          owner = user.name;
          mode = "0400";
        };
      };
    };
```

在最终导出的 checks attrset 里追加：

```nix
    example-workstation-ssh-agent-session =
      mkSshAgentSessionCheck system "example-workstation-ssh-agent"
        hosts.example-workstation-ssh-agent;
```

- [ ] **步骤 2：运行失败验证，确认新检查现在是 RED**

运行：

```bash
nix build .#checks.x86_64-linux.example-workstation-ssh-agent-session
```

预期：FAIL，输出包含至少一项未满足条件，通常会看到：

```text
Expected session-level ssh-agent wiring for example-workstation-ssh-agent.
sshAgentEnabled=0
sessionSock=MISSING
```

---

### 任务 2：引入新的 Home Manager ssh-agent 模块

**文件：**
- 新增：`modules/home/ssh-agent/default.nix`
- 修改：`modules/home/default.nix`

- [ ] **步骤 1：新增 `modules/home/ssh-agent/default.nix`**

创建文件：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform.home.sshAgent;
  socket = config.services.ssh-agent.socket;
  addKeysScript = pkgs.writeShellScript "ssh-add-sops-keys" ''
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/${socket}"

${lib.concatMapStringsSep "\n" (name: ''
    if [ -f "/run/secrets/${name}" ]; then
      ${lib.getExe' pkgs.openssh "ssh-add"} "/run/secrets/${name}" >/dev/null
    fi
'') cfg.sopsSecrets}
  '';
in
{
  config = lib.mkIf cfg.enable {
    services.ssh-agent.enable = true;

    systemd.user.sessionVariables.SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/${socket}";

    systemd.user.services.ssh-add-sops-keys = lib.mkIf (cfg.sopsSecrets != [ ]) {
        Unit = {
          Description = "Load configured SSH keys into ssh-agent";
          Wants = [ "ssh-agent.service" ];
          After = [ "ssh-agent.service" ];
          PartOf = [ "ssh-agent.service" ];
        };
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          Environment = [ "SSH_AUTH_SOCK=%t/${socket}" ];
          ExecStart = toString addKeysScript;
        };
        Install.WantedBy = [ "default.target" ];
      };
  };
}
```

- [ ] **步骤 2：导入新模块**

将 `modules/home/default.nix` 改为：

```nix
{ ... }:
{
  imports = [
    ../shared/options.nix
    ./core/base.nix
    ./git
    ./shell
    ./ssh-agent
    ./development/cli-tools.nix
    ./development/packages.nix
    ./development/mirrors.nix
    ./opencode
    ./desktop
  ];
}
```

- [ ] **步骤 3：运行通过验证，确认新模块已经把 agent/service 结构接上**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "ssh-agent-probe";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "workstation-base" ];
    roles = [ "development" ];
    machine.boot.mode = "uefi";
    home.sshAgent.sopsSecrets = [ "ssh_private_key" ];
    secrets.sops = {
      enable = true;
      defaultFile = ./example/my-host/hosts/workstation/secrets.yaml;
      ageKeyFile = "/tmp/example-age-key";
      secrets.ssh_private_key = { };
    };
    extraModules = [
      {
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      }
    ];
  };
  homeCfg = host.config.home-manager.users.example;
in
{
  sshAgentEnable = homeCfg.services.ssh-agent.enable;
  sessionSock = homeCfg.systemd.user.sessionVariables.SSH_AUTH_SOCK;
  hasAddKeysService = builtins.hasAttr "ssh-add-sops-keys" homeCfg.systemd.user.services;
  addKeysExecStart = homeCfg.systemd.user.services.ssh-add-sops-keys.Service.ExecStart;
}'
```

预期：PASS，输出至少满足以下结构：

```json
{
  "addKeysExecStart": "/nix/store/...-ssh-add-sops-keys",
  "hasAddKeysService": true,
  "sessionSock": "$XDG_RUNTIME_DIR/ssh-agent",
  "sshAgentEnable": true
}
```

---

### 任务 3：清理 shell 旧逻辑并把选项文案改成会话级语义

**文件：**
- 修改：`modules/home/shell/default.nix`
- 修改：`modules/shared/options.nix`

- [ ] **步骤 1：删除 `zsh` 中启动 agent 和 `ssh-add` 的旧逻辑**

把 `modules/home/shell/default.nix` 的文件头和 `programs.zsh` 块改成下面的形态：

```nix
{
  config,
  lib,
  ...
}:
let
  cfg = config.platform;
in
{
  config = lib.mkIf cfg.home.shell.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        ll = "ls -l";
        clean = "nix-collect-garbage -d";
      };
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        forwardAgent = false;
        addKeysToAgent = "yes";
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
    };
  };
}
```

重点是删掉：

- `loadSopsSecrets` 这个 `let` 绑定。
- `programs.zsh.initContent = lib.mkIf cfg.home.sshAgent.enable '' ... '';` 整段。
- 不再从 shell 里执行 `eval "$(ssh-agent -s)"` 或 `ssh-add`。

- [ ] **步骤 2：更新共享 options 的描述文案**

把 `modules/shared/options.nix` 中 `platform.home.sshAgent` 这一段的描述修改为：

```nix
      sshAgent = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "是否启用会话级 OpenSSH agent 集成。";
        };

        sopsSecrets = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "登录后自动加载到 ssh-agent 的 sops secret 名称列表。";
        };
      };
```

- [ ] **步骤 3：运行通过验证，确认回归检查转绿且 shell 旧逻辑已消失**

运行：

```bash
nix build .#checks.x86_64-linux.example-workstation-ssh-agent-session
```

预期：PASS，并生成对应结果路径，不再出现：

```text
sshAgentEnabled=0
sessionSock=MISSING
ssh-agent -s
```

---

### 任务 4：清理 Tabby 包里无效的 `SSH_AUTH_SOCK` wrapper

**文件：**
- 修改：`pkgs/tabby/default.nix`

- [ ] **步骤 1：运行失败验证，确认无效 wrapper 仍然存在**

运行：

```bash
rg -n "SSH_AUTH_SOCK" pkgs/tabby/default.nix
```

预期：PASS，并看到当前 wrapper 中仍有这类内容：

```text
106:       --run '[ -n "''${SSH_AUTH_SOCK:-}" ] && export SSH_AUTH_SOCK'
```

- [ ] **步骤 2：删除无效 wrapper，只保留 `--no-sandbox`**

把 `pkgs/tabby/default.nix` 的 `makeWrapper` 调整为：

```nix
    makeWrapper $out/lib/tabby/tabby $out/bin/tabby \
      --add-flags "--no-sandbox"
```

- [ ] **步骤 3：运行通过验证，确认源码已清理且包仍能求值构建**

运行：

```bash
if rg -n "SSH_AUTH_SOCK" pkgs/tabby/default.nix; then
  echo "Unexpected SSH_AUTH_SOCK wrapper remained" >&2
  exit 1
fi

nix build .#packages.x86_64-linux.tabby --no-link
```

预期：PASS，第一段命令无输出，`nix build` 成功结束。

---

### 任务 5：做最终仓库验证和登录后手工冒烟

**文件：**
- 无新增实现文件；只运行格式化、repo 级验证和会话级手工验证。

- [ ] **步骤 1：格式化所有 Nix 改动**

运行：

```bash
nix fmt
```

预期：PASS，格式化完成且没有报错。

- [ ] **步骤 2：运行最终自动验证**

运行：

```bash
nix build \
  .#checks.x86_64-linux.example-workstation-ssh-agent-session \
  .#packages.x86_64-linux.tabby \
  --no-link
```

预期：PASS，两个目标都成功构建。

- [ ] **步骤 3：在实际主机应用配置并重新进入新会话**

对消费这个仓库的实际主机执行对应的切换命令，然后重新登录图形会话。这个步骤不能省略，因为 `systemd.user.sessionVariables` 需要进入新的用户会话环境后才会稳定体现在 GUI 程序里。

预期：新会话中的 GUI 应用和 shell 都继承同一个 `SSH_AUTH_SOCK`。

- [ ] **步骤 4：做登录后的会话级冒烟验证**

重新登录后运行：

```bash
systemctl --user show-environment | rg '^SSH_AUTH_SOCK='
printf '%s\n' "$SSH_AUTH_SOCK"
ssh-add -l
systemctl --user status ssh-agent ssh-add-sops-keys --no-pager
```

预期：

```text
SSH_AUTH_SOCK=/run/user/<uid>/ssh-agent
/run/user/<uid>/ssh-agent
<至少 1 把已加载的 ED25519 key>
Active: active
```

- [ ] **步骤 5：从桌面启动 Tabby 做最终手工验证**

从应用启动器或桌面菜单直接启动 Tabby，不要从已经带环境变量的终端里启动。然后使用现有 SSH profile 重试连接。

预期：

- Tabby 的 SSH profile 不再报 `Failed to authenticate using agent`。
- 不再出现 `Invalid argument`。
- 认证流程直接通过 agent 完成。

如果这一步失败，先收集：

```bash
systemctl --user show-environment | rg '^SSH_AUTH_SOCK='
journalctl --user -u ssh-agent -u ssh-add-sops-keys -n 100 --no-pager
```

并优先确认当前 GUI 会话是否已经重新登录到新环境。
