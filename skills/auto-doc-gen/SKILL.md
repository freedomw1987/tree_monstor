---
name: auto-doc-gen
description: 從代碼註解自動生成 API docs。從 JSDoc/TSDoc 註解、TSDoc、Python docstring 自動生成 API 文檔。保持 docs/ 目錄與實際代碼同步。
trigger: "api docs / 自動文檔 / 生成文檔 / update docs"
category: productivity
---


Last-verified: 2026-07-28
# Auto Doc Generator

自動從代碼註解生成 API 文檔，確保文檔與代碼同步。

## 支援格式

| 語言 | 註解格式 | 输出 |
|------|---------|------|
| TypeScript/JavaScript | JSDoc / TSDoc | Markdown |
| Python | docstring | Markdown |
| Go | godoc | Markdown |

## 使用方式

```python
delegate_task(
    goal="自動生成 API 文檔",
    context="""
    語言: TypeScript
    源目錄: ./src/api
    輸出: docs/api.md
    """,
    toolsets=['terminal', 'file'],
    role="leaf"
)
```

## 工作流程

1. 掃描源目錄中的所有 API endpoints
2. 提取 JSDoc/TSDoc 註解
3. 生成 Markdown 格式的 API 文檔
4. 與現有 `docs/api.md` 比較，只更新變更部分
5. 提交前驗證：接口數量是否匹配

## 輸出格式

```markdown
# API Documentation

## Endpoints

### GET /api/users
**描述**: 獲取用戶列表

**參數**:
| 名稱 | 類型 | 必填 | 描述 |
|------|------|------|------|
| page | number | 否 | 頁碼 |

**返回**:
```json
{
  "users": [...],
  "total": 100
}
```
```

## 自動化觸發

在 `docs/devops.md` 中配置 git hooks：
```bash
# .git/hooks/pre-commit
npxapidoc --input ./src/api --output docs/api.md
```

## 驗證步驟

1. 生成的文檔是否編譯通過
2. 接口數量是否與實際 routes 一致
3. 參數描述是否完整
4. 是否有遺漏的端點