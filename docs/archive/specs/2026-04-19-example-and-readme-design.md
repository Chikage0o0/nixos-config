# Example 创建与 README 重构设计

## 目标

在公开仓库 `nixos-config` 中创建完整可运行的 example，并重构 README，使新用户能快速理解和使用该项目。

## Example 设计

### 目录结构

```
example/
└── my-host/
    ├── README.md                  # 示例说明文档
    ├── flake.nix                  # 私有仓库 flake 模板
    ├── .sops.yaml                 # sops 密钥配置模板
    ├── deploy.sh                  # 部署脚本
    ├── hosts/
    │   └── my-host/
    │       ├── default.nix        # WSL 主机配置示例
    │       └── secrets.yaml       # sops 加密机密（占位）
    └── opencode-config.template.json  # OpenCode 配置模板
```

### 文件内容设计

#### flake.nix

从私有仓库的 flake.nix 简化而来，保留完整结构但使用 `path:` 引用本仓库：

- inputs: nixpkgs, nixos-config-public (path:../..), home-manager, nixos-wsl, sops-nix
- outputs: mkHost 函数，hostConfigs 映射 "my-host"
- 每个关键段落附中文注释说明用途

#### hosts/my-host/default.nix

基于私有仓库 `hosts/default/default.nix`，简化为 WSL 场景：

- isWSL=true, isNvidia=false, enableDae=false
- myConfig 使用占位用户信息（username="your_username" 等）
- 完整的 sops secrets 配置（user/hashedPassword, opencode/apiKey, ssh_private_key）
- sops.templates 生成 opencode-config.json
- home-manager 配置传递 myConfig

每个段落附带详细中文注释，解释"为什么这样做"而非"做了什么"。

#### .sops.yaml

简化版模板，仅包含 admin + 一个主机密钥：

- 注释说明如何生成 age 密钥
- 注释说明如何从 SSH host key 派生 age 密钥

#### deploy.sh

直接复用私有仓库的 deploy.sh。

#### opencode-config.template.json

简化版模板，保留结构但使用通用 provider：

- 仅保留一个 provider，使用 `__OPENCODE_API_KEY__` 占位符
- 注释说明如何自定义

## README 重构设计

### 结构

```
# NixOS Config Library
├── 徽章 + 一句话描述
├── 架构设计（双仓库分层图）
├── 快速开始
│   ├── 前置条件
│   ├── 1. 创建私有仓库（从 example 初始化）
│   ├── 2. 配置 sops 密钥
│   ├── 3. 编辑主机配置
│   ├── 4. 部署
│   └── 5. 添加新主机
├── 配置参考
│   ├── myConfig 完整选项表（NixOS 级别）
│   ├── myConfig 完整选项表（Home Manager 级别）
│   └── 功能开关说明
├── 高级用法
│   ├── 物理机 + NVIDIA + dae 配置
│   ├── 多主机管理
│   └── 自定义模块组合
├── 项目结构
├── 导出内容
└── 许可证
```

### 关键改进

1. **新增快速开始**：step-by-step 引导，从 example 初始化到部署
2. **配置参考**：将 myConfig 选项整理为结构化表格，标注必填/可选/默认值
3. **场景化示例**：物理机 + NVIDIA + dae 的配置差异说明
4. **保留现有内容**：架构图、项目结构树、导出内容表等保留并优化

## 约束

- 所有文档和注释使用中文
- example 中的敏感信息使用占位符
- README 面向"有 Linux 基础但 Nix 新手"和"有 Nix 经验的用户"双受众
- 不改变公开仓库的任何模块代码，仅新增 example 和重构 README
