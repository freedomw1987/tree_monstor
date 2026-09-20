# Sprint 14 RSI 反省 — US-026 rsi-propose --show-similar（2026-09-20）

## 基本資訊

- **User Story**：US-026 — rsi-propose --show-similar
- **對應 SP**：1 SP
- **對應 Sprint 14 主軸**：RSI 相似度計算
- **對應設計文件**：
  - docs/prd/04-self-evolution.md §11.7
  - docs/system-design.md ADR-026（show-similar 原則）

## 變更摘要

1. `tools/rsi-propose.sh` 加 `--show-similar` 旗標
2. 加 `--rules <file>` 旗標（指定規則庫）
3. `cmd_similar()` 函式用 Python 計算相似度：
   - **prefix_sim（前綴相似度）**：`相同前綴長度 / 最長長度 > 0.4`
   - **lev（Levenshtein 距離）**：≤ 12 視為相似
4. 支援 text / json 兩種輸出格式

## 相似度算法設計

| 算法 | 公式 | 適用場景 |
| --- | --- | --- |
| prefix_sim | 相同前綴 / 最長 | `bats_test_xxx_yyy` vs `bats_test_xxx_zzz` |
| lev（編輯距離） | 替換/插入/刪除次數 | 短字串差異（如 `gate_skip_v1` vs `gate_skip_v2`）|

兩個條件**任一滿足即視為相似**（OR 邏輯）。

## 量化指標

| 指標 | 數值 |
| --- | --- |
| 新增/修改檔案 | 1（tools/rsi-propose.sh）|
| bats 數量 | 5（us026-1 ~ us026-5）|
| bats 通過率 | 5/5（100%）|
| markdownlint | 0 errors |

## 與 SP-005 結論整合

依 Sprint 13 SP-005：
- AI 提建議（cmd_similar 列相似對）
- 人類決策（不自動合併）
- 規則庫 ≤ 20 條上限

✅ `--show-similar` 嚴格遵循「AI 提建議，不自動合併」原則

## 風險評估

- **風險 1**：相似度算法可能誤判（`bats_test_a` vs `bats_test_b` 距離 1 視為相似）
  - **緩解**：門檻 prefix_sim > 0.4 + lev ≤ 12 雙條件，且人類決策
- **風險 2**：markdown 表格格式變動會讓 awk 抓不到
  - **緩解**：regex 用 `^\| [0-9]+ \|` 嚴格匹配
- **風險 3**：python heredoc 在 bash 中可能解析錯誤
  - **緩解**：用 `python3 -c '...'` + 變數傳遞（避免 PYEOF close 問題）

## SOP 規範遵守

- [x] TDD 紅 → 綠（先寫 5 個 bats，再實作）
- [x] 雙演算法（前綴 + Levenshtein）OR 邏輯
- [x] text + json 兩格式
- [x] bats 覆蓋：help / 空規則庫 / 抓到相似 / JSON / 建議合併
- [x] markdownlint 0 errors
- [x] bash -n 通過

## 下一步

- [ ] Sprint 14 §2.4 反省
- [ ] Sprint 14 §2.5 提交
- [ ] Sprint 15 候選：可選 --auto-merge 旗標（高風險，需人類審批）

## 反思

US-026 是 SOP-Evolver 的「品質保險」：規則庫隨時間膨脹，
相似規則會增加「心智負擔」（人類決策時要比較 N 條規則）。

`--show-similar` 把這個負擔前置（讓人類先看相似對，再決定），
避免規則庫膨脹到「看不懂」的程度。

下次若改規則庫結構（如改 JSON、改 YAML），要同步更新 awk 抓取邏輯。
