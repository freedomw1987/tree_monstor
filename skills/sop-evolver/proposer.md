# proposer.md — 提案生成規範

> **對應 SKILL.md**：[`SKILL.md`](./SKILL.md) §3 子模組
> **對應 SOP**：[`docs/sop/handbook/2.8-rsi-evolution.md`](../../../docs/sop/handbook/2.8-rsi-evolution.md) §4
> **對應 Backlog**：[`docs/backlog.md`](../../../docs/backlog.md) — Sprint 09 US-013 起持續擴充

---

## 1. 用途

定義「提案生成」規範：聚合報告 → 候選 diff 提案（含 confidence score）。

提案模式**只在源 repo**跑。

---

## 2. 提案流程

```
1. 讀聚合報告（rsi-aggregated-{date}.md）
   ↓
2. 對每個 Top N 信號產生「候選提案骨架」
   ↓
3. 計算 confidence score
   ↓
4. 標記 主要提案（≥ 0.7）OR 低信心（需人工確認）
   ↓
5. 寫 docs/sop/rsi-proposals/{date}-{NN}.md
   ↓
6. ⚠️ Reviewer 二審（V03 必經）
```

---

## 3. Confidence Score

```
confidence = min(1.0, freq × 0.05 + projects × 0.1)
```

| 頻次 | 跨專案數 (impact) | confidence | 標記 |
|---|---|---|---|
| 10 | 5 | 1.0 | ✅ 主要提案 |
| 5 | 3 | 0.55 | ⚠️ Low Confidence |
| 1 | 1 | 0.15 | ⚠️ Low Confidence |

**影響專案數**（impact）= 觀察到此信號的 distinct project_id 數。

---

## 4. 提案模板

```markdown
# RSI 提案 #{NN} — {date}

## 問題描述
（從聚合報告摘錄）

## 證據 (evidence)
（聚合報告引用 + 跨專案觀察數）

## 影響 (impact)
（影響專案數、頻次）

## 提案修法
（diff 草稿）

## Confidence
{score} — {主要/Low Confidence}

## 預期效益
（簡述）

## 風險分級
🟢/🟡/🔴

## 回滾計畫 (rollback)
（git tag rsi-v{date}-{NN} + rsi-rollback.sh）

## 驗收標準
- [ ] ...

## 相關文件
- ...
```

---

## 5. 工具

---

### 5.1 rsi-propose.sh

```bash
./tools/rsi-propose.sh [options]

--report FILE           # 聚合報告路徑
--confidence N          # 信心門檻（預設 0.7）
--min-freq N            # 最小頻次（預設 3）
--output-format text    # 或 json（Sprint 12 TD-037）
```

### 5.2 內建規則庫（lookup_proposal）

```bash
case "$signal_type" in
  1) echo "..." ;;  # duplicate_question
  2) echo "..." ;;  # gate_skip
  3) echo "..." ;;  # session_no_complete
  4) echo "..." ;;  # prd_no_update
  5) echo "..." ;;  # review_skip
  6) echo "..." ;;  # long_session
  7) echo "..." ;;  # repetitive_error
  8) echo "..." ;;  # unclear_requirement
  9) echo "..." ;;  # circular_ref（Sprint 11 US-020）
  10) echo "..." ;; # skill_timeout（Sprint 11 US-020）
  11) echo "..." ;; # agent_hang（Sprint 11 US-020）
  12) echo "..." ;; # commit_no_msg（Sprint 11 US-020）
esac
```

---

## 6. Reviewer 二審必經（V03 紀律）

所有提案**必經** `dev-checker-loop` Reviewer subagent 二審，產出 `docs/sop/rsi-reviewer-verdict-{date}.md`：

- 風險分級（🟢/🟡/🔴）
- 跨 SOP 一致性檢查
- 修改建議

用戶收到「diff + verdict」兩者並呈。

---

## 7. 故障排除

| 症狀 | 處理 |
|---|---|
| 沒有提案產生 | 調低 `--confidence` 或 `--min-freq` |
| Proposal 全是 Low Confidence | 加更多觀察天數 |

---

## 8. 版本

- v1.0（2025-09-20）— 隨 Sprint 09 US-013 引入
- v1.0（2025-09-20）— Sprint 10 規則庫擴充到 8 個
- v1.0（2025-09-20）— Sprint 11 規則庫擴充到 12 個 + confidence score
- v1.0-fix（2026-09-20）— Sprint 12 重建，源檔案修復
