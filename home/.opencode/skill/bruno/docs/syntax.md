# Bru 语言语法参考 (Syntax Reference)

Bruno 使用自定义的 **Bru Lang** 存储请求。本文件是 `.bru` 文件的完整语法参考手册。

## 文件结构概览

一个标准的 `.bru` 文件由多个“块 (Block)”组成。块的顺序不强制，但通常遵循以下约定：

1. `meta` (元数据)
2. `get/post/put/delete` (请求定义)
3. `headers`
4. `auth`
5. `params` (Query 参数)
6. `body`
7. `vars`
8. `script`
9. `assert`
10. `tests`
11. `docs`

---

## 块详解

### 1. Meta Block (`meta`)
定义请求的元数据。

```bru
meta {
  name: Get User Details
  type: http            # http 或 graphql
  seq: 1                # 排序序号
  tags: [smoke, dev]    # 标签列表
}
```

### 2. Request Block (HTTP Method)
定义请求方法和 URL。

```bru
# 语法: [method] { url: [value] }
get {
  url: {{base_url}}/api/v1/users?active=true
}
```
支持的方法: `get`, `post`, `put`, `delete`, `patch`, `head`, `options`.

### 3. Parameters Block (`params`)
定义 URL 查询参数 (Query Params)。

```bru
params:query {
  page: 1
  sort: desc
  # 以 ~ 开头表示该参数被禁用 (Commented out)
  ~debug: true
}
```

### 4. Headers Block (`headers`)
定义请求头。

```bru
headers {
  Content-Type: application/json
  Authorization: Bearer {{token}}
  X-Client: bruno-cli
}
```

### 5. Authentication Block (`auth`)
定义认证方式。

**支持的类型:**
- `auth:basic`
- `auth:bearer`
- `auth:digest`
- `auth:awsv4`
- `inherit` (继承父级认证)

**语法结构:**
1. 首先通过 `auth { mode: <type> }` 声明认证模式
2. 然后通过 `auth:<type> { ... }` 定义具体凭证

示例:
```bru
# Basic 认证
auth {
  mode: basic
}

auth:basic {
  username: {{user}}
  password: {{pass}}
}

# Bearer Token 认证
auth {
  mode: bearer
}

auth:bearer {
  token: {{jwt_token}}
}

# 继承父级认证 (使用 folder.bru 中定义的 auth)
auth {
  mode: inherit
}
```

### 6. Body Block (`body`)
定义请求体。支持多种格式，通过后缀区分。

**JSON (`body:json`):**
```bru
body:json {
  {
    "name": "Bruno",
    "version": 1
  }
}
```

**Form URL Encoded (`body:form-urlencoded`):**
```bru
body:form-urlencoded {
  client_id: 123
  grant_type: password
}
```

**Multipart Form (`body:multipart-form`):**
```bru
body:multipart-form {
  file: @file(/path/to/image.png)
  description: Profile Image
}
```
*注意: `@file()` 语法用于引用本地文件。*

**GraphQL (`body:graphql`):**
```bru
body:graphql {
  query {
    users {
      id
      name
    }
  }
}

body:graphql:vars {
  {
    "limit": 10
  }
}
```

**Text/XML (`body:text`, `body:xml`):**
直接包含原始内容。

### 7. Variables Block (`vars`)
定义请求级变量。
- `pre-request` 变量: 在请求前计算。
- `post-response` 变量: 暂不支持在此块定义，需在脚本中设置。

```bru
vars {
  internal_id: 555
  target_env: {{process.env.TARGET}}
}
```

### 8. Script Blocks (`script`)
包含 JavaScript 代码。

```bru
script:pre-request {
  // 请求前执行
  req.setHeader("X-Time", Date.now());
}

script:post-response {
  // 响应后执行
  bru.setVar("last_id", res.body.id);
}
```

### 9. Assertions Block (`assert`)
声明式断言列表。

**语法:** `[expression] [operator] [value]`

**可用操作符:**
- `eq` (等于)
- `neq` (不等于)
- `gt`, `gte` (大于, 大于等于)
- `lt`, `lte` (小于, 小于等于)
- `in`, `notIn`
- `contains`, `notContains`
- `startsWith`, `endsWith`
- `matches` (正则)
- `isNumber`, `isString`, `isBoolean`, `isArray`, `isObject`
- `isJson`
- `isEmpty`, `isNotEmpty`
- `isNull`, `isNotNull`, `isUndefined`

示例:
```bru
assert {
  res.status eq 200
  res.body.items.length gt 0
  res.headers['content-type'] contains json
}
```

### 10. Tests Block (`tests`)
包含基于 Chai 的测试脚本。

```bru
tests {
  test("Status is 200", function() {
    expect(res.getStatus()).to.equal(200);
  });
}
```

### 11. Example Block (`example`)
保存请求/响应示例 (Saved Examples)。

```bru
example {
  name: Success Response
  request: { ... }
  response: { ... }
}
```
*详见 [Example Block 参考](./example-block.md)。*

### 12. Documentation Block (`docs`)
Markdown 格式的请求说明文档。

```bru
docs {
  # 用户登录接口
  
  此接口用于验证用户凭证并返回 JWT Token。
  
  ## 错误码
  - 401: 密码错误
  - 404: 用户不存在
}
```

---
[< 返回主页](./README.md)
