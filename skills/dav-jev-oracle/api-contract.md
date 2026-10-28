# API Contract — Probe / Assert / Describe + 環境變量

> 本檔為 dav-developer 的「API 合約」+「環境變量」章節（v2.1 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：拆檔當時 API 合約 21 行 + 環境變量 9 行 = 30 行，屬於「寫探針 / 設環境」時才查。

## API 合約

### `probe(name, actual, expected)`

- **name**（string）：探針名稱（描述性）
- **actual**（any）：實際值
- **expected**（any）：預期值
- **return**：通過時 ✅，失敗時 ❌ + suggestion

### `assert(condition, message)`

- **condition**（bool）：布林條件
- **message**（string）：描述文字
- **return**：通過時 ✅，失敗時 ❌

### `describe(name, fn)`

- **name**（string）：套件名稱
- **fn**（function）：包含探針的函數 / 區塊
- **return**：分組結果

## 環境變量

- **`REGRESSION_MODE`**
  - 預設值：`false`
  - 說明：開關探針
- **`REGRESSION_OUTPUT`**
  - 預設值：`both`
  - 說明：輸出格式：`json` / `text` / `both`
- **`REGRESSION_STRICT`**
  - 預設值：`true`
  - 說明：遇錯即停
- **`REGRESSION_REPORT_PATH`**
  - 預設值：`./report.json`
  - 說明：報告路徑
- **`REGRESSION_MODULE`**
  - 預設值：（未設定）
  - 說明：Module 範圍限定（v2.9 新增）：設為 `M01` 時只跑 `M01-*` prefix 的探針；未設定 = 跑全部。Module 代碼定義見 `docs/system-design.md`。
