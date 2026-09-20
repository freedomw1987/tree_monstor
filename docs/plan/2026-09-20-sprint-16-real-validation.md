# Sprint 16 規劃 — RSI 真實專案驗證（2026-09-20）

> **對應 §2.1 dav-planner**
> **Sprint**：Sprint 16 RSI 真實專案驗證
> **SP**：3 SP（推薦）
> **狀態**：🟡 Planning

---

## 1. Sprint 16 主軸

**主軸**：把 RSI 完整機制裝到真實中型 Web App 上，驗證完整閉環。

Sprint 09-15 已建立 14 個 RSI 工具 + 12 條規則 + 完整閉環圖。
**但從未跑過真實專案驗證**。

Sprint 16 是把 RSI 從「工具齊全」進化到「實戰可用」的關鍵 Sprint：

```
觀察 → 聚合 → 趨勢 → 回顧 → 警告 → 反推 → 找相似 → 規則 review → SOP 改動
```

要在 `lemontree_aws`（Bun + TypeScript 中型 Web App）走一遍。

---

## 2. 驗證目標

### 2.1 觀察期（1 SP）

在 `lemontree_aws` 上裝 RSI，觀察 7 天，收集事件類型。

**具體動作**：
1. 跑 `install.sh --enable-rsi`（預設）— 部署 sop-evolver skill + 設 cron
2. 確認 `~/.tree-monstor/observations/lemontree_aws/<日期>.json` 有產出
3. 觀察 7 天（實時，無需等待）— Sprint 11 US-019 真實部署跑過 14 天，這次縮為 7 天

**觀察事件類型預期**：
- TypeScript 編譯錯誤（bun build fail）
- ESLint 錯誤（lint fail）
- Playwright 測試 fail（e2e test）
- Drizzle migration 錯誤
- Docker compose 啟動失敗

### 2.2 反推期（1 SP）

跑 `rsi-propose --show-similar` 看實際事件類型是否對應規則庫：

**預期對應**：
- TypeScript 編譯錯誤 → 規則庫無（需新增 `typescript_*` 系列）
- ESLint 錯誤 → 規則庫無（需新增 `eslint_*` 系列）
- Docker 啟動失敗 → 規則庫無（需新增 `docker_*` 系列）
- bash 測試錯誤 → 規則庫已有（`bash_*` 系列）

**具體動作**：
1. 跑 `rsi-aggregate.sh` 看跨日觀察結果
2. 跑 `rsi-propose.sh --show-similar --rules docs/sop/rsi-rules.md` 看相似對
3. 比對觀察事件 vs 規則庫（gap analysis）

### 2.3 規則 review（1 SP）

依 gap analysis 結果，更新規則庫到 15-18 條：

**具體動作**：
1. 新增 `typescript_*` / `eslint_*` / `docker_*` 系列規則
2. 跑 `rsi-rules-review.sh` 看新相似對
3. **不強求人類決策合併**（保持精簡原則）

---

## 3. 候選評估（為何不做 US-032/033/034）

| ID | 評估 | 決定 |
| --- | --- | --- |
| US-032 人類決策合併 | 規則庫 12 → 15-18 後可能觸發 | 可在 Sprint 16 內順帶做 |
| US-033 規則庫 CI 整合 | 規則庫 < 20 條，無需求 | **不做** |
| US-034 跨專案規則去重 | Sprint 16 跑通後再做 | 留 Sprint 17+ |

---

## 4. Sprint 16 vs Sprint 11 對比

| 維度 | Sprint 11 US-019 | Sprint 16 |
| --- | --- | --- |
| 觀察期 | 14 天 | **7 天**（效率提升）|
| 規則庫 | 12 條 | 從 12 條開始，看實際事件擴展 |
| 反推 | 純人工 | **rsi-propose --show-similar 自動** |
| Review | 人工 | **rsi-rules-review 自動** |
| RSsync dry-run | 還沒做（Sprint 14 才加）| **可順帶驗證 sync** |

---

## 5. 風險評估

| 風險 | 機率 | 影響 | 緩解 |
| --- | --- | --- | --- |
| lemontree_aws 沒事件產生 | 中 | 中 | 手動跑 bun build / lint 觸發事件 |
| TypeScript 事件太技術、難分類 | 高 | 低 | 規則粒度放粗（`typescript_*` 即可）|
| 觀察 JSON schema 不符合 | 低 | 高 | 跑前先手動驗 `rsi-aggregate.sh` 接受格式 |
| install.sh 改 lemontree_aws 壞東西 | 低 | 高 | `--dry-run` 預覽後再跑（rsi-sync dry-run 已對齊）|

---

## 6. 完成定義（DoD）

- [ ] `install.sh --enable-rsi` 已對 `lemontree_aws` 跑過（含 `--dry-run` 預覽）
- [ ] `~/.tree-monstor/observations/lemontree_aws/<日期>.json` 至少 3 天有產出
- [ ] `rsi-aggregate.sh` 能聚合觀察
- [ ] `rsi-propose --show-similar` 能找到相似對
- [ ] 規則庫擴展到 15-18 條
- [ ] `rsi-rules-review.sh` 產出新 REVIEW.md（markdownlint 0 errors）
- [ ] ≥ 2 個新 bats 全綠（含實際 lemontree_aws 觀察測試）
- [ ] §2.2 設計 + §2.3 執行 + §2.4 反省 + §2.5 提交 + commit

---

## 7. 不在 Sprint 16 範圍

- 自動化 sprint commit / push（留 Sprint 17+）
- 多機器規則庫同步（US-034 留 Sprint 17+）
- Slack/email 通知（US-031 仍 P4）

---

## 8. Sprint 17 候選預覽

| 候選 | 說明 |
| --- | --- |
| US-034 跨專案規則去重 | 跨 lemontree_aws + tree_monstor 同步規則庫 |
| 自動化觀察 → commit | 觀察觸發 SOP 改動後自動 commit |
| 規則庫 v2 結構 | event_type 改用樹狀前綴 |

---

## 9. Sprint 16 量化預期

| 指標 | Sprint 15 末 | Sprint 16 末 | 變化 |
| --- | --- | --- | --- |
| 規則庫 | 12 | 15-18 | +3-6 |
| 觀察事件類型 | 0（lemontree_aws）| ≥ 5 | +5 |
| FR | 28 | 29（+4.29）| +1 |
| 累計 SP | 42.5 | **45.5** | **+3** |

---

## 10. 結語

Sprint 16 是 RSI 機制的**最終驗證**：

- Sprint 09-13：建 RSI 機制
- Sprint 14：成熟化（dry-run / 相似度 / review）
- Sprint 15：規則庫實戰（建 12 條 + 修 3 個 Sprint 14 BUG）
- **Sprint 16：真實專案驗證**（裝到 lemontree_aws 走完整閉環）

完成 Sprint 16 後，RSI 從「實驗室工具」進化到「可在多專案使用」。

---

## 11. 計劃摘要

**Sprint 16**：US-035（RSI 真實專案驗證，3 SP）
- 階段 1：裝到 lemontree_aws 觀察 7 天（1 SP）
- 階段 2：rsi-propose 反推 + gap analysis（1 SP）
- 階段 3：規則庫擴展 + review（1 SP）

**累計**：45.5 SP（Sprint 09-16，11 個 Sprint）
