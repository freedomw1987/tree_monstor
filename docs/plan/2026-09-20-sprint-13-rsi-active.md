# Sprint 13 規劃 — RSI 主動化（2026-09-20）

> **對應 §2.1 dav-planner**
> **主軸**：RSI 主動化
> **SP**：4 SP（TD-037 + US-023 + US-024 + SP-005）

## 1. Sprint 目標

Sprint 09-12 把 RSI 從無到有（觀察→聚合→改 SOP），加上回顧 + 告警被動→主動監控。Sprint 13 進一步「主動化」：

1. **TD-037**：rsi-propose 加 JSON output（讓 Agent 可解析、cron 可讀）
2. **US-023**：rsi-deploy.sh 自動部署小型工具（從手動到 1 鍵）
3. **US-024**：rsi-rollback 加 dry-run（先看再滾，避免誤滾）
4. **SP-005**：跨專案規則去重（兩個 mock 專案觀察到同類事件如何合併）

## 2. 用戶故事（4 個，4 SP）

| ID | 類型 | 標題 | 優先級 | SP | 對應 FR |
|---|---|---|---|---|---|
| TD-037 | TD | rsi-propose 加 `--output-format json` | P3 | 1 | FR-4.21 |
| US-023 | US | rsi-deploy.sh 自動部署小型工具 | P3 | 2 | FR-4.22 |
| US-024 | US | rsi-rollback 加 dry-run | P3 | 1 | FR-4.23 |
| SP-005 | SP | 跨專案規則去重研究 | P3 | 2 | FR-4.24 |
| **小計** | | | | **6** | |

## 3. 詳細 AC

### TD-037（1 SP）

- [ ] 加 `--output-format json` 旗標
- [ ] 輸出結構化 JSON（含 rules + confidence + evidence）
- [ ] 既有 `text` 格式保留
- [ ] ≥ 3 個 bats 驗證
- [ ] markdownlint 0 issues

### US-023（2 SP）

- [ ] 建新工具 `tools/rsi-deploy.sh`
- [ ] 1 鍵部署小型 web app（含 Node.js / Python 任一）
- [ ] 自動加 cron（每日 metrics + alert）
- [ ] 自動跑 `rsi-aggregate.sh` 驗證部署
- [ ] ≥ 4 個 bats
- [ ] markdownlint 0 issues

### US-024（1 SP）

- [ ] 加 `--dry-run` 旗標到 rsi-rollback.sh
- [ ] 列出將被回滾的變更（檔案清單 + commit hash）
- [ ] 不實際執行 git reset / tag delete
- [ ] ≥ 3 個 bats
- [ ] markdownlint 0 issues

### SP-005（2 SP）

- [ ] 寫 `docs/research/2026-09-20-cross-project-rule-dedup.md`
- [ ] 3 個 mock 測試（同類事件在 2 個專案都出現）
- [ ] 結論：是否要合併、如何合併、合併後的規則庫結構
- [ ] ≥ 3 個 bats

## 4. 順序與依賴

```
SP-005（研究先做，給 TD-037 輸入）
  ↓
TD-037（JSON output）
  ↓
US-024（dry-run 簡單）
  ↓
US-023（deploy 複雜）
```

依賴關係：
- TD-037 不依賴其他
- US-024 不依賴其他
- US-023 不依賴其他
- SP-005 不依賴其他，但產出可影響 Sprint 14

## 5. 風險與緩解

| 風險 | 機率 | 影響 | 緩解 |
|---|---|---|---|
| US-023 部署失敗（環境問題）| 🟡 中 | 🟡 中 | mock app + containerized |
| SP-005 結論「不需合併」→ 浪費 2 SP | 🟡 中 | 🟢 低 | 至少產出技術評估文檔（不虧）|
| TD-037 JSON 格式不對 | 🟢 低 | 🟢 低 | schema 對齊 `rsi-aggregate.sh` 輸出 |

## 6. 量化指標預期

| 指標 | Sprint 12 末 | Sprint 13 末 | 變化 |
|---|---|---|---|
| 工具 | 12 | 13（+rsi-deploy.sh）| +1 |
| 規則庫 | 12 | 12~14 | +0~2 |
| bats | 250 | 263（+13）| +13 |
| FR | 20 | 24 | +4 |
| 累計 SP | 32.5 | 38.5 | +6 |

## 7. 預期效益

1. **TD-037**：rsi-propose 輸出可被 Agent 解析 → cron 自動套用
2. **US-023**：手動部署→1 鍵部署 → 部署時間 30 分鐘 → 5 分鐘
3. **US-024**：先看再滾 → 避免誤滾
4. **SP-005**：跨專案規則去重 → 規則庫不爆

## 8. 下一步

Sprint 13 §2.2 設計：
- PRD §11.6
- system-design ADR-021/022/023
- Reviewer verdict

## 9. Sprint 13 量化目標

| 指標 | 目標 |
|---|---|
| 全部 4 SP 完成 | ✅ |
| 13 新 bats 全綠 | ✅ |
| markdownlint 新加部分 0 issues | ✅ |
| Reviewer 二審通過 | ✅ |
| 5 Gate 通過 | ✅ |

## 10. 完成 Sprint 13 §2.1 規劃

進 §2.2 設計。
