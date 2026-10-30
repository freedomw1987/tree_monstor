---
name: dav-designer-system-prototype
description: dav-designer 的「系統 demo 原型」子檔。定義 Surface 模型（web-admin／mobile-app／tablet／cli-terminal）、React + Tailwind + shadcn/ui stack 規格、單一 mock store、demo 路線、驗收關鍵字。
---

# Dav Designer — 系統 Demo 原型規格

> Step 5 嘅全部規格喺呢度：原型單位係 **Surface**（唔再係 Module）；產出係 **一個 demo app**（唔再係逐 Module 孤島 html）。

## §1 Surface 模型

- **Surface（介面載體）**：同一套功能喺唔同外形上嘅呈現。
- **常見**：`web-admin`（中央管理後台）／`mobile-app`（手機，390×844 框內）／`tablet-app`／`cli-terminal`（終端 mock view）。
- **Surface ≠ Module**：Module = 功能內聚單位（開發／測試邊界）；Surface = 功能嘅外殼。1 Module 可落多 Surface；1 Surface 可裝多 Module。
- **切 surface 規則**：Step 1 標明每 Module 落邊個 Surface；跨端功能兩邊都畫，唔准只畫一邊。
- **CLI 專案**：冇 GUI → Surface = `cli-terminal`（假輸入 → 假輸出嘅終端 view），一樣可 demo。

## §2 Stack 規格（硬規定）

- **必用**：Vite ＋ React ＋ TypeScript ＋ Tailwind CSS ＋ shadcn/ui（Radix primitives，裝 `radix-ui`）
＋ react-router-dom（**HashRouter**）＋ zustand（含 persist）。
- **HashRouter 嘅理由**：`dist/index.html` 用 `file://` 雙擊開，BrowserRouter 嘅 pushState 會 SecurityError。
- **zustand persist 嘅理由**：demo 狀態留喺 localStorage（重開唔會跌空狀態），兼支援一鍵 reset。
- **shadcn/ui 嘅理由**：佢係抄入 repo 嘅組件碼（唔係 npm 套件）→ 版控得、樣式跟 Tailwind tokens；Radix 供 a11y 互動底層。
- **單檔交付**：`vite-plugin-singlefile` → build 出 `dist/index.html`（雙擊即開、拎得走）。

## §3 Scaffold（已實測，非互動）

```bash
npm create vite@latest <slug> -- --template react-ts
cd <slug> && npm i
npm i tailwindcss @tailwindcss/vite react-router-dom zustand
npm i -D @types/node vite-plugin-singlefile
npx shadcn@latest init -d -b radix -f -y
npx shadcn@latest add button card input table dialog tabs sheet dropdown-menu badge avatar --yes --overwrite
```

- **坑 1（實測 fail 過）**：`shadcn init` 前置檢查要求 Tailwind ＋ path alias 已就緒 → 未裝就 fail。
- **坑 2（實測踩中）**：`paths` 要寫喺 **root `tsconfig.json` 同 `tsconfig.app.json` 兩份** ——
shadcn 讀 root，tsc 讀 app；漏咗 root → shadcn 會寫出字面 `@/` 目錄（`./@/components/ui/`）。
新版 TS 已移除 `baseUrl`（淨寫 `paths`）。
- **坑 3**：`vite-plugin-singlefile` 要加落 `vite.config.ts` 先 build 到單檔。
- **`-b radix`**：揀 Radix primitives 做底層（裝 `radix-ui` 套件）；`-f` 覆蓋已有 `components.json`（唔加會問 Y/N 卡住）。
- **設定檔 ＋ 接線樣板** → 同套 `templates/demo-app/`（`vite.config.ts`／`tsconfig*.json`／`src/` 樣板）。

## §4 Demo app 結構（建議）

```
prototype/<slug>/
  vite.config.ts  tsconfig*.json  components.json  index.html  package.json
  src/
    main.tsx           # HashRouter + surface route 分派
    App.tsx
    index.css          # design tokens 唯一來源 + theme
    components/ui/     # shadcn 組件碼（CLI 抄入）
    components/shell/  # 每 surface 一套 layout（Sidebar／Topbar／PhoneFrame／Terminal）
    features/<module>/ # 每 Module 嘅畫面
    mock/db.ts         # seed 資料
    mock/store.ts      # zustand store（單一真相源）+ actions
    demo/routes.ts     # demo 路線定義
    demo/panel.tsx     # demo 路線面板 + reset
```

- **tokens 唯一來源**：`index.css` 定義 CSS 變數（色／字／間距／圓角／陰影），所有 surface 引用同一套 → 跨端視覺一致。
- **store 單一真相源**：跨 Module、跨 Surface 共用；只經 action 改 state。
- **layout 分區**：surface 之間用 layout component 隔離（唔係同一頁硬縮），但 tokens／ui 組件／store 共用。
- **擺位**：跟專案既有前端結構；冇就放專案根 `prototype/<slug>/`（`node_modules/`、`dist/` 唔入版控）。

## §5 Demo 路線（demo script）

- **每個 demo app 必有 1 條路線**：有序 step 陣列，每 step = 目標 Surface ＋ 目標 route ＋ 一句「要講乜」。
- **路線最少跨 1 Module，理想跨 2 Surface**（例：手機落單 → 後台見到新單 → 審批 → 儀表板）。
- **面板**：shadcn `Sheet`／`Dialog`；有「上一步／下一步／跳到呢步／重設資料」。
- **路線入 PRD**：追溯矩陣加「Demo 步驟」欄，標明每 FR 落喺路線第幾步。

## §6 驗收（機械可查）

- **build 綠**：`npm run build` 成功（tsc 型檢查 ＋ vite build）→ `dist/index.html` 存在且可雙擊開。
- **關鍵字自查**：`HashRouter`／zustand `persist`／store `create`／demo 路線陣列／`reset` action／每 surface 一條 route 前綴。
- **跨 surface 串連**：至少 1 條流程由 A surface 寫入、B surface 讀到（同一 store）。
- **demo 路線行得通**：逐步走一次，冇死路、冇跳轉失敗。
- **DoD 深度**（Step 1 選定）：Lite = 每 Surface happy path ＋ 系統級 4 項（shell／tokens／store 串連／demo 路線）；
Full = 再加每 Module 五狀態 → 見同套 `prototype-quality.md`。
- **禁止**：真實後端 API 呼叫／build 後仍靠外部 CDN／把 mock 標成真實功能／喺 demo app 內寫 production 業務邏輯。

## §7 邊界

- demo app = **設計期原型**：可以寫前端 code，但唔寫 production 後端、唔接真 API、唔做真實業務邏輯。
- production 實作由 `dav-developer` skill 另起（可重用 tokens／元件思路，但唔好直接攞 demo code 當 production）。
- **一個 Surface 一個 demo app**，唔係一個 Module 一個 app；同一 Module 唔重複開 app。
