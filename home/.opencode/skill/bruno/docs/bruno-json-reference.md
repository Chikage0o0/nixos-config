# Bruno 集合配置参考 (bruno.json)

`bruno.json` 是 Bruno 集合 (Collection) 的根配置文件。它定义了集合的元数据、脚本安全设置、代理配置以及忽略规则。

## 文件位置
必须位于集合的根目录下。

## 完整配置结构 (Schema)

```json
{
  "version": "1",
  "name": "My API Collection",
  "type": "collection",
  "ignore": [
    "node_modules",
    ".git",
    "coverage"
  ],
  "scripts": {
    "moduleWhitelist": [
      "axios",
      "moment",
      "crypto-js"
    ],
    "filesystemAccess": {
      "allow": true
    },
    "flow": "sandwich"
  },
  "proxy": {
    "mode": "system", 
    "http": "",
    "https": "",
    "bypass": ""
  }
}
```

## 字段详解

### 1. 基础元数据
| 字段 | 类型 | 说明 | 示例 |
| :--- | :--- | :--- | :--- |
| `version` | string | 配置文件版本，目前固定为 "1" | `"1"` |
| `name` | string | 集合显示的名称 | `"Stripe API"` |
| `type` | string | 集合类型，通常为 "collection" | `"collection"` |

### 2. 忽略规则 (`ignore`)
定义 Bruno 在加载集合时应忽略的文件或文件夹列表。这对于排除 `node_modules` 或版本控制目录非常重要。

```json
"ignore": [
  "node_modules",
  ".git",
  "**/*.log"
]
```

### 3. 脚本安全与行为 (`scripts`)
控制集合内脚本的权限和执行流程。

#### `moduleWhitelist` (数组)
列出允许在脚本 (`pre-request`, `post-response`, `tests`) 中引入 (`require`) 的 Node.js 模块。出于安全考虑，默认是不允许引入外部模块的。

#### `filesystemAccess` (对象)
控制脚本是否可以访问本地文件系统 (例如使用 `fs` 模块)。
- `allow`: `true` | `false`

#### `flow` (字符串)
定义脚本的执行顺序模式。
- `"sandwich"` (默认):
  - 集合级 Pre-request -> 文件夹级 Pre-request -> 请求级 Pre-request -> **发送请求** -> 请求级 Post-response -> 文件夹级 Post-response -> 集合级 Post-response
- `"sequential"`:
  - 仅执行当前层级的脚本 (不推荐，除非有特殊需求)。

### 4. 代理设置 (`proxy`)
配置集合特定的代理规则。

- `mode`:
  - `"system"`: 使用系统/全局代理设置。
  - `"custom"`: 使用自定义代理设置。
  - `"none"`: 禁用代理。
- `http`: HTTP 代理地址 (仅当 mode 为 custom)。
- `https`: HTTPS 代理地址。
- `bypass`: 不走代理的域名列表 (逗号分隔)。

---
[< 返回主页](./README.md)
