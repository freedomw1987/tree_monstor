---
name: ultrawork
description: Enable Claude Code harness mode — use Workflow/parallel/pipeline for complex multi-agent tasks. Spawns concurrent subagents, handles fan-out/fan-in patterns, and orchestrates large-scale development work.
trigger: "ultrawork | harness mode | workflow orchestration | parallel execution | fan-out | multi-agent coordination"
version: 1
category: autonomous-ai-agents
prerequisites:
  - orchestrator (理解任務協調基本概念)
  - task-board (任務追蹤機制)
---

# Ultrawork — Harness Mode for Complex Tasks

## 角色定位

**Ultrawork 是 Tree Monstor 的加速引擎** — 當任務複雜度需要多個 subagent 並行工作時，啟用 Claude Code 的 Workflow 引擎，讓 Tree Monstor 以 **harness mode** 全速運轉。

---

## 核心概念

### 什麼是 Harness Mode？

Harness mode = 善用 Claude Code 的 Workflow 工具來编排 subagent：

| 模式 | 做法 | 適用場景 |
|------|------|----------|
| **普通模式** | `claude --agent "role" "task"` 依序派發 | 簡單任務、探索性工作 |
| **Harness Mode** | `Workflow` + `agent()` + `parallel()` + `pipeline()` | 複雜、多階段、需要並行的任務 |

### 何時打開 Harness Mode？

打開信號（滿足任一條件）：

- [ ] 任務需要 3+ 個 subagent 同時工作
- [ ] 有明確的階段（phase）分化，需要屏障同步
- [ ] 需要「搜索 → 驗證 → 綜合」流程
- [ ] 工作量大（>50 tool calls）
- [ ] 用戶明確說「ultrawork」

---

## Workflow 語法速查

### 基本結構

```javascript
export const meta = {
  name: 'task-name',
  description: '任務描述',
  phases: ['Phase1', 'Phase2', 'Verify', 'Synthesize'],
}

phase('Phase1')

// 並行派發多個 subagent
const results = await parallel([
  () => agent('Research frontend options', {schema: OPTIONS_SCHEMA}),
  () => agent('Research backend options', {schema: OPTIONS_SCHEMA}),
  () => agent('Research infra options', {schema: OPTIONS_SCHEMA}),
])

// pipeline: 每個項目依序通過所有階段
const findings = await pipeline(
  files,
  file => agent(`Analyze: ${file}`, {schema: FINDING_SCHEMA}),
  finding => agent(`Verify: ${finding.title}`, {schema: VERDICT_SCHEMA}),
  verdict => agent(`Fix: ${verdict}`, {schema: FIX_SCHEMA}),
)
```

### 常用模式

#### 1. Fan-Out（向外擴散）

```javascript
export const meta = { name: 'bug-sweep', phases: ['Scan', 'Fix'] }

// 每個 bug 同時被處理（無需等待）
const fixesRes = await pipeline(
  bugs,
  bug => agent(`Fix: ${bug.title}`, {label: `fix:${bug.id}`, phase: 'Fix'}),
)
```

#### 2. Fan-In + Barrier（匯聚 + 屏障）

```javascript
// 等所有搜索完成後，統一處理
const [bugs, perf, security] = await parallel([
  () => agent('Find bugs', {schema: ISSUE_SCHEMA}),
  () => agent('Find perf issues', {schema: ISSUE_SCHEMA}),
  () => agent('Find security issues', {schema: ISSUE_SCHEMA}),
])
// barrier: 所有結果都回來了，才進入下一階段
const allIssues = dedupe(bugs, perf, security)
```

#### 3. Verify Before Act（先驗後行）

```javascript
const [pro, con] = await parallel([
  () => agent('Argue for: ' + recommendation, {schema: POSITION_SCHEMA}),
  () => agent('Argue against: ' + recommendation, {schema: POSITION_SCHEMA}),
])
```

#### 4. Loop-Until-Dry（直到乾涸）

```javascript
const bugs = []
while (budget.total && budget.remaining() > 50_000) {
  const result = await agent("Find bugs in this codebase.", {schema: BUGS_SCHEMA})
  bugs.push(...result.bugs)
  log(`${bugs.length} found`)
}
```

---

## 在 Tree Monstor 中使用 Ultrawork

### 觸發方式

```bash
# 方式 1: 用戶明確指示
/ultrawork 完成電商系統的所有後端 API

# 方式 2: 自動偵測（由 Developer 主體觸發）
# 當複雜度超過閾值，呼叫此 skill
```

### 作為 Subagent 使用

Developer 主體派發 ultrawork：

```
delegate_task(
    goal="使用 harness mode 完成代碼審查",
    context="""
    目標: PR #123 的完整審查
    需要: 正確性、簡潔性、架構、效能檢查
    """,
    role="ultrawork"  # 觸發 ultrawork skill
)
```

---

## 整合到現有流程

### Think/Plan/Build/Review/Test/Ship 中的位置

```
Think → Plan → 【Ultrawork HERE for complex planning】 → Build → 【Ultrawork HERE for parallel development】 → Review → Test → Ship → Reflect
```

### 常見應用場景

| 階段 | Ultrawork 應用 |
|------|---------------|
| **Think** | CEO + Researcher 並行市場/技術調研 |
| **Plan** | 4 人規劃團隊並行生成方案，評委投票 |
| **Build** | Frontend + Backend + DevOps 並行開發 |
| **Review** | 多角度審查並行（程式碼/架構/安全） |
| **Test** | E2E + 效能 + 安全掃描並行 |
| **Reflect** | 自動收集各階段指標 |

### 實例：PR 審查流程

```javascript
export const meta = {
  name: 'pr-review-workflow',
  description: 'Full PR review with multi-dimensional analysis',
  phases: ['Scan', 'Verify', 'Synthesize'],
}

phase('Scan')
const DIMENSIONS = [
  {key: 'bugs', prompt: 'Find correctness bugs. Check edge cases, null checks, error handling.'},
  {key: 'perf', prompt: 'Find performance issues. Check N+1 queries, redundant computations, large loops.'},
  {key: 'security', prompt: 'Find security issues. Check injections, auth, data exposure.'},
  {key: 'arch', prompt: 'Check architecture consistency. Is the design pattern correct?'},
]

const scans = await pipeline(
  DIMENSIONS,
  d => agent(d.prompt, {label: `scan:${d.key}`, schema: FINDING_SCHEMA}),
)

// Barrier: 等所有掃描完成
phase('Verify')
const VERIFY_SCHEMA = { /* ... */ }
const verified = await pipeline(
  scans.filter(Boolean).flat(),
  f => agent(`Adversarially verify: ${f.title}`, {schema: VERIFY_SCHEMA}),
)

// Synthesis
phase('Synthesize')
log(`Confirmed issues: ${verified.filter(v => v.isReal).length}`)
return { confirmed: verified.filter(v => v.isReal) }
```

---

## 與其他 Skill 的協作

```
┌─────────────────────────────────────────────────────┐
│                   Developer 主體                      │
│  (整合 ultrawork skill 進入 orchestrator skill 可選)   │
└───────────────────────┬─────────────────────────────┘
                        │ 派發
                        ▼
┌─────────────────────────────────────────────────────┐
│                Ultrawork Subagent                     │
│  (作為 Workflow 引擎，包裝 Tree Monstor subagent 矩陣) │
└───────────────────────┬─────────────────────────────┘
                        │ agent() 派發
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
     ┌─────────┐  ┌─────────┐  ┌─────────┐
     │  BA     │  │  SA     │  │ Designer│
     │ Subagent│  │ Subagent│  │ Subagent│
     └─────────┘  └─────────┘  └─────────┘

注意: Ultrawork 是 Workflow 引擎，不是 leaf subagent。
      它負責調度，而非親自執行。
```

---

## 常見錯誤與修正

| 錯誤 | 修正 |
|------|------|
| Barrier 不當使用（明明不需要等待全部） | 改用 `pipeline`，各項目獨立通過階段 |
| `parallel()` 內放同步代碼 | 把同步邏輯提取到 `pipeline` 各 stage 內 |
| `phase()` 標題與 `meta.phases` 不匹配 | 確保 phase 名稱一致 |
| 忘記 `budget.remaining()` guard | 添加 `while (budget.total && budget.remaining() > 50_000)` |
| Agent 結果為 null（用戶 Skip） | 使用 `.filter(Boolean)` 過濾 |

---

## 進階技巧

### 1. 動態並行度（根據預算調整）

```javascript
const FLEET = budget.total
  ? Math.floor(budget.remaining() / 100_000)  // tokens 越多，並行度越高
  : 5  // default

const BATCH_SIZE = Math.max(1, Math.min(FLEET, 16))
// 把任務分成 BATCH_SIZE 大小的批次，逐步處理
```

### 2. Adversarial Verify（對抗驗證）

```javascript
// 每個發現由 3 個 skeptic 同時驗證
const votes = await parallel([1,2,3].map(() => () =>
  agent(`REFUTE: ${claim}`, {schema: VERDICT_SCHEMA})
))

// 只有 ≥2 個 skeptical 認可，才保留
const survives = votes.filter(Boolean).filter(v => !v.refuted).length >= 2
```

### 3. 結果緩存（Resume）

```javascript
// 相同的 (prompt + opts) 會自動使用緩存結果
// 所以可以先做粗略搜索，再細化，不需要重新計算
```

### 4. Worktree 隔離（隔離開發）

```javascript
// 當 subagent 需要改檔並行時，用 worktree 避免衝突
const fix = await agent('Fix this bug', {
  label: `fix:${bug.id}`,
  isolation: 'worktree',  // 隔離工作區
})
```

---

## 觸發決策樹

```
收到任務
  │
  ├─ 複雜度 < 3 個並發 subagent？
  │     └─ 是 → 用普通模式 或 orchestrator 直接派發
  │
  ├─ 有明確 phase 順序需要屏障？
  │     └─ 是 → Workflow with parallel + barrier
  │
  ├─ 是「搜索 → 驗證 → 綜合」流程？
  │     └─ 是 → pipeline + adversarial verify
  │
  └─ 用戶說 ultrawork / 需要高吞吐量？
        └─ 是 → Workflow with loop-until-dry
```

---

## 關鍵原則

1. **先用普通模式試探** — 如果簡單，別過度複雜化
2. **屏障只在真正需要時用** — 不然浪費等待時間
3. **`pipeline` 是默認** — 各項目並行通過所有階段
4. **adversarial verify 提升質量** — 對抗性驗證讓結論更可靠
5. **Budget-aware** — 根據 token 預算動態調整並行度

---

## 參考資料

- Claude Code `--agent` flag documentation
- Workflow tool API: `agent()`, `parallel()`, `pipeline()`, `phase()`, `log()`, `budget`
- Tree Monstor Orchestrator Skill: `/Users/davidchu/www/tree_monstor/skills/orchestrator/SKILL.md`
- Tree Monstor Subagent Matrix: `/Users/davidchu/www/tree_monstor/MEMORY.md`
