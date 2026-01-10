# Example Block (example)

`example` 块用于在 `.bru` 文件中保存请求和响应的示例。这对于 API 文档化非常有帮助，类似于 Postman 中的 "Saved Examples"。它展示了特定场景下的请求参数及预期的响应结果。

## 基本结构

一个 `.bru` 文件可以包含多个 `example` 块。

```bru
example {
  name: 成功创建用户
  
  request: {
    url: {{base_url}}/users
    method: POST
    mode: json
    headers: {
      Content-Type: application/json
    }
    body:json: {
      {
        "name": "John Doe",
        "job": "Developer"
      }
    }
  }
  
  response: {
    status: {
      code: 201
      text: Created
    }
    headers: {
      Content-Type: application/json
      Date: Wed, 21 Oct 2023 07:28:00 GMT
    }
    body: {
      type: json
      content: {
        {
          "id": "123",
          "name": "John Doe",
          "job": "Developer",
          "createdAt": "2023-10-21T07:28:00.000Z"
        }
      }
    }
  }
}
```

## 字段详解

### 1. `name`
示例的名称，显示在 UI 的 Examples 列表中。

### 2. `request` (请求部分)
定义该示例对应的请求信息。

- `url`: 请求 URL。
- `method`: HTTP 方法 (GET, POST, PUT, DELETE 等)。
- `mode`: Body 模式 (例如 `json`, `text`, `xml`, `formUrlEncoded`, `multipartForm`, `graphql`)。
- `headers`: 请求头键值对。
- `body:<mode>`: 请求体内容。
  - `body:json`: JSON 内容。
  - `body:text`: 纯文本内容。
  - `body:xml`: XML 内容。

### 3. `response` (响应部分)
定义该示例对应的预期响应信息。

- `status`: 状态信息。
  - `code`: HTTP 状态码 (如 200, 404)。
  - `text`: 状态文本 (如 OK, Not Found)。
- `headers`: 响应头键值对。
- `body`: 响应体内容。
  - `type`: 内容类型 (`json`, `text`, `xml`)。
  - `content`: 实际内容。如果是 JSON，直接写 JSON 对象；如果是 Text/XML，通常使用多行字符串语法 `''' ... '''`。

## 多行文本语法
对于较长的响应体或 XML/HTML 内容，建议使用 `'''` 包裹：

```bru
body: {
  type: text
  content: '''
    <html>
      <body>
        <h1>Hello World</h1>
      </body>
    </html>
  '''
}
```

---
[< 返回主页](./README.md)
