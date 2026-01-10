# 高级示例场景 (Advanced Examples)

以下示例展示了如何在真实场景中组合使用 Bruno 的各种功能。

## 场景 1: 自动刷新 Token (Request Chaining)

**需求**: 每次请求前检查 Token 是否过期，如果过期则自动调用登录接口刷新，并更新环境变量。

**Pre-Request Script:**

```javascript
const tokenTimestamp = bru.getVar("token_timestamp");
const now = Date.now();
const EXPIRE_TIME = 3600 * 1000; // 1小时

// 检查 Token 是否存在或过期
if (!tokenTimestamp || (now - tokenTimestamp) > EXPIRE_TIME) {
  
  // 构造登录请求
  const loginRequest = {
    url: bru.getEnvVar("base_url") + "/auth/login",
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: {
      username: bru.getEnvVar("api_user"),
      password: bru.getEnvVar("api_pass")
    }
  };

  // 发送请求 (使用 Promise 包装以便 await)
  await new Promise((resolve, reject) => {
    bru.sendRequest(loginRequest, (err, response) => {
      if (err) return reject(err);
      if (response.status !== 200) return reject("Login Failed");

      // 更新 Token 和时间戳
      bru.setVar("jwt_token", response.body.access_token);
      bru.setVar("token_timestamp", Date.now());
      resolve();
    });
  });
}

// 设置当前请求的 Auth Header
req.setHeader("Authorization", "Bearer " + bru.getVar("jwt_token"));
```

## 场景 2: 文件上传 (Multipart Upload)

**需求**: 上传用户头像和相关元数据。

**.bru 文件配置:**

```bru
method: post
url: {{base_url}}/users/avatar
body: multipart-form

body:multipart-form {
  # 文本字段
  user_id: 1001
  category: profile
  
  # 文件字段 (使用 @file 语法)
  # 路径可以是绝对路径，或相对于集合根目录的路径
  avatar: @file(./assets/profile_pic.jpg)
}
```

## 场景 3: 复杂数据验证 (Schema Validation)

**需求**: 验证响应 JSON 严格符合 Schema 定义。使用内置的 `ajv` 库。

**Tests Script:**

```javascript
const Ajv = require("ajv");
const ajv = new Ajv();

const schema = {
  type: "object",
  properties: {
    id: { type: "integer" },
    name: { type: "string" },
    tags: { type: "array", items: { type: "string" } }
  },
  required: ["id", "name"],
  additionalProperties: false
};

test("Schema Validation", function() {
  const valid = ajv.validate(schema, res.getBody());
  if (!valid) {
    // 输出具体的验证错误信息
    console.error(ajv.errors);
  }
  expect(valid).to.be.true;
});
```

## 场景 4: 动态生成签名 (Crypto)

**需求**: 请求头需要包含基于 Body 内容的 HMAC-SHA256 签名。

**Pre-Request Script:**

```javascript
const CryptoJS = require("crypto-js");

// 获取 Body 字符串
let body = req.getBody();
if (typeof body === 'object') {
  body = JSON.stringify(body);
}

// 获取密钥
const secret = bru.getEnvVar("api_secret");
const timestamp = Date.now().toString();

// 构造签名内容: timestamp + body
const payload = timestamp + body;

// 计算签名
const signature = CryptoJS.HmacSHA256(payload, secret).toString(CryptoJS.enc.Hex);

// 设置 Headers
req.setHeader("X-Timestamp", timestamp);
req.setHeader("X-Signature", signature);
```

---
[< 返回主页](./README.md)
