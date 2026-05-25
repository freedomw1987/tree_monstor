---
name: elysia-llm-graceful-fallback
description: Elysia.js route pattern for graceful LLM/API fallback — return result objects instead of throwing, letting route handlers decide HTTP status and format.
tags: [elysia, typescript, error-handling, llm]
version: 1.0.0
---

# Graceful LLM Fallback in Elysia Routes

## 背景
在 Elysia.js 後端中，當某個可選依賴（如 LLM）未配置或呼叫失敗時，常見做法是 `throw new Error()`，但這會被 route 的 `catch` block 接管並轉成 500，導致前端只能看到通用錯誤訊息。

更好的模式：**用回傳值表達成功/失敗**，讓 route handler 控制回應格式，前端可以讀取有意義的錯誤訊息。

## 問題場景
```typescript
// ❌ 舊寫法：LLM 失敗時拋例外，導致 500 + 前端無法顯示有意義訊息
async function analyzeDocumentWithLLM(...) {
  if (!config) throw new Error('LLM config not set')
  // ...fetch...
  if (!response.ok) throw new Error(`LLM failed (${response.status})`)
  return content
}

// route 中
try {
  const llmOutput = await analyzeDocumentWithLLM(...) // 可能拋例外
  // ...
} catch (error) {
  return errorResponse(set, 500, 'DOCUMENT_PARSE_FAILED', message) // 變成 500，前端 alert 固定文字
}
```

## 正確做法：Result Object Pattern

### 1. 函數返回 Typed Result（不拋例外）
```typescript
type LLMResult = { content: string | null; raw: string | null; error?: string }

async function analyzeDocumentWithLLM(...): Promise<LLMResult> {
  const config = await prisma.lLMConfig.findFirst()
  if (!config) {
    return { content: null, raw: null, error: '請先到「AI 設定」頁面配置 API Key 和模型' }
  }
  try {
    // ...fetch...
    if (!response.ok) {
      return { content: null, raw: null, error: `AI 分析失敗（HTTP ${response.status}），請確認 API Key 和模型` }
    }
    // ...
    return { content, raw: content, error: undefined }
  } catch (err) {
    return { content: null, raw: null, error: err instanceof Error ? err.message : 'AI 分析時發生未知錯誤' }
  }
}
```

### 2. Route handler 檢查錯誤並客製回應
```typescript
const llmResult = await analyzeDocumentWithLLM(fileName, parsedText)

if (llmResult.error) {
  return {
    success: false,
    error: { code: 'LLM_NOT_CONFIGURED', message: llmResult.error }
  }
}

const llmOutput = llmResult.raw ?? ''  // 安全取值
const structured = parseLLMJson(llmOutput)
// 繼續正常流程...
```

### 3. 前端讀取真實錯誤訊息
```typescript
// WikiEditor.tsx
} catch (err: any) {
  const msg = err?.response?.data?.error?.message || '文件解析失敗，請確認 AI 設定已配置'
  alert(msg)
}
```

## 適用時機
- LLM / AI 功能為可選增強（主要功能不應被阻斷）
- 第三方 API 呼叫可能失敗但不應使整個 request 500
- 希望使用者看到具體錯誤原因而非「系統錯誤」
- 單一 request 中有多個可獨立的步驟（解析 → LLM 分析 → 寫入 DB）

## 關鍵原則
- **不回拋** — 失敗時返回 result object，不使用 `throw`
- **Route 掌控回應** — 由 route handler 決定成功/失敗時返回什麼 HTTP status 和格式
- **Typed result** — 用 TypeScript interface 定義 result shape，明確標注 error 類型
- **前端顯示真實訊息** — 前端 `catch` 從 `err.response.data.error.message` 取實際內容

## 反例（何時不適用）
- 若該功能是**必要條件**（如 auth），失敗應果斷拋 401/403，不需要優雅降級
- 若失敗代表**整個 operation 無意義**（如儲存資料失敗），直接 500 是合理的