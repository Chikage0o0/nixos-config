# 脚本 API 参考 (Scripting API)

在 `script:pre-request`, `script:post-response` 和 `tests` 块中，Bruno 暴露了以下全局对象供你调用。

## 1. `req` (Request Object)
提供对当前 HTTP 请求的读写访问。

### 读方法 (Getters)
| 方法 | 返回值 | 说明 |
| :--- | :--- | :--- |
| `req.getUrl()` | string | 获取完整 URL |
| `req.getMethod()` | string | 获取 HTTP 方法 (如 "GET") |
| `req.getHeader(name)` | string | 获取指定 Header 的值 |
| `req.getHeaders()` | object | 获取所有 Headers |
| `req.getBody()` | any | 获取请求体 |
| `req.getAuthMode()` | string | 获取认证模式 (如 "bearer") |
| `req.getTimeout()` | number | 获取超时时间 (ms) |

### 写方法 (Setters)
*注意: 写方法主要用于 `pre-request` 脚本中修改请求。*

| 方法 | 参数 | 说明 |
| :--- | :--- | :--- |
| `req.setUrl(url)` | string | 修改请求 URL |
| `req.setMethod(method)` | string | 修改 HTTP 方法 |
| `req.setHeader(name, value)` | string, string | 设置/覆盖单个 Header |
| `req.setHeaders(object)` | object | 批量设置 Headers |
| `req.setBody(data)` | any | 修改请求体 |
| `req.setTimeout(ms)` | number | 设置超时时间 |
| `req.setMaxRedirects(num)` | number | 设置最大重定向次数 |

---

## 2. `res` (Response Object)
提供对 HTTP 响应的只读访问 (在 Mock 场景下可写)。仅在 `post-response` 和 `tests` 中可用。

### 属性
- `res.status`: 状态码 (Number)
- `res.statusText`: 状态文本 (String)
- `res.headers`: 响应头 (Object)
- `res.body`: 响应体 (自动解析为 Object 或 String)
- `res.responseTime`: 响应耗时 ms (Number)

### 方法
| 方法 | 返回值 | 说明 |
| :--- | :--- | :--- |
| `res.getStatus()` | number | 获取状态码 |
| `res.getStatusText()` | string | 获取状态文本 |
| `res.getHeader(name)` | string | 获取指定 Header |
| `res.getHeaders()` | object | 获取所有 Headers |
| `res.getBody()` | any | 获取响应体 |
| `res.getResponseTime()` | number | 获取耗时 |
| `res.getSize()` | object | 返回 `{ body: number, headers: number, total: number }` (单位字节) |
| `res.getUrl()` | string | 获取最终响应 URL (包含重定向后) |

### Mock 方法
| 方法 | 参数 | 说明 |
| :--- | :--- | :--- |
| `res.setBody(data)` | any | 手动设置响应体 (用于 Mock) |

---

## 3. `bru` (Bruno Context)
提供变量管理和工具函数。

### 变量管理
| 方法 | 说明 |
| :--- | :--- |
| `bru.getVar(key)` | 获取变量 (自动查找各级作用域) |
| `bru.setVar(key, value)` | 设置 **集合级** 变量 |
| `bru.getEnvVar(key)` | 获取 **当前环境** 变量 |
| `bru.setEnvVar(key, value)` | 设置 **当前环境** 变量 (临时，仅本次运行有效) |
| `bru.getProcessEnv(key)` | 获取系统环境变量 (`process.env`) |
| `bru.interpolate(str)` | 解析字符串中的 `{{variable}}` 占位符 |

### 异步请求 (Chaining)
| 方法 | 说明 |
| :--- | :--- |
| `bru.sendRequest(options, callback)` | 发送一个额外的 HTTP 请求 (不支持 await, 需使用 Promise 封装或 callback) |

**`sendRequest` 示例:**

```javascript
const request = {
  url: "https://api.example.com/token",
  method: "POST",
  body: { apiKey: "123" }
};

// 注意: 目前 API 设计是 Callback 风格
await new Promise((resolve, reject) => {
  bru.sendRequest(request, (err, response) => {
    if (err) return reject(err);
    bru.setVar("token", response.body.token);
    resolve();
  });
});
```

### 工具
- `bru.cwd()`: 获取当前工作目录。
- `bru.sleep(ms)`: 暂停执行。

---

## 4. 内置库 (Built-in Modules)
无需 `npm install`，可直接 `require` 使用的库：

- `ajv`: JSON Schema 验证
- `axios`: HTTP 客户端
- `btoa` / `atob`: Base64 编码解码
- `chai`: 断言库
- `cheerio`: HTML 解析 (类似 jQuery)
- `crypto-js`: 加密库 (MD5, SHA, AES)
- `dayjs`: 日期处理 (轻量级 Moment)
- `lodash`: 工具函数
- `moment`: 日期处理
- `uuid`: 生成 UUID
- `xml2js`: XML 解析

---
[< 返回主页](./README.md)
