# 脚本编写 (Scripting)

Bruno 允许在请求生命周期的两个阶段执行 JavaScript 代码：请求前 (`pre-request`) 和响应后 (`post-response`)。

## 脚本上下文对象

在脚本中，你可以访问以下内置对象：

### 1. `req` (Request Object)
用于在发送前读取或修改请求。

- **方法**:
  - `req.getUrl()`: 获取当前 URL。
  - `req.setUrl(url)`: 修改 URL。
  - `req.getMethod()`: 获取 HTTP 方法 (GET, POST 等)。
  - `req.setMethod(method)`: 修改 HTTP 方法。
  - `req.getHeader(name)`: 获取 Header 值。
  - `req.setHeader(name, value)`: 设置/添加 Header。
  - `req.setHeaders(object)`: 批量设置 Headers。
  - `req.getBody()`: 获取请求体。
  - `req.setBody(data)`: 设置请求体。

**示例 (Pre-Request):**
```javascript
// 自动添加时间戳 Header
req.setHeader("X-Timestamp", new Date().toISOString());

// 动态修改 Body
const body = req.getBody();
body.requestId = bru.interpolate("{{$randomUUID}}");
req.setBody(body);
```

### 2. `res` (Response Object)
用于在响应后读取数据。该对象在 `pre-request` 阶段不可用。

- **属性**:
  - `res.status`: HTTP 状态码 (Number)。
  - `res.statusText`: 状态文本 (String)。
  - `res.headers`: 响应头对象。
  - `res.body`: 响应体 (如果是 JSON 会自动解析)。
  - `res.responseTime`: 耗时 (ms)。

- **方法**:
  - `res.getStatus()`
  - `res.getBody()`
  - `res.getHeader(name)`

**示例 (Post-Response):**
```javascript
// 打印响应结果
console.log(res.status, res.body);
```

### 3. `bru` (Bruno Utility Object)
用于操作变量和执行工具函数。

- **方法**:
  - `bru.getVar(key)`: 获取变量 (自动解析层级)。
  - `bru.setVar(key, value)`: 设置集合级变量。
  - `bru.getEnvVar(key)`: 获取环境变量。
  - `bru.setEnvVar(key, value)`: 设置环境变量。
  - `bru.interpolate(string)`: 解析字符串中的变量 (例如 `{{var}}`)。

## 外部库支持
Bruno 内置了常用的 npm 库，可以直接 require 使用：
- `moment`
- `lodash`
- `crypto-js`
- `axios`
- ... (更多库请参考官方文档)

```javascript
const moment = require('moment');
req.setHeader("X-Date", moment().format('YYYY-MM-DD'));
```

---

[< 返回变量说明](./environments.md) | [学习断言与测试 >](./tests.md)
