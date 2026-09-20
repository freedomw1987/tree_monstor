# 設計計劃 — RSI（Recursive Self-Improvement）機制

**對應 Backlog**：[US-011~017 + TD-022](../backlog.md)
**日期**：2025-09-20
**狀態**：✅ 設計完成，待用戶審核
**作者**：Agent（依 SOP §2.2 + `dav-designer`）
**範圍**：M4 — Self-Evolution (RSI)

---

## 1. 目標

讓 tree_monstor 具備「**跨專案學習、單一源進化**」能力：

- 裝在專案裡的 tree_monstor **只觀察不動 SOP**
- 裝回源 repo 才聚合 + 提案 + 改 SOP
- 改完一次同步給所有已裝專案（`rsi-sync.sh`）

**為什麼是這個方向**：你的項目**早就有 70% RSI 基礎**（dav-reflection + TD 閉環 + gates.json + reviewer subagent），缺的是把這個閉環**機制化、量化、加安全網**。

---

## 2. 為什麼推薦「主動跨專案升級」

| 對比 | 主動跨專案升級（推薦） | 每專案獨立 | 全互聯同步 |
|---|---|---|---|
| 風險 | ⭐⭐⭐⭐⭐ 低 | ⭐⭐⭐ 中 | ⭐⭐ 高 |
| 學習價值 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 實作複雜度 | 中 | 中 | 高 |
| 一致性保證 | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐⭐ |

**結論**：主動跨專案升級平衡了所有維度，且與你的 Think Big 哲學契合。

---

## 3. 整體架構

```
┌───────────────────────────┐    ┌───────────────────────────┐
│ 專案 A（裝了 tree_monstor）│    │  專案 B（裝了 tree_monstor） │
│  skills/sop-evolver      │    │  skills/sop-evolver      │
└─────────────┬─────────────┘    └─────────────┬─────────────┘
              │                                │
        任務完成自動觸發                            │
              ▼                                ▼
┌─────────────────────────────────────────────────┐
│  ~/.tree-monstor/observations/                │
│   ├── project-A/{date}.json                  │
│   ├── project-A/                   │
│   ├── project-B/                   │
│   └── ...                    │
└──────────────────┬──────────────────────────────┘
                   │
                   │ 用戶：cd 回源 repo + 打 /reflect
                   ▼
┌─────────────────────────────────────────────────┐
│  tree_monstor 源 repo                            │
│                                                   │
│  [1] 聚合  rsi-aggregate.sh                      │
│       → docs/sop/rsi-aggregated-{date}.md        │
│                                                   │
│  [2] 提案  sop-evolver proposer.md                │
│       → docs/sop/rsi-proposals-{date}.md         │
│         （每個 diff 附證據 + 影響專案數 + rollback）│
│                                                   │
│  [3] Reviewer 二審  dev-checker-loop  ← V03      │
│       → docs/sop/rsi-reviewer-verdict-{date}.md │
│                                                   │
│  [4] 用戶批准  ← 必經人手                         │
│       → git commit + tag rsi-vYYYYMMDD-NN       │
│                                                   │
│  [5] 合併  rsi-rollback.sh 寫 rsi-log.md          │
│                                                   │
│  [6] 同步  rsi-sync.sh （install.sh 自動觸發）      │
│       → 把新版 ~/.pi/sop/ 同步到所有已裝專案          │
│         （不覆蓋本地 override）                       │
└─────────────────────────────────────────────────┘
```

---

## 4. 模組劃分（M4）

| 維度 | 內容 |
|---|---|
| **職責** | RSI 觀察 / 聚合 / 提案 / 審批 / 合併 / 同步 |
| **邊界** | 不改業務邏輯，只改 SOP |
| **變更影響** | AGENTS.md / gates.json / skills/ / docs/ |
| **介面契約** | 見 [`system-design.md` §4](../system-design.md) |

---

## 5. Skill 結構（sop-evolver）

```
skills/sop-evolver/
├── SKILL.md                    # ≤150 行
├── observation.md              # 觀察模式規範 + JSON schema
├── aggregator.md               # 聚合模式規範
├── proposer.md                 # 提案 prompt 模板
└── safety.md                   # 4 條不可違反規則
```

---

## 6. 工具結構

| 工具 | 用途 | SP |
|---|---|---|
| `tools/rsi-aggregate.sh` | 收集觀察 + 聚合 + 排序 | US-015 |
| `tools/rsi-propose.sh` | 產出 diff 提案 + 附證據/影響/rollback | US-015 |
| `tools/rsi-metrics.sh` | 量化指標（6 個） | US-014 |
| `tools/rsi-rollback.sh` | 一鍵回滾 + git tag | US-014 |
| `tools/rsi-sync.sh` | 同步 SOP 到已裝專案 | US-015 |

---

## 7. SOP Gate 5（RSI Gate）

> **⚠️ 設計陷阱**：`gates.schema.json` 中 `trigger_skill` regex 為 `^(dav-|tdd-|regression-|dev-|minimax-).*$`，
> **不接受** `sop-evolver`。US-012 執行時，**必須先改 schema regex 加 `sop-` 前綴**，
> 再改 gates.json 加 Gate 5，最後用 `ajv validate -s gates.schema.json -d gates.json` 驗證。
>
> 推薦順序：`schema.json` → `gates.json` → `ajv validate` （缺 ajv 驗證 → 不可合併）

在 `docs/sop/gates.json` 加 Gate 5：

```json
{
  "id": "gate-5",
  "name": "RSI gate",
  "trigger_skill": "sop-evolver",
  "pass_criteria": [
    "觀察記錄已寫入",
    "Reviewer subagent verdict 已產生",
    "用戶已批准或明確說「跳過 Reviewer」"
  ],
  "required_evidence": [
    "反省報告路徑",
    "改進提案 diff",
    "Reviewer verdict 路徑",
    "用戶批准訊息截錄"
  ],
  "fail_action": "不可合併 diff",
  "mandatory_phrase": "依 gates.json 規範，Gate 5 (RSI) 需要：反省報告 + 改進提案 diff + Reviewer 二審 verdict + 用戶批准截錄"
}
```

---

## 8. 觀察記錄 Schema（白名單）

```json
{
  "task_id": "uuid-v4",
  "project_id": "a3f7b2c1",           // SHA256(安裝路徑)[:8]
  "timestamp": "2025-09-21T14:30:00Z",
  "gate_results": {
    "gate-1-tdd": "pass",
    "gate-2-lint": "pass",
    "gate-3-regression": "fail",
    "gate-4-reviewer": "pass"
  },
  "skills_used": ["dav-planner", "tdd-test-writer"],
  "failure_signals": [
    {"gate": "gate-3-regression", "type": "test_timeout", "count": 2}
  ],
  "duration_seconds": 145
}
```

**黑名單（被拒絕）**：`raw_conversation` / `code_snippets` / `file_paths` / `env_values` / `git_messages`

---

## 9. 安全規則（不可違反，4 條）

1. **觀察/改動分離**：裝在專案裡的 tree_monstor **只能觀察**，不能改 SOP
2. **匿名化**：observation 只記結構化信號，不收 raw 對話 / code / 路徑
3. **Reviewer 二審必經**（V03）：所有 SOP 改動提案都走 dev-checker-loop 二審
4. **一鍵回滾**：每次合併自動寫 git tag，`rsi-rollback.sh` 從 rsi-log.md 找 diff 還原

---

## 10. Story Point 拆分

| ID | 子任務 | SP | Sprint |
|---|---|---|---|
| US-011 | 建立 sop-evolver skill（5 個檔案） | 5 | Sprint 09 |
| US-012 | 加 Gate 5 到 gates.json + Schema | 1 | Sprint 09 |
| US-013 | 寫 §2.8 handbook + AGENTS.md 引用 | 1.5 | Sprint 09 |
| US-014 | 寫 rsi-metrics.sh + rsi-rollback.sh | 2 | Sprint 09 |
| US-015 | 寫 rsi-aggregate.sh + rsi-propose.sh + rsi-sync.sh | 2 | Sprint 09 |
| US-016 | install.sh 加 --enable-rsi 旗標 | 1 | Sprint 09 |
| US-017 | Sprint 10 真實驗證 | 3 | Sprint 10 |
| TD-022 | 觀察記錄格式設計（安全） | 0.5 | Sprint 09 |
| **總計** | — | **16** | — |

**Sprint 09**：13 SP（Sprint 主題：建 RSI 機制）
**Sprint 10**：3 SP（Sprint 主題：真實驗證）

---

## 11. 驗收標準（高層次 AC）

- [ ] AC-1：`sop-evolver` skill 5 個檔案齊全，SKILL.md ≤ 150 行
- [ ] AC-2：裝在專案裡只能觀察、不能改 SOP（驗證：專案裡 `/evolve` 被拒絕）
- [ ] AC-3：裝回源 repo 跑 `/reflect`，自動收集 `~/.tree-monstor/observations/`
- [ ] AC-4：聚合分析後產出「跨專案改進提案」，每個附「影響專案數」
- [ ] AC-5：所有 SOP 改動以 diff 形式呈現，**未經批准絕不合併**
- [ ] AC-6：`rsi-rollback.sh` 一鍵回滾到任一歷史版本
- [ ] AC-7：`rsi-metrics.sh` 6 個量化指標
- [ ] AC-8：install.sh 加 `--enable-rsi` / `--disable-rsi` 旗標
- [ ] AC-9：所有 AC 有對應 bats 測試（≥ 15 個，含安全測試）
- [ ] AC-10：通過 5 個 Gate（含 Gate 5）

---

## 12. 風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
|---|---|---|---|
| 觀察意外洩漏敏感資料 | 中 | 高 | 白名單 + 黑名單 schema 強制 |
| 一處改 SOP 破壞多專案 | 中 | 高 | rsi-sync 不覆蓋 + git tag + 一鍵回滾 |
| 提案 hallucinate 出虛假問題 | 高 | 中 | 提案必須附「證據」（觀察 JSON 編號） |
| RSI 過度觸發 | 低 | 低 | 觀察自動累積，聚合隨時可跑 |
| 用戶忘了裝回源 repo 聚合 | 中 | 中 | rsi-metrics 每週提醒「N 個觀察待聚合」 |

---

## 13. 量化指標（6 個）

`tools/rsi-metrics.sh` 統計：

1. **任務完成率**（過 4 Gates / 啟動任務）
2. **規範違規次數**（未引用 mandatory_phrase）
3. **TD 閉環率**（產出 TD / 解決 TD）
4. **跨專案觀察分佈**（哪些專案最容易出問題）
5. **AGENTS.md 字數變化**（SOP 熵增追蹤）
6. **skill 使用頻率**（哪些 skill 被低度使用）

---

## 14. 關鍵決策記錄

| 決策 | 理由 | 用戶批准 |
|---|---|---|
| 焦點：SOP-Evolver 機制 | 與現有基礎契合度最高 | ✅ |
| 自動化：主動跨專案升級 | 觀察自動累積、改 SOP 必經人手 | ✅ |
| 觀察位置：`~/.tree-monstor/observations/` | 隱私、不污染 repo | ✅ |
| Reviewer 二審：寫進 V03 紀律 | 加強保護層、防止自我強化偏見 | ✅ |

---

## 15. 相關文件

- 系統設計：[`docs/system-design.md` §4](../system-design.md)
- PRD（Markdown）：[`docs/prd/04-self-evolution.md`](../prd/04-self-evolution.md)
- PRD（HTML，含 SVG 流程圖）：[`docs/prd/04-self-evolution.html`](../prd/04-self-evolution.html)
- 對應 Backlog：[`docs/backlog.md` US-011~017 + TD-022](../backlog.md)

---

## 16. 下一步

§2.2 設計完成，等用戶審核。批准後進入 **§2.3 執行階段**（4 Gate + Gate 5）。
