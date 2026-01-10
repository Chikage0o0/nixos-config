# 断言与测试参考 (Assertions Reference)

Bruno 提供两种测试验证机制：`assert` 块 (声明式) 和 `tests` 块 (脚本式)。

## 1. 声明式断言 (`assert`)

位于 `.bru` 文件中，语法简洁，无需编写 JavaScript。

### 语法结构
```text
assert {
  [LHS] [Operator] [RHS]
}
```
- **LHS (左值)**: 通常是 `res.body`, `res.status`, `res.headers` 及其属性。
- **Operator (操作符)**: 比较逻辑。
- **RHS (右值)**: 期望值 (如果是字符串无需引号，除非包含空格)。

### 完整操作符列表

| 操作符 | 含义 | 示例 |
| :--- | :--- | :--- |
| `eq` | 等于 (严格匹配) | `res.status eq 200` |
| `neq` | 不等于 | `res.body.code neq -1` |
| `gt` | 大于 | `res.responseTime gt 50` |
| `gte` | 大于等于 | `res.body.age gte 18` |
| `lt` | 小于 | `res.body.price lt 100` |
| `lte` | 小于等于 | `res.body.score lte 100` |
| `in` | 在列表中 | `res.body.status in [active, pending]` |
| `notIn` | 不在列表中 | `res.body.role notIn [banned]` |
| `contains` | 包含 (字符串/数组) | `res.body.tags contains admin` |
| `notContains` | 不包含 | `res.body.error notContains "db error"` |
| `startsWith` | 以...开头 | `res.body.url startsWith https` |
| `endsWith` | 以...结尾 | `res.body.file endsWith .png` |
| `matches` | 正则匹配 | `res.body.email matches ^\S+@\S+\.\S+$` |
| `isNumber` | 是数字 | `res.body.id isNumber` |
| `isString` | 是字符串 | `res.body.name isString` |
| `isBoolean` | 是布尔值 | `res.body.isActive isBoolean` |
| `isArray` | 是数组 | `res.body.items isArray` |
| `isObject` | 是对象 | `res.body.meta isObject` |
| `isNull` | 是 null | `res.body.deletedAt isNull` |
| `isNotNull` | 不是 null | `res.body.createdAt isNotNull` |
| `isUndefined`| 未定义 | `res.body.extra isUndefined` |
| `isEmpty` | 为空 (空串/空数组) | `res.body.errors isEmpty` |
| `isNotEmpty` | 不为空 | `res.body.data isNotEmpty` |
| `isJson` | 是有效的 JSON 字符串| `res.body.rawConfig isJson` |

---

## 2. 脚本式测试 (`tests`)

位于 `tests` 块中，使用 JavaScript 和 Chai 断言库。

### 基础语法
```javascript
tests {
  test("描述测试目的", function() {
    // 断言逻辑
  });
}
```

### Chai Expect 常用模式

**检查值:**
```javascript
expect(res.status).to.equal(200);
expect(res.body.active).to.be.true;
expect(res.body.name).to.equal("Bruno");
```

**检查类型:**
```javascript
expect(res.body).to.be.an('object');
expect(res.body.items).to.be.an('array');
```

**检查包含:**
```javascript
expect(res.body.tags).to.include('api');
expect(res.body.message).to.contain('success');
```

**检查属性存在:**
```javascript
expect(res.body).to.have.property('token');
expect(res.body).to.have.nested.property('data.user.id');
```

**检查长度:**
```javascript
expect(res.body.items).to.have.lengthOf(5);
expect(res.body.items).to.have.lengthOf.above(2);
```

**复杂逻辑示例:**
```javascript
test("Each item should have an id", function() {
  const items = res.getBody().items;
  items.forEach(item => {
    expect(item).to.have.property('id').that.is.a('number');
  });
});
```

---
[< 返回主页](./README.md)
