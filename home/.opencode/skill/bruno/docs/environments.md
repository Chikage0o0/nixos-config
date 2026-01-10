# 环境与变量 (Environments & Variables)

Bruno 提供了灵活的变量系统，支持环境变量、集合变量、文件夹变量和请求级变量。

## 变量层级与优先级
变量解析遵循就近原则 (优先级从高到低)：
1. **请求级变量** (定义在 Request `vars` 块中)
2. **文件夹级变量**
3. **环境级变量** (当前选中的 Environment)
4. **集合级变量** (Root Collection Variables)
5. **全局/进程变量**

## 定义环境文件

环境文件通常位于 `environments/` 目录下，例如 `environments/dev.bru`。

```bru
vars {
  base_url: https://api-dev.example.com
  api_key: secret_key_123
  max_retries: 3
}
```

## 在请求中使用变量

使用双花括号 `{{variable_name}}` 语法引用变量。

```bru
get {
  url: {{base_url}}/users
}

headers {
  Authorization: Bearer {{api_key}}
}
```

## 动态变量 (Dynamic Variables)
Bruno 内置了一些伪变量，用于生成随机数据：

- `{{$randomUUID}}`
- `{{$randomEmail}}`
- `{{$randomFirstName}}`
- `{{$timestamp}}`

## 密钥管理 (.env 集成)

为了安全起见，不要将敏感密钥直接硬编码在 `.bru` 文件中。Bruno 支持从 `.env` 文件加载密钥。

1. 在集合根目录创建 `.env` 文件：
   ```env
   SECRET_TOKEN=my-super-secret-token
   ```

2. 在环境文件 (`environments/dev.bru`) 中引用它：
   ```bru
   vars {
     base_url: https://api.dev.com
     auth_token: {{process.env.SECRET_TOKEN}}
   }
   ```
   *注意：使用 `{{process.env.VAR_NAME}}` 语法访问。*

## 脚本中操作变量

在脚本中，你可以使用 `bru` 对象来获取或设置变量：

```javascript
// 获取变量
const url = bru.getEnvVar("base_url");

// 设置环境变量 (运行时修改)
bru.setEnvVar("current_token", "new-value");

// 设置集合变量
bru.setVar("global_id", 123);
```

---

[< 返回配置语法](./syntax.md) | [学习脚本编写 >](./scripts.md)
