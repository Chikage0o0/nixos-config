# 目录结构 (Directory Structure)

Bruno 采用 "File System as Database" 的理念。这意味着你的文件夹结构就是你的 API 集合结构。

## 标准项目布局

```text
my-bruno-collection/
├── bruno.json                  # [必须] 集合元数据与配置
├── README.md                   # 集合说明文档
├── .gitignore                  # Git 忽略规则
├── .env                        # [私有] 本地环境变量与密钥 (不要提交!)
├── environments/               # 环境配置目录
│   ├── production.bru          # 生产环境
│   ├── staging.bru             # 测试环境
│   └── local.bru               # 本地开发环境
├── 01_Onboarding/              # 文件夹 (对应 UI 中的 Folder)
│   ├── folder.bru              # [可选] 文件夹级别的配置 (Script/Vars)
│   ├── Sign Up.bru             # 请求文件
│   └── Login.bru
├── 02_Account/
│   ├── Get Profile.bru
│   └── Update Profile.bru
└── assets/                     # 存放上传测试用的文件 (推荐)
    └── test_image.png
```

## 关键文件类型详解

### 1. 集合根配置 (`bruno.json`)
这是识别 Bruno 集合的标志文件。
- 详见 [Bruno JSON 参考](./bruno-json-reference.md)。

### 2. 环境文件 (`environments/*.bru`)
定义特定环境下的变量集。

**`production.bru` 示例:**
```bru
vars {
  base_url: https://api.production.com
  api_key: {{process.env.PROD_API_KEY}}
}
```

### 3. 请求文件 (`*.bru`)
实际的 API 请求定义。
- 详见 [语法参考](./syntax.md)。

### 4. 文件夹配置 (`folder.bru`)
如果你需要在文件夹层级定义通用的脚本或变量（例如，该文件夹下的所有请求都需要特定的 Auth Header），可以在该目录下创建一个 `folder.bru`。

**内容结构:**
- `meta`: 定义文件夹名称 (可选，默认使用目录名)。
- `auth`: 定义文件夹级的认证方式。
- `script`: 定义文件夹级的 `pre-request` / `post-response`。
- `vars`: 定义文件夹级变量。

```bru
meta {
  name: Onboarding Flow
}

auth {
  mode: bearer
}

auth:bearer {
  token: {{italent_access_token}}
}

script:pre-request {
  // 此脚本会在该文件夹下的每个请求前执行
  console.log("Entering Onboarding folder...");
}
```

### 5. `collection.bru` (已废弃/旧版)
在早期版本中可能存在，现已被 `bruno.json` 和分散的 `.bru` 结构取代。

---
[< 返回主页](./README.md)
