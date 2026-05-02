# SSH Agent 会话级修复设计

## 背景

当前仓库把 `ssh-agent` 的启动和私钥加载逻辑写在 `modules/home/shell/default.nix` 的 `programs.zsh.initContent` 里。这种实现只在 shell 启动后才创建并导出 `SSH_AUTH_SOCK`，因此命令行里的 `ssh` 可用，但图形会话启动的应用无法稳定继承同一个 agent 环境。

Tabby 上游在 Linux 下不会自行发现 agent，只会直接读取 GUI 进程环境里的 `process.env.SSH_AUTH_SOCK`。现场已经验证：

- 当前 `ssh-agent` 和私钥本身是正常的，`ssh-add -l`、`ssh -T git@github.com` 都成功。
- 在已带正确 `SSH_AUTH_SOCK` 的终端里直接启动 `tabby` 后，SSH profile 可以工作。
- `systemctl --user show-environment` 当前没有 `SSH_AUTH_SOCK`，说明用户级 systemd / GUI 会话环境未拿到该变量。

因此，本问题的根因不是密钥、socket 权限或 Tabby 打包失败，而是 agent 仍停留在“shell 级”，没有变成“登录会话级”。

## 用户已确认的边界

- 做永久修复，不做只依赖启动顺序的临时补丁。
- 一并清理当前 shell 中启动 agent 的旧逻辑。
- 继续使用 OpenSSH agent，不切换到 `gpg-agent`。
- 继续自动加载 `sops` 提供的私钥。
- 目标是 GUI 和 shell 都直接可用，尤其是 Tabby 的 SSH profile 可用。

## 决策摘要

本设计采用以下固定决策：

- 使用 Home Manager 的 `services.ssh-agent.enable = true` 创建用户级 `ssh-agent` service。
- 通过 Home Manager 的 `systemd.user.sessionVariables` 显式把 `SSH_AUTH_SOCK` 固定为 `%t/ssh-agent` 对应的运行时路径，确保 GUI 会话和 `systemctl --user` 环境都能拿到一致的 socket。
- 把“自动加载 `sops` 私钥”从 `zsh` 启动脚本迁移到用户级 systemd 一次性服务，在 agent 可用后执行 `ssh-add`。
- 保留 `platform.home.sshAgent` 选项组，但将其语义收敛为“是否启用会话级 agent 集成”和“要自动加载哪些 `sops` 私钥”。
- 清理 `pkgs/tabby/default.nix` 中对 `SSH_AUTH_SOCK` 的无效 wrapper 逻辑，只保留与 Tabby 运行本身相关的包装参数。

## 目标

- 登录后自动启动单一、稳定的 OpenSSH agent。
- `SSH_AUTH_SOCK` 在 shell、用户级 systemd、Plasma/GUI 程序之间保持一致。
- Tabby 这类 GUI 程序启动时即可拿到正确的 `SSH_AUTH_SOCK`。
- 指定的 `sops` 私钥在登录后自动加载进 agent，无需手动 `ssh-add`。
- 删除当前 `zsh` 中的 agent 启动副作用，避免 shell 启动顺序继续影响 SSH 能力。
- Tabby 包定义不再携带看似处理 `SSH_AUTH_SOCK`、但实际上无法解决 GUI 环境问题的 wrapper 代码。

## 非目标

- 不切换到 `gpg-agent` 或其他 agent 实现。
- 不为每个 GUI 应用单独写 wrapper 注入 `SSH_AUTH_SOCK`。
- 不引入基于 `dbus-update-activation-environment` 或 `systemctl --user import-environment` 的时序型补丁。
- 不改动现有 `programs.ssh` 的主机配置语义。
- 不把私钥内容改成由 Nix store 管理；仍然从 `/run/secrets/<name>` 读取。

## 任务规模判断

该任务预计至少修改以下文件：

- `modules/home/shell/default.nix`
- `modules/shared/options.nix`
- `modules/home/default.nix` 或新增其导入的子模块
- `pkgs/tabby/default.nix`

同时大概率新增一份 Home Manager 用户级 service 模块文件，用于承载 `ssh-agent` 和自动 `ssh-add` 逻辑。整体超过 3 个文件，属于大任务，应先写 spec，再写实施计划。

## 文件与模块边界

### `modules/home/shell/default.nix`

保留现有 `programs.zsh`、`programs.ssh`、`programs.starship`、`programs.direnv` 结构，但删除 `programs.zsh.initContent` 中这段职责：

- 探测 agent 状态
- 启动 `ssh-agent`
- 在 shell 启动时执行 `ssh-add`

原因是这些行为已经不应依赖 shell 生命周期。

### `modules/shared/options.nix`

保留 `platform.home.sshAgent.enable` 与 `platform.home.sshAgent.sopsSecrets`，但更新描述，使其表达的是“会话级 OpenSSH agent 集成”和“自动加载到 agent 的 secrets”，而不是“shell 启动时自动启动 agent”。

第一版不新增复杂选项，如自定义 socket 路径、额外 agent 参数、手动 service 名称覆盖等，因为当前需求只需要一个统一、稳定的默认方案。

### 新的 Home Manager SSH Agent 模块

新增独立模块，例如 `modules/home/ssh-agent/default.nix`，并由 `modules/home/default.nix` 导入。该模块负责：

- 在 `platform.home.sshAgent.enable = true` 时启用 `services.ssh-agent.enable = true`。
- 明确设置 `systemd.user.sessionVariables.SSH_AUTH_SOCK`，值为 agent 对应的运行时 socket 路径。
- 声明一次性用户级 service，在 `ssh-agent.service` 可用后运行 `ssh-add`，把 `platform.home.sshAgent.sopsSecrets` 指向的 `/run/secrets/<name>` 加入 agent。

这层模块是永久修复的核心实现位置。

## 会话级 Agent 设计

### Agent 提供方式

采用 Home Manager 自带的 `services.ssh-agent.enable`，而不是继续手写 `eval "$(ssh-agent -s)"`。原因：

- 它天然以 `systemd --user` service 形式运行，更符合 GUI 会话共享同一 agent 的需求。
- 它避免每开一个 shell 就重新探测或重建 agent 状态。
- 它和 Home Manager 本身的用户态配置边界一致，便于后续维护。

### `SSH_AUTH_SOCK` 注入方式

除了启用 `services.ssh-agent.enable`，还必须显式把 `SSH_AUTH_SOCK` 写入用户会话环境。固定做法是通过 `systemd.user.sessionVariables` 设置该变量，让用户级 systemd 环境和从该环境派生的 GUI 程序都指向同一个 socket。

这样解决两个问题：

- shell 外启动的应用在启动时就有正确的 `SSH_AUTH_SOCK`
- 后续检查 `systemctl --user show-environment` 时，能直接看到稳定值，便于验证和排障

### 私钥自动加载方式

私钥自动加载不再放在 `zsh` 的 `initContent` 中，而是迁移到独立的一次性用户级 service。该 service：

- 只在 `platform.home.sshAgent.enable = true` 时存在。
- 在 agent 已启动后运行。
- 遍历 `platform.home.sshAgent.sopsSecrets`，对存在的 `/run/secrets/<name>` 执行 `ssh-add`。
- 不因单个 secret 缺失而导致整个用户会话失败。

这种设计让“agent 生命周期”和“登录后补充身份”的职责分开：前者由 `ssh-agent.service` 负责，后者由一次性导入 service 负责。

## Tabby 包清理

`pkgs/tabby/default.nix` 当前 wrapper 中的：

```nix
--run '[ -n "''${SSH_AUTH_SOCK:-}" ] && export SSH_AUTH_SOCK'
```

不会让 GUI 启动的 Tabby 获得新的 agent 环境，它只会在 Tabby 进程已经带有该变量时再次导出同值，因此没有实际修复意义。

本设计删除这段 wrapper 逻辑，仅保留 `--no-sandbox` 等与程序运行直接相关的参数。这样能减少误导性代码，让 agent 问题回归到正确的会话层解决。

## 验证标准

实现完成后，至少要验证以下结果：

- `systemctl --user show-environment` 中存在 `SSH_AUTH_SOCK`。
- 登录后的普通 shell 中 `echo $SSH_AUTH_SOCK` 指向相同 socket。
- `ssh-add -l` 可列出自动加载的 key。
- 从桌面环境直接启动的 Tabby，其 SSH profile 能通过 agent 完成认证。
- `pkgs/tabby/default.nix` 中不再保留无效的 `SSH_AUTH_SOCK` wrapper 逻辑。

## 风险与约束

- 自动 `ssh-add` 的用户级 service 需要正确处理 `sopsSecrets` 为空、secret 文件缺失或 key 已加载等情况，避免无意义失败。
- `SSH_AUTH_SOCK` 必须与 `services.ssh-agent.enable` 实际创建的 socket 路径保持一致，不能写成与 service 默认值不一致的硬编码路径。
- 该修复主要依赖重新登录或刷新用户会话环境后生效；验证步骤需要明确区分“配置已生成”和“当前登录会话已更新”两个阶段。

## 实施后的用户工作流

修复落地后，预期工作流应简化为：

1. `home-manager switch` / 系统切换生成新的用户级服务和会话环境配置。
2. 重新登录图形会话，或以能刷新用户会话环境的方式进入新会话。
3. 无需手动 `eval "$(ssh-agent -s)"`。
4. shell、Git、Tabby 和其他 GUI SSH 客户端共用同一个 agent。
