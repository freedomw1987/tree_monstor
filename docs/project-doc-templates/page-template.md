# Per-Page Spec — `docs/pages/<page>.md`

> **When to use:** DESIGN 階段，每個 page 一個檔。
> **No-code rule:** 不適用（純 wireframe + interaction spec）。

## 必填區塊

```markdown
# Page: Login

**對應 US**: US-001
**URL**: `/login`
**對應實作**: `src/pages/Login.tsx`

## Purpose
用戶輸入 email + 密碼登入。

## Wireframe
```
┌────────────────────────────────┐
│          [Brand Logo]          │
│                                │
│   ┌────────────────────────┐   │
│   │  Email                 │   │
│   │  [_______________]     │   │
│   │                        │   │
│   │  Password              │   │
│   │  [_______________]     │   │
│   │                        │   │
│   │  [    Sign In (md)    ] │   │
│   │                        │   │
│   │  Forgot password?      │   │
│   │  Don't have account?   │   │
│   └────────────────────────┘   │
│                                │
└────────────────────────────────┘
```

## Components used
- Input (email, password)
- Button (primary, md)
- Link (forgot password, sign up)

## Interaction spec
1. 用戶輸入 → 觸發 `onChange` → 表單 state 更新
2. submit 按鈕：所有欄位 valid 前 disabled
3. submit 後：顯示 loading state（spinner replaces label）
4. 成功 → 跳轉 `/dashboard`
5. 失敗 → 表單下方顯示 error（紅字），按鈕恢復 default state
6. 連續 5 次失敗 → 429 鎖 15 分鐘（form disabled）

## States
- `idle`: 預設
- `submitting`: loading 旋轉
- `error`: 顯示錯誤訊息
- `locked`: 429 後 form disabled，顯示剩餘時間

## Accessibility
- Page title: "Login"
- Form labels 明確（不只是 placeholder）
- 鍵盤 navigation: Tab 順序 email → password → submit
- 錯誤訊息: `role="alert"`, `aria-live="polite"`
- Focus 自動到第一個 error field

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
```

## 規則
- Wireframe 用 ASCII；複雜 layout 才用圖檔（圖檔 link 即可，不嵌入）
- Components used 引用 `components/<Name>.md` 不重複 contract
- 改 page 行為 → 加 changelog；如影響 US → 同步 US 檔