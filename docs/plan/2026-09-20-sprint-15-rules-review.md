# Sprint 15 規劃 — 規則庫實戰 review（2026-09-20）

> **對應 §2.1 dav-planner**
> **Sprint**：Sprint 15 規則庫實戰 review（精簡版）
> **SP**：1 SP（精簡 — 只做階段 A，避免 over engineering）
> **狀態**：🟡 Planning

---

## 1. Sprint 15 主軸（精簡版）

**主軸**：驗證 Sprint 14 RSI 成熟化工具的實用性，並建立規則庫基礎。

Sprint 14 已建 3 個成熟化工具（sync dry-run / show-similar / REVIEW.md 自動產生），
但規則庫（`docs/sop/rsi-rules.md`）尚未實體建立 — 工具空轉。

Sprint 15 精簡為**只做階段 A**（不做階段 B）：
1. **建立基礎規則庫**（12 條）：把 Sprint 09-14 累積的常見事件類型落地
2. **實戰 REVIEW.md**：跑 `rsi-rules-review.sh` 看實際相似規則對

**不做階段 B 理由**（避免 over engineering）：
- 規則庫才 12 條，未達 20 條閾值
- 強制合併 = 為合併而合併，無真實需求
- 等規則庫累積到 18+ 條再進 Sprint 16 處理人類決策合併

---

## 2. Sprint 15 候選任務（從 backlog Sprint 15 推薦）

| ID | 標題 | SP | 優先級 |
|---|---|---|---|
| **US-029-A** | 建規則庫 + 跑 review（階段 A）| 1 | P3 |
| **小計** | | **1** | |
| **未做** | US-029-B（人類決策合併）| ~~1~~ | 暫緩 |

### 2.1 US-029-A（1 SP）— 規則庫 + 跑 review（精簡版）

**需求**：Sprint 14 TD-038 建了 `rsi-rules-review.sh` 但從未跑過實際規則庫。
Sprint 15 只做：
1. 建基礎規則庫（從 Sprint 09-14 觀察累積）
2. 跑 review 看實際結果
3. **不做人類決策合併**（等規則庫 ≥ 18 條再說）

**目標**：

建立 `docs/sop/rsi-rules.md`（12 條規則）：

| ID | Event Type | 對應 Sprint | 規則描述 |
| --- | --- | --- | --- |
| 1 | shellcheck_not_installed | Sprint 09 | 提示用戶安裝 shellcheck |
| 2 | bats_test_chinese_name | Sprint 09 | bats test name 必須 ASCII |
| 3 | markdown_md047_error | Sprint 09 | 寫完檔案用 python rstrip 修 |
| 4 | bash_set_u_unbound | Sprint 10 | TD-035 隔離層（set +u / set -u） |
| 5 | declare_a_unsupported | Sprint 10 | macOS bash 3.2 不支援 declare -A |
| 6 | awk_ternary_truncated | Sprint 10 | awk 三元運算被 shell 截斷 |
| 7 | py_heredoc_in_function | Sprint 11 | bash 函式內 Python 用 -c 而非 PYEOF |
| 8 | rule_md058_tables | Sprint 11 | markdown 表格需空行圍繞 |
| 9 | rule_md029_ol_prefix | Sprint 11 | ol 列表前綴一致 |
| 10 | rule_md036_emphasis_heading | Sprint 11 | 避免用 `**...**` 當 heading |
| 11 | langle_pipe_in_md | Sprint 12 | markdown 表格避免 `\|` |
| 12 | lf_in_func_before_call | Sprint 13 | bash 函式定義在呼叫之前 |

**驗證**：
1. 跑 `./tools/rsi-rules-review.sh` 產出 `tools/rules/REVIEW.md`
2. 確認 markdownlint 0 errors
3. ≥ 2 個 bats（全綠，含實際 rules.md 測試，不只 mock）

### 2.2 ~~US-029-B（1 SP）— 人類決策合併~~ **暫緩**

**理由**：
- 12 條規則未達 20 條閾值（無 REVIEW.md 警告觸發）
- 強制合併 = 為合併而合併，無真實需求
- Sprint 16+ 候選：規則庫 ≥ 18 條時啟動

**設計重點**：
- 嚴格遵循 SP-005「AI 提建議不自動合併」
- 等真實需求出現再做

---

## 3. 風險評估

| 風險 | 機率 | 影響 | 緩解 |
| --- | --- | --- | --- |
| 規則庫 12 條太密，找不到相似對 | 中 | 中 | 用 Sprint 14 雙演算法（prefix + Levenshtein）抓 |
| 人類決策猶豫不決 | 中 | 低 | 預先給 2 對「預期相似對」作參考 |
| 合併後規則庫 < 8 條反而太少 | 低 | 低 | 不強求合併，可保留 12 條 |
| REVIEW.md 路徑衝突 | 低 | 低 | 用 `--output-dir` 指定獨立目錄 |

---

## 4. 完成定義（DoD）

- [ ] `docs/sop/rsi-rules.md` 12 條規則已建
- [ ] `./tools/rsi-rules-review.sh` 已跑，產出 `tools/rules/REVIEW.md`
- [ ] `tools/rules/REVIEW.md` markdownlint 0 errors
- [ ] `docs/sop/rsi-rules.md` markdownlint 0 errors
- [ ] ≥ 2 個新 bats 全綠（含實際 rules.md 測試）
- [ ] Sprint 13 + 14 bats 無 regression
- [ ] ~~§2.2 設計~~（精簡版不需要 §2.2，直接進 §2.3 執行）
- [ ] §2.3 執行 + §2.4 反省 + §2.5 提交 + commit

---

## 5. 不在 Sprint 15 範圍（精簡）

- ~~人類決策合併（US-029-B）~~ — **暫緩到 Sprint 16+**（規則庫 ≥ 18 條再說）
- sync 衝突策略（US-030）— 高風險，需獨立 Sprint
- Slack/email 通知（US-031）— P4 優先級低
- 規則庫自動 commit / push — 屬於 Sprint 16+ 候選

---

## 6. Sprint 16+ 候選預覽

| 候選 | 說明 |
| --- | --- |
| US-029-B 人類決策合併（規則庫 ≥ 18 條時啟動）| 等真實需求 |
| sync 衝突策略 | 自動 3-way merge（高風險）|
| 規則庫 CI 整合 | 規則庫 ≥ 20 條 → CI fail |
| 跨專案規則去重 | 多機器規則庫同步 |

---

## 7. Sprint 15 量化預期（精簡）

| 指標 | Sprint 14 末 | Sprint 15 末 | 變化 |
| --- | --- | --- | --- |
| 規則庫 | 0（未建）| 12 | +12 |
| FR | 27 | 28（+4.28）| +1 |
| 累計 SP | 41.5 | **42.5** | **+1** |

---

## 8. 結語

Sprint 15 是「**RSI 成熟化 → 實戰驗證**」的關鍵 Sprint（精簡版）：

- Sprint 09-13：建 RSI 機制（觀察/聚合/反推/部署）
- Sprint 14：成熟化（dry-run / 相似度 / review）
- **Sprint 15：實戰驗證**（建規則庫 + 跑 review）

**精簡原則**（依用戶 feedback）：避免 over engineering，只做最小必要工作。
人類決策合併（階段 B）等真實需求再做，不為合併而合併。

完成 Sprint 15 後，RSI 從「工具空轉」進化到「實戰可用」，REVIEW.md 才有真東西可看。

---

## 9. 計劃摘要（精簡版）

**Sprint 15**：US-029-A（建規則庫 + 跑 review，**1 SP**）
- 階段 A：建規則庫 12 條 + 跑 REVIEW.md（1 SP）
- ~~階段 B：人類決策合併（1 SP）~~ — **暫緩**

**累計**：42.5 SP（Sprint 09-15）
