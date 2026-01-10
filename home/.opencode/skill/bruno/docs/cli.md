# Bruno CLI 参考指南

Bruno CLI (`bru`) 允许你在命令行中运行 API 集合，实现自动化测试及 CI/CD 集成。

## 安装

```bash
npm install -g @usebruno/cli
```

## 运行集合 (`bru run`)

进入你的集合根目录（包含 `bruno.json` 的目录），执行：

```bash
bru run
```

### 运行模式 (安全模式 vs 开发者模式)

**注意 (v3.0.0+ 变更)**: 默认运行在 **安全模式 (Safe Mode)**。
如果你的脚本需要使用外部 npm 包或进行文件系统操作 (fs)，必须显式开启 **开发者模式**：

```bash
bru run --sandbox=developer
```

### 指定运行范围

- **运行特定文件夹**: `bru run <文件夹名称>` (例如: `bru run Auth`)
- **运行单个请求**: `bru run <请求文件>.bru` (例如: `bru run Auth/Login.bru`)
- **混合运行**: `bru run folder1 request2.bru`

### 数据驱动测试

- **使用 CSV 数据**: `bru run --csv-file-path data.csv`
- **使用 JSON 数据**: `bru run --json-file-path data.json`
- **迭代次数**: `bru run --iteration-count 5` (如果不指定数据文件，仅重复运行)

### 环境配置

- **指定环境文件 (.bru)**: `bru run --env-file environments/dev.bru`
- **指定环境名称**: `bru run --env Local` (需在集合目录下)
- **指定全局环境**: `bru run --global-env Production`
- **覆盖环境变量**: `bru run --env-var TOKEN=123 --env-var HOST=api.test`

### 过滤请求

- **包含标签**: `bru run --tags=smoke,sanity` (运行包含任一标签的请求)
- **排除标签**: `bru run --exclude-tags=wip` (跳过包含任一标签的请求)
- **仅运行有测试的请求**: `bru run --tests-only`

### 生成报告

- **JSON 报告**: `bru run --reporter-json results.json`
- **JUnit 报告**: `bru run --reporter-junit results.xml` (适用于 CI 集成)
- **HTML 报告**: `bru run --reporter-html results.html`

### 其他常用选项

- `--parallel`: 并行运行请求（注意：可能影响依赖顺序的测试）。
- `--bail`: 遇到第一个失败即停止运行。
- `--insecure`: 允许不安全的 SSL 连接（忽略证书错误）。
- `--delay <ms>`: 在请求之间添加延迟（毫秒）。
- `--cacert <file>`: 指定 CA 证书文件。

## 常见工作流示例

### CI/CD 流水线集成
在 CI 环境中运行所有测试，使用生产环境配置，并生成 JUnit 报告以便展示：
```bash
bru run --env Production --reporter-junit results.xml --sandbox=developer
```

### 本地调试
仅运行 `Auth` 文件夹下的请求，使用本地环境，且一报错就停止：
```bash
bru run Auth --env Local --bail
```
