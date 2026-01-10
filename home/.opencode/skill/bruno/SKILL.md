---
name: bruno
description: Bruno API 客户端专家指南。涵盖 .bru 语法、脚本 API (req/res)、断言 (assertions) 和配置。在编辑 Bruno 文件 (.bru)、管理集合或编写 API 测试时使用。
---

# Bruno API Client 技能

本技能提供 Bruno API Client 的详细参考文档，涵盖配置、语法、脚本编写及测试指南。

## 核心文档索引

详细文档位于本技能的 `docs/` 目录下：

### 配置与结构
- **[集合配置 (bruno.json)](docs/bruno-json-reference.md)**: `bruno.json` 完整 Schema，包含白名单、安全设置、代理及忽略规则。
- **[目录结构](docs/structure.md)**: 标准文件布局、环境文件、`folder.bru` 及 `.env` 集成。
- **[环境配置](docs/environments.md)**: 环境管理与变量使用指南。

### 语法与格式
- **[语法参考](docs/syntax.md)**: `.bru` 文件完整语法规范 (Meta, Http, Body, Auth, Vars 等 Block)。
- **[示例块](docs/example-block.md)**: 如何编写 `example` 块以保存请求/响应示例。

### 脚本与测试
- **[脚本 API](docs/scripting-api.md)**: `req` (Request), `res` (Response), `bru` (Context) 对象的完整 API 参考。包含方法签名及内置库 (axios, moment, lodash 等)。
- **[脚本指南](docs/scripts.md)**: Pre Request 和 Post Response 脚本的使用指南。
- **[断言参考](docs/assertions.md)**: 声明式断言 (`assert`) 操作符列表及 Chai `expect` 脚本测试语法。
- **[测试示例](docs/tests.md)**: 常见测试模式与用例。

### 命令行工具
- **[CLI 指南](docs/cli.md)**: Bruno CLI (`bru`) 的安装、命令参数、环境选择及报告生成。

### 高级用法
- **[高级示例](docs/examples.md)**: 请求链 (Request Chaining)、自定义加密 (HMAC)、JSON Schema 校验 (AJV) 及文件上传等场景。

## 快速参考

- **文件扩展名**: `.bru`
- **配置文件**: 集合根目录下的 `bruno.json`
- **脚本语言**: JavaScript (Node.js runtime)
- **内置库**: `axios`, `moment`, `lodash`, `cheerio`, `crypto-js` 等

## 使用建议

当需要编写 Bruno 脚本、修复 `.bru` 文件语法或查阅 API 时，请优先参考 [语法参考](docs/syntax.md) 和 [脚本 API](docs/scripting-api.md)。当你写完`.bru`后请使用cli进行测试bru是否正常工作。
