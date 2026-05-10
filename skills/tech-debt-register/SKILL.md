---
name: tech-debt-register
description: 記錄和追蹤技術債，幫忙估算修復時間。Template based，系統化追蹤優先級、修復成本、業務影響。
trigger: "tech debt / 技術債 / 技術負債 / debt register"
version: 1
category: productivity
---

# Tech Debt Register

系統化記錄、優先級排序、和規劃償還技術債。

## Tech Debt 模板

```markdown
# Tech Debt Register — {project_name}

## 條目格式
| ID | 描述 | 模組 | 優先級 | 修復成本 | 業務影響 | 狀態 | 日期 |

### 優先級定義
- **P0 (Critical)**: 影響核心功能或安全，立即修復
- **P1 (High)**: 影響開發效率，1-2週內修復
- **P2 (Medium)**: 技術上有問題，下個 sprint 修復
- **P3 (Low)**: 可忽略或下次重構時處理

### 修復成本估算
- **S (Small)**: < 4 小時
- **M (Medium)**: 4-16 小時
- **L (Large)**: 16-40 小時
- **XL (Extra Large)**: > 40 小時（需要單獨 sprint）

---

## P0 — Critical

| ID | 描述 | 模組 | 修復成本 | 業務影響 | 狀態 | 日期 |
|----|------|------|---------|---------|------|------|
| TD-001 | 密碼明文存儲 | Auth | M | 安全風險 | TODO | 2026-05-10 |

---

## P1 — High

| ID | 描述 | 模組 | 修復成本 | 業務影響 | 狀態 | 日期 |
|----|------|------|---------|---------|------|------|
| TD-002 | API 沒有 rate limiting | API | S | DDoS 風險 | TODO | 2026-05-10 |

---

## P2 — Medium

| ID | 描述 | 模組 | 修復成本 | 業務影響 | 狀態 | 日期 |
|----|------|------|---------|---------|------|------|
| TD-003 | 環境變量硬編碼 | Config | S | 部署風險 | TODO | 2026-05-10 |

---

## P3 — Low

| ID | 描述 | 模組 | 修復成本 | 業務影響 | 狀態 | 日期 |
|----|------|------|---------|---------|------|------|
| TD-004 | 棄用的 CSS class | Frontend | S | 維護困難 | TODO | 2026-05-10 |
```

## 使用方式

### 識別 Tech Debt
當發現以下情況時，立即記錄：
- 臨時解決方案（workaround）
- 重複代碼超過 3 次
- 沒有測試覆蓋的關鍵代碼
- 已知性能問題
- 安全漏洞或潛在風險

### 觸發 Subagent
```python
delegate_task(
    goal="記錄新發現的技術債",
    context="""
    描述：API 沒有 rate limiting
    模組：backend/api
    優先級：P1
    修復成本：S (< 4 小時)
    業務影響：DDoS 風險
    """,
    role="leaf",
    toolsets=['terminal', 'file']
)
```

### Sprint Planning
在每個 sprint planning 時：
1. 讀取 `docs/tech-debt.md`
2. 選擇該 sprint 能完成的 TD（根據修復成本）
3. 在 sprint backlog 中加入 Tech Debt 償還任務
4. 目標：每個 sprint 償還 1-2 個 P1 TD

## 償還原則

1. **先高優先級**：P0 > P1 > P2 > P3
2. **先低成本**：同優先級時，先做 S 再做 M/L/XL
3. **業務影響**：同優先級時，先做高業務影響的
4. **不要累积**：發現就記錄，不要假裝看不見
5. **償還時間**：估算 × 2（實際通常更久）