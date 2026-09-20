# RSI 規則庫（2026-09-20）

> **對應**：PRD §11.7 + ADR-027 + handbook 2.8-rsi-evolution.md §6.6
> **規則數**：12 條（SP-005 上限 20 條）
> **狀態**：🟢 Active（首次建立）

---

## 規則清單

| 編號 | event_type | 規則描述 | 對應 Sprint |
| --- | --- | --- | --- |
| 1 | shellcheck_not_installed | 提示用戶安裝 shellcheck（macOS 預設無）| Sprint 09 |
| 2 | bats_test_chinese_name | bats test name 必須 ASCII（中文括號 unknown test name）| Sprint 09 |
| 3 | markdown_md047_error | 寫完檔案用 python `rstrip(b'\n') + b'\n'` 修 | Sprint 09 |
| 4 | bash_set_u_unbound | bash `set -u` 環境下未定義變數用 `: "${VAR:=}"` 預設 | Sprint 10 |
| 5 | bash_declare_a_unsupported | macOS bash 3.2 不支援 `declare -A`（改用臨時檔）| Sprint 10 |
| 6 | awk_ternary_truncated | awk 三元運算被 shell 截斷（用 if/else 替代）| Sprint 10 |
| 7 | bash_function_before_call | bash 函式定義必須在呼叫之前（無 hoisting）| Sprint 11 |
| 8 | py_heredoc_in_bash | bash 中 Python heredoc 易壞（用 `python3 -c '...'`）| Sprint 11 |
| 9 | markdown_md058_blanks | markdown 表格需空行圍繞（否則 MD058）| Sprint 11 |
| 10 | markdown_md029_ol_prefix | ol 列表前綴必須一致（1/1/1 或 1/2/3）| Sprint 11 |
| 11 | markdown_md036_emphasis | 避免用 `**...**` 當 heading（會被 MD036 警告）| Sprint 11 |
| 12 | json_ensure_ascii_false | Python `json.dumps` 中文用 `ensure_ascii=False` | Sprint 12 |

---

## 規則庫維護原則

1. **新增規則**：每次觀察到新常見事件類型時，由人類決定是否入庫（SP-005）
2. **合併 / 拆分**：當規則數 ≥ 18 條時觸發 review（見 `tools/rules/REVIEW.md`）
3. **上限**：20 條（SP-005 結論 — 過大會變難維護）
4. **格式**：markdown 表格，`^| <num> | <event_type> |` 開頭才會被 `rsi-rules-review.sh` 抓到

---

## 規則命名規範

- **event_type**：snake_case，前綴分類
  - `markdown_*` — markdown lint 相關
  - `bash_*` — bash 語法相關
  - `py_*` — Python 相關
  - `json_*` — JSON 處理相關
  - `bats_*` — bats 測試相關
  - `awk_*` — awk 處理相關
  - `shellcheck_*` — shellcheck 工具相關

---

## 規則來源

| Sprint | 規則數 | 累積 |
| --- | --- | --- |
| Sprint 09 | 3 | 3 |
| Sprint 10 | 3 | 6 |
| Sprint 11 | 5 | 11 |
| Sprint 12 | 1 | 12 |

**觀察頻率**：Sprint 09-12 期間累計，每次遇到新錯誤類型時由人類決策入庫。

---

## 參考

- `tools/rsi-rules-review.sh` — 自動 review（找相似對 + 警告）
- `tools/rsi-propose.sh --show-similar` — 相似度計算（雙演算法 OR 邏輯）
- `tools/rules/REVIEW.md` — 自動產出的 review 報告
- `docs/research/2026-09-20-cross-project-rule-dedup.md` — SP-005 研究結論
