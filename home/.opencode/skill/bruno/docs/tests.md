# 断言与测试 (Assertions & Tests)

Bruno 提供了两种验证 API 响应的方式：简单直观的声明式断言 (`assert`) 和 功能强大的 JavaScript 测试脚本 (`tests`)。

## 1. 声明式断言 (`assert`)

这是最简单的方式，适合快速验证。它使用一种简洁的 DSL (领域特定语言)。

**语法:**
`[表达式] [操作符] [值]`

**支持的操作符:**
- `eq` (等于)
- `neq` (不等于)
- `gt` (大于)
- `gte` (大于等于)
- `lt` (小于)
- `lte` (小于等于)
- `in` (包含于)
- `notIn` (不包含于)
- `contains` (包含字符串)
- `notContains` (不包含字符串)
- `length` (数组/字符串长度)
- `matches` (正则匹配)
- `startsWith`, `endsWith`
- `isNumber`, `isString`, `isBoolean` ...

**示例 (.bru 文件中):**
```bru
assert {
  res.status eq 200
  res.body.data.users.length gt 0
  res.body.success eq true
  res.responseTime lt 1000
}
```

## 2. JavaScript 测试脚本 (`tests`)

如果你需要更复杂的逻辑，可以使用 `tests` 块。Bruno 内置了 `chai` 断言库 (Expect 风格)。

**基本结构:**
```javascript
test("测试用例名称", function() {
  // 测试逻辑
});
```

**常用断言 (Chai Expect):**

```javascript
tests {
  test("Status code is 200", function() {
    expect(res.status).to.equal(200);
  });

  test("Response returns a valid token", function() {
    const body = res.getBody();
    expect(body).to.be.an('object');
    expect(body.token).to.be.a('string');
    expect(body.token).to.not.be.empty;
  });

  test("User list contains specific user", function() {
    const users = res.body.data;
    // 使用 Lodash 查找
    const user = _.find(users, { id: 1 });
    expect(user).to.exist;
    expect(user.name).to.equal("Leanne Graham");
  });
}
```

## 3. 混合使用
你可以同时使用 `assert` 和 `tests` 块。通常建议用 `assert` 处理简单的状态码和字段检查，用 `tests` 处理复杂的数据验证逻辑。

---

[< 返回脚本编写](./scripts.md) | [回到主页 >](./README.md)
