# 設計草案：Skill 自包含化（examples 進 skills）

| 項目 | 值 |
|------|-----|
| 日期 | 2026-09-26 |
| 對應 Backlog | TD-019（skill 自包含化） |
| Module | dav-skill-creater（本 skill 觸發）+ 5 個受影響 skill |
| 動機 | 讓 skill 自包含、可離線用（Q1） |
| 範例來源 | 直接搬原檔 + 不改（Q2） |
| 交叉引用段 | 更新為「見本 skill 的 `examples.md`」（Q3） |
| 流程 | 先出設計草案 + Reviewer 雙審（Q4） |

---

## 1. 為什麼做這個改動

### 1.1 問題

上個 §3（2026-09-26）清完 5 個 skill 的「`examples/module-lifecycle/...`」具體 path 引用後，採抽象詞「見 monorepo 對應的 X」處理 — 但**這只是「引用違規清掉」，範例本身仍是 monorepo 約束**。

**實際痛點**：
- skill 搬到非 `tree_monstor/` 的 monorepo 就找不到範例（破壞 v2.2 「skill 獨立搬動」初衷）
- LLM 讀到「見 monorepo 對應的 X」無法離線讀，注意力被打斷
- 範例散落在 `examples/module-lifecycle/` 與 skills 兩個地方 → 維護負擔 ×2

### 1.2 為什麼是現在做

1. **剛清完存量**：5 個 skill 都在 v2.4 變動歷史剛更新過，CHANGELOG.md 是新的 → 加新條目不擾亂既有歷史
2. **探針剛建好**：共用 bats 探針 `restruct-no-cross-dir-path.bats` 還熱 → 可順手擴展支援「skill 子檔例外」白名單
3. **範例檔未腐爛**：剛 v2.6/v2.3/v2.10/v2.2/v2.2 對應的版本基線，不會發現「範例 v3 與 skill v2.5 不對齊」問題

---

## 2. 5 份 skill 的改動規劃

### 2.1 改動總覽

| Skill | 搬入範例 | 檔名（建議）| 來源 | 大小 |
|-------|---------|-------------|------|------|
| **dav-designer** | system-design.md | `examples/system-design.md` | `examples/module-lifecycle/docs/system-design.md` | 152 行 / 5.2 KB |
| **dav-planner** | backlog.md | `examples/backlog.md` | `examples/module-lifecycle/docs/backlog.md` | 136 行 / 6.7 KB |
| **dev-checker-loop** | checklist.md | `examples/checklist.md` | `examples/module-lifecycle/checklist.md` | 109 行 / 3.9 KB |
| **dav-submitter** | deliverable-sample.md | `examples/deliverable-sample.md` | `examples/module-lifecycle/deliverable-sample.md` | 210 行 / 10 KB |
| **regression-guard** | probes/ (3 個 .ts) | `examples/probes/` | `examples/module-lifecycle/probes/*.ts` | 55+77+53 = 185 行 / 5.3 KB |
| **README.md（範例總索引）** | 不搬入任何 skill | 留在 monorepo 原處 | `examples/module-lifecycle/README.md` | 87 行 / 4.8 KB |

### 2.2 每個 skill 的具體動作

#### dav-designer
1. `cp examples/module-lifecycle/docs/system-design.md ~/.pi/agent/skills/dav-designer/examples/system-design.md`
2. SKILL.md L105 改：「見 monorepo 對應的 X」 → 「見本 skill 的 `examples/system-design.md`」
3. **主檔變動歷史**：當前 3 條（v2.4/v2.3/v2.2）→ 加 v2.5 後變 4 條 → **觸發 v2.4 外移**（最舊 v2.2 移到 CHANGELOG.md）
4. CHANGELOG.md 加 v2.5 條目（自包含化）+ v2.2 條目（外移紀錄）
5. 不動探針（不改 SKILL.md 結構）

#### dav-planner
1. `cp examples/module-lifecycle/docs/backlog.md ~/.pi/agent/skills/dav-planner/examples/backlog.md`
2. SKILL.md L104 改為「見本 skill 的 `examples/backlog.md`」
3. **主檔變動歷史**：當前 3 條（v2.4/v2.3/v2.2）→ 加 v2.5 後變 4 條 → **觸發 v2.4 外移**（最舊 v2.2 移到 CHANGELOG.md）
4. CHANGELOG.md 加 v2.5 條目（自包含化）+ v2.2 條目（外移紀錄）

#### dev-checker-loop
1. `cp examples/module-lifecycle/checklist.md ~/.pi/agent/skills/dev-checker-loop/examples/checklist.md`
2. SKILL.md 改為「見本 skill 的 `examples/checklist.md`」
3. **主檔變動歷史**：當前 3 條（v2.2/v2.1/v2.0）→ 加 v2.3 後變 4 條 → **觸發 v2.4 外移**（最舊 v2.0 移到 CHANGELOG.md）
4. CHANGELOG.md 加 v2.3 條目（自包含化）+ v2.0 條目（外移紀錄）

#### dav-submitter
1. `cp examples/module-lifecycle/deliverable-sample.md ~/.pi/agent/skills/dav-submitter/examples/deliverable-sample.md`
2. SKILL.md 改為「見本 skill 的 `examples/deliverable-sample.md`」
3. **主檔變動歷史**：當前 4 條已瘦身過（v2.3/v2.2/v2.1/v2.0）→ 加 v2.4 後變 5 條 → **再次瘦身**（v2.0 已外移過，再外移一條？）

> ⚠️ **設計卡點**：dav-submitter 主檔第 2 次外移 v2.0 已是極限，不可能再外移。需要決定是否合併變動條目、或者接受主檔變 4 條。

**dav-submitter 解法（F3 修正）**：把這次 + 上次清存量的變動合併成「v2.4 批次清理 + 自包含化」一條。主檔加這條後仍是 4 條（v2.4/v2.3/v2.2/v2.1），CHANGELOG.md 補一條詳細紀錄。**合併條目「為什麼」欄位寫法**：
```
v2.4 合併 v2.3（清存量）+ 本次自包含化：合併理由 — 主檔 4 條已達 v2.4 規範上限，再加會違規；可追溯性由 CHANGELOG.md 補條目保證；V03 Reviewer 二審通過
```

#### regression-guard
1. `mkdir -p ~/.pi/agent/skills/regression-guard/examples/probes && cp examples/module-lifecycle/probes/*.ts ~/.pi/agent/skills/regression-guard/examples/probes/`
2. SKILL.md 改為「見本 skill 的 `examples/probes/`」
3. **主檔變動歷史**：當前 3 條（v2.10/v2.9/v2.8）→ 加 v2.11 後變 4 條 → **觸發 v2.4 外移**（最舊 v2.8 移到 CHANGELOG.md）
4. CHANGELOG.md 加 v2.11 條目（自包含化）+ v2.8 條目（外移紀錄）

### 2.3 5 段結構 + 150 行上限衝擊

- 每個範例**都搬進 skill 子目錄**，**SKILL.md 不變長**（因為用「見本 skill 的 `examples/...md`」一行同長度替換）
- 但每個 skill 多了 `examples/` 子目錄 — 這是新增子檔、**不算 SKILL.md 行數**
- 5 個 skill 主檔行數不會被破壞 ✅

### 2.4 探針影響（F2 修正）

共用探針 `restruct-no-cross-dir-path.bats` 需擴展。**正確邏輯順序**：「先檢查禁用字串，白名單作為內部例外」+「加 fail 結論」：

```bash
@test "no skill SKILL.md contains examples/module-lifecycle/ without whitelist exception" {
  local violations=0
  for f in "$SKILLS_DIR"/*/SKILL.md; do
    if grep -q 'examples/module-lifecycle' "$f"; then
      # 例外：白名單字串可通過
      if ! grep -qE '見本 skill 的 `examples/' "$f"; then
        echo "VIOLATION: $f still references examples/module-lifecycle/" >&2
        violations=$((violations + 1))
      fi
    fi
  done
  [ "$violations" -eq 0 ]
}
```

> **設計理由**：v2.2 例外明確寫「skill 子檔可用 markdown」，現在要讓探針實質支持。**白名單精準匹配**「見本 skill 的 `examples/`」（反引號必含），不接受「見 monorepo」、「見 docs/」、「`../examples/`」等變體。

### 2.4.1 版本基線探針（F4 新增）

為防範例與 skill 版本漂移，新增 1 個探針 `check-examples-version-baseline.bats`：

```bash
@test "each example file declares its skill version baseline" {
  local violations=0
  for f in "$SKILLS_DIR"/*/examples/*.{md,ts}; do
    if ! grep -qE '對應 skill 版本基線：v[0-9]+\.[0-9]+' "$f"; then
      echo "VIOLATION: $f missing skill version baseline marker" >&2
      violations=$((violations + 1))
    fi
  done
  [ "$violations" -eq 0 ]
}
```

> **必做**：每個範例檔的 frontmatter 或首段必含「對應 skill 版本基線：v?.?」標記。

### 2.5 交叉引用段改寫模板

| 現有 | 改為 |
|------|------|
| `見 monorepo 對應的 Module 完整生命週期範例（含 system-design.md / backlog.md / ...；位置由 monorepo 約定）` | `見本 skill 的 `examples/system-design.md`` |
| `見 monorepo 對應的 Module 完整生命週期範例（含 backlog.md；位置由 monorepo 約定）` | `見本 skill 的 `examples/backlog.md`` |
| `見 monorepo 對應的 Module 完整生命週期範例（含 checklist.md；位置由 monorepo 約定）` | `見本 skill 的 `examples/checklist.md`` |
| `見 monorepo 對應的 Module 完整生命週期範例（含 deliverable-sample.md；位置由 monorepo 約定）` | `見本 skill 的 `examples/deliverable-sample.md`` |
| `見 monorepo 對應的 Module 完整生命週期範例（含 probes/；位置由 monorepo 約定）` | `見本 skill 的 `examples/probes/`` |

**全部符合 v2.2 例外**：「skill 子檔可用 markdown」+「同 dir 子檔引用」 ✅

### 2.6 範例總索引（README.md）的處置

**選項 C（推薦）**：保留 `examples/module-lifecycle/README.md` 在原處。

理由：
- 跨 skill 視角（5 skill 怎麼對接）是 monorepo 級概念，不是單 skill 級
- 5 skill 自包含化後，README.md 仍可作為「完整生命週流程大圖」給 monorepo 用戶讀
- 不破壞 monorepo 既有用法

**替代方案**：把 README.md 拆成 5 個片段，分別進對應 skill。但**失去「跨 skill 對接」視角** → 不推薦。

---

## 3. 不做的（明確排除）

| 不做 | 為什麼 |
|------|-------|
| 不搬 README.md | 跨 skill 視角不是單 skill 概念 |
| 不動 5 份 skill 的子檔結構（workflow.md / reference.md / etc.）| 本次任務範圍限定「examples 進 skills」，其他子檔不動 |
| 不重寫範例內容 | 用戶決策 Q2「直接搬原檔 + 不改」 |
| 不刪除 monorepo 原檔 `examples/module-lifecycle/` | 保留作為「範例總索引」位置 |
| 不動 SOP 全域變動歷史 | 本次只動 5 個 skill |

---

## 4. 風險評估

### 4.1 高風險

| 風險 | 緩解 |
|------|------|
| dav-submitter 主檔第 2 次瘦身卡點（v2.0 已外移過） | 採方案：合併條目「v2.4 批次清理 + 自包含化」為一條；主檔仍 4 條、CHANGELOG.md 補一條詳細紀錄 |

### 4.2 中風險

| 風險 | 緩解 |
|------|------|
| 範例內容與 skill 版本漂移（skill v3.0 改了但範例還是 v2.x）| 範例 frontmatter / 註解加「對應 skill 版本基線：v?.?」標記，後續 release 必同步更新 |
| README.md 與新結構不同步（仍寫「見 `probes/`」而 skill 改用 `examples/probes/`）| README.md 加一段 v?.? 後變動紀錄 |
| 探針白名單被濫用（未來有人寫「見 monorepo 對應的 examples/」也通過）| 探針白名單精準匹配「見本 skill 的 `examples/`」字串，不接受「見 monorepo」 |

### 4.3 低風險

| 風險 | 緩解 |
|------|------|
| skill 目錄變大（每個 skill 多 5–13 KB）| 仍在 skill 目錄合理範圍內（每個 skill < 50 KB）|
| probes/ 從 .ts 範例從 monorepo 移到 skill 後，dev-checker-loop v2.2「Module 感知」可能誤判 Module 邊界 | probes/ 是範例、不是真實 Module 程式碼，不會被 Module 邏輯掃到 |

---

## 5. Reviewer 必審 4 點

1. **合規性**：5 skill 交叉引用段改為「見本 skill 的 `examples/...`」是否符合 v2.2 例外「skill 子檔可用 markdown」？
2. **結構性**：150 行上限是否守住？（main SKILL.md 不變長，只加子目錄）
3. **探針擴展**：新增的「skill 子檔例外白名單」是否會被濫用？
4. **dav-submitter 主檔瘦身卡點**：合併條目方案是否破壞變動歷史的可追溯性？

---

## 6. 必產出物

1. 5 個 `examples/` 子目錄（含 5 份原檔）
2. 5 個 SKILL.md 交叉引用段更新
3. 5 個 CHANGELOG.md 新增條目（dav-submitter 用合併方案）
4. 1 個共用探針擴展（白名單）
5. 1 個交付檔 `docs/deliverable/2026-09-26-skill-self-contained.md`

---

## 7. 驗收條件

- [ ] 5 個 skill 主檔 < 150 行
- [ ] 5 個 skill 各含 `examples/` 子目錄 + 對應原檔
- [ ] 5 個 skill 交叉引用段改為「見本 skill 的 `examples/...`」
- [ ] 5 個 skill CHANGELOG.md 新增對應條目
- [ ] 探針擴展支援 skill 子檔例外白名單
- [ ] 探針 3 次跑（前/中/後）全綠
- [ ] 5 項自驗收全綠
- [ ] Reviewer 二審批准
- [ ] 用戶簽核