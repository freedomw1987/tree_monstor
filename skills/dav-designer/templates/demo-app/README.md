# demo app 範本（templates/demo-app）

Scaffold（見同套 `system-prototype.md` §3）之後，抄呢啲檔落 demo app：

- `vite.config.ts` → demo app 根（覆蓋 Vite 預設）
- `tsconfig.json` → demo app 根（覆蓋 Vite 預設，加 `paths` alias）—— **shadcn 讀呢份**
- `tsconfig.app.json` → demo app 根（覆蓋 Vite 預設，加 `paths` alias）—— **tsc 讀呢份**
- `src/main.tsx` → `src/main.tsx`
- `src/mock/store.ts` → `src/mock/store.ts`
- `src/demo/routes.ts` → `src/demo/routes.ts`

## 接線清單（抄完之後逐項做）

1. `src/index.css` —— `shadcn init` 已寫好 `@import "tailwindcss"` ＋ theme 變數；
**design tokens 加落同一個 `:root` 段**（唯一來源，所有 surface 共用同一套）
2. `src/components/shell/` —— 每個 surface 一個 layout（`web-admin-layout` / `mobile-layout` / `terminal-layout`），
共用 tokens ＋ `components/ui/`
3. `src/features/<module>/` —— 每 Module 嘅畫面；資料一律經 `useDemoStore` action 改
4. `src/demo/panel.tsx` —— demo 路線面板（shadcn `Sheet`）：上一步／下一步／跳到呢步／重設資料（呼叫 store `reset`）
5. `src/mock/db.ts` —— seed 資料（`seedOrders` 等）

## 驗收

```bash
npm run build   # tsc 型檢查 ＋ vite build → dist/index.html（單檔、雙擊即開）
```

- 雙擊 `dist/index.html` 開得到（HashRouter；用 BrowserRouter 會 SecurityError）
- 逐步行一次 demo 路線，睇吓有冇死路、冇跳轉失敗
- 至少 1 條流程跨 surface 串連（手機寫入 → 後台讀到同一個 store）
