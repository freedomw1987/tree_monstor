# API Contract — Probe / Assert / Describe + 環境變量

> 本檔為 regression-guard 的「API 合約」+「環境變量」章節（v2.1 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：API 合約 21 行 + 環境變量 9 行 = 30 行，屬於「寫探針 / 設環境」時才查。

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

| 變量 | 預設值 | 說明 |
|------|--------|------|
| `REGRESSION_MODE` | `false` | 開關探針 |
| `REGRESSION_OUTPUT` | `both` | 輸出格式：`json` / `text` / `both` |
| `REGRESSION_STRICT` | `true` | 遇錯即停 |
| `REGRESSION_REPORT_PATH` | `./report.json` | 報告路徑 |
