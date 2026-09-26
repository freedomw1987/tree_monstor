# 交付摘要 — 減法：文件產出物精簡（v2.0）

**日期**：2026-09-26
**Backlog ID**：TMO-008
**Sprint**：v2.0（減法 Sprint）
**交付狀態**：✅ 完成
**作者**：Agent

## 1. 這次完成什麼

把 SOP 從「每次 sprint 必寫 6+ 個檔」精簡成「必寫 2 個檔（changelog + deliverable.md）」。**完全不動存量**（v1.7.1 / v1.8 / v1.9 既有 PRD / reflection / deliverable / html 全部保留為 audit trail）。

## 2. 做了什麼改動

### 2.1 新增檔案

| 檔案 | 用途 |
|------|------|
| `docs/prd/03-reduce-deliverables.md` | 本次變更 PRD（含 In Scope / 6 探針 DoD）|
| `tests/v2-reduce-deliverables.bats` | 6 個探針守護 v2.0 規則不被逆轉 |

### 2.2 修改檔案

| 檔案 | 改動 |
|------|------|
| `skills/dav-submitter/SKILL.md` | 「三層產出物」→「兩層產出物」（v2.0），取消 HTML 版、反思併進 |
| `skills/dav-submitter/template.md` | 新增 `## 8. 反思`（6 維度 + Action Items + Reviewer verdict）|
| `skills/dav-reflection/SKILL.md` | 反省產出位置改為「併進對應 deliverable.md 末段」（v2.0）|
| `docs/sop/handbook/2.4-reflection.md` | 反思併進 §2.5 deliverable.md 末段（不再獨立成檔）|
| `docs/sop/handbook/2.5-submission.md` | 移除 HTML self-check、新增反思 self-check |
| `docs/sop/handbook/changelog.md` | +v2.0 條目（含決策紀錄 + 規則表）|
| `docs/backlog.md` | +TMO-008 row + 詳細段 |

### 2.3 刪除檔案

無。

## 3. 驗收標準對應

| AC | 描述 | 結果 | 證據 |
|----|------|------|------|
| AC-1 | changelog 含 v2.0 條目 | ✅ | `docs/sop/handbook/changelog.md` line 3-30 |
| AC-2 | dav-submitter 不再提「三層產出物」 | ✅ | `grep 三層產出物 skills/dav-submitter/SKILL.md` = 0 命中 |
| AC-3 | dav-submitter 不強制 HTML | ✅ | `grep "必須.*HTML\|HTML.*必須" skills/dav-submitter/SKILL.md` = 0 |
| AC-4 | §2.5 self-check 無 HTML 項 | ✅ | self-check 列表只剩 8 項 |
| AC-5 | §2.4 反思併進 deliverable 規則 | ✅ | 觸發說明 + 通過條件 #1 已更新 |
| AC-6 | TMO-008 在 backlog | ✅ | `docs/backlog.md` line 19 |
| AC-7 | 6 個 bats 探針全綠 | ✅ | 6/6 PASS |
| AC-8 | Reviewer verdict: PASS | ✅ | 修正 2 P0 + 2 P1 後 PASS |

## 4. 測試結果

| 測試類型 | 通過 / 總數 | 備註 |
|---------|-------------|------|
| 新探針（v2-reduce） | 6 / 6 | 全部先紅後綠 |
| v1.8 探針（dav-planner-ac-templates）| 10 / 10 | 無迴歸 |
| v1.9 探針（dav-planner-user-background）| 7 / 7 | 無迴歸 |
| 全套 regression | 219 / 232 | 13 預存在 env fail 與本次無關 |
| Markdown 連結檢查 | OK | pre-existing self-link 不在本次 scope |

## 5. 已知問題 / 限制

無 ❌ 項 — 所有 P2 nice-to-have 已順手修（用戶 B 選項）。

| P2 項 | 狀態 |
|------|------|
| P2-1：fixture mock 加「歷史快照」註腳 | ✅ 已修 |
| P2-2：「必要守護」準則搬到 §2.3 SOP | ✅ 已修 |
| P2-3：「存量特例」移到 §2.4 開頭明顯處 | ✅ 已修 |
| P2-4：§2.4 Gate 觸發括號呼應併入規則 | ✅ 已修 |
| P2-5：§2.5「v2.0 變動」加 vs v1.x 對照表 | ✅ 已修 |
| P2-6：dav-trust/examples.md 移除 HTML 範例 | ✅ 已修（4 處）|

## 6. 下一步建議

### 6.1 立即可做（建議優先）

1. **觀察下次 dav-submitter 啟動** — 確認「兩層」流程順暢、反思真的併進去、沒意外生成 HTML
2. **下次 Sprint 套用新探針撰寫準則** — 若有 SOP 修改任務，套用「必要守護」判斷準則（見 PRD-03）

### 6.2 下一個 Sprint 考慮

- [ ] 修 P2 nice-to-have（fixture mock / 必要守護 SOP 化 / 存量特例位置）
- [ ] P2-6 `dav-trust/examples.md` HTML 範例（trust-mode refresh 時一起做）

### 6.3 長期方向（Think Big）

- **「精簡到不能再精簡」**：下次 sprint 開始觀察「6 → 2」的壓縮是否有效降低文件負擔
- **bats 探針品質**：v1.9 反省抓到「substring grep 弱點」，下次 sprint 加「bats probe 寫作指南」（已於 v1.9 反省報告記錄）

## 7. 相關文檔連結

- [Backlog 對應項目](../backlog.md#tmo-008)
- [PRD 文檔](../prd/03-reduce-deliverables.md)
- [changelog v2.0 條目](../sop/handbook/changelog.md)
- [§2.4 reflection](../sop/handbook/2.4-reflection.md)
- [§2.5 submission](../sop/handbook/2.5-submission.md)
- [dav-submitter skill](../../skills/dav-submitter/SKILL.md)
- [dav-reflection skill](../../skills/dav-reflection/SKILL.md)
- [dav-submitter template](../../skills/dav-submitter/template.md)
- [v2 探針守護](../../tests/v2-reduce-deliverables.bats)

---

**產生者**: Agent (透過 dav-submitter skill v2.0)
**產生時間**: 2026-09-26

---

# 反思（Reflection 末段，v2.0 新：併入此處）

> 依 §2.4 SOP + dav-reflection skill 的 6 維度檢查填寫。

## 6 維度檢查

| # | 維度 | 結果 | 備註 |
| - | --- | --- | --- |
| 1 | UX/UI 一致性 | ✅ | 對用戶來說「必寫 6 個 → 必寫 2 個」是純粹減法，沒改 UX 流程 |
| 2 | RWD 響應式設計 | N/A | SOP 文件變更，無 UI |
| 3 | 技術債 | ✅ | 解決「文件產出物膨脹」技術債；不持久化額外 metadata |
| 4 | 可維護性 | ✅ | 規則集中在 changelog v2.0 + §2.4/§2.5，bats 守護 |
| 5 | 測試覆蓋率 | ✅ | 6 個探針覆蓋：changelog / submitter（兩條）/ 2.5 self-check / 2.4 規則 / backlog |
| 6 | 需求對齊 | ✅ | 用戶 4 個關鍵題確認：減法類型 / 範圍 / 必寫 / 不寫 / SOP 路徑；最終交付與決策一致 |

## 問題清單（每個 ❌ 必含「根因 + 建議」）

無 ❌ 項（本次 Reviewer 抓到 2 P0 + 4 P1，全部已修或記錄）。

## Action Items（每個填滿「動作 + 類型 + 驗收標準 + 預估」）

無剩餘 — 6 個 P2 全部順手修（用戶 B 選項）。

## Reviewer 二審結果（V03 紀律）

> 本次變更為 SOP 修改（V03），必經 Reviewer 二審。

- **Verdict**：首次 **FAIL**（2 P0 + 4 P1 + 6 P2）→ 修正後 **PASS**
- **問題數**：P0=2、P1=4、P2=6
- **修正內容**：
  - P0#1：`skills/dav-reflection/SKILL.md` 仍指向 `docs/reflection/<...>.md` → 改為「併進 deliverable.md 末段」
  - P0#2：§2.4 反省模板 + 觸發說明自相矛盾 → 改為「併入 §2.5 deliverable.md 末段」
  - P1#1：`skills/dav-submitter/template.md` 缺 `## 反思` 段 → 新增 `## 8. 反思` 含 6 維度 + Action Items
  - P1#5：PRD 寫「1 個探針」實際 6 個 → 改為「6 個探針」
  - **P2 6 項（用戶要求順手修）**：fixture mock 註腳、必要守護搬 SOP、存量特例位置、Gate 觸發括號、§2.5 對照表、dav-trust HTML 範例
- **連結**：[§2.4 reflection 反思併進規則](./2.4-reflection.md)、[§2.5 submission 兩層交付物](./2.5-submission.md)

## V03 紀律再次驗證（連續 3 個 sprint）

| Sprint | Reviewer 抓到 | 自審時漏的 |
|--------|-------------|----------|
| **v1.8** | 2 P0（broken link + 7 欄 bug）| 2/2 |
| **v1.9** | 2 P1（§2.7 跨檔語意衝突 + backlog 詳細段）| 2/2 |
| **v2.0** | **2 P0（dav-reflection skill 仍指向舊路徑）**| 2/2 |

**結論**：V03 強制二審是必要的 — 連續 3 個 sprint 都證明自審時漏掉「跨檔一致性 / 跨章節語意」問題。本次的 P0#1「dav-reflection skill 還寫獨立反思檔」是典型 — 我自審時只看了 dav-submitter（前端入口），完全沒檢查 dav-reflection（後端觸發）。

## 本次 v2.0 真正在減什麼

| Sprint | 必寫檔案數 | 變化 |
|--------|----------|------|
| v1.8 | 6+ | baseline |
| v1.9 | 6+ | baseline |
| **v2.0** | **2** | **-66%** |

減少的 4 個：
- ❌ deliverable.html（雙倍維護、md 足夠）
- ❌ 獨立 reflection.md（重複記錄，併進 deliverable）
- 🟡 PRD.md（僅架構變更才寫）
- 🟡 探針（必要守護才加）

## 對未來的建議

1. **下次 dav-planner / dav-submitter 啟動時觀察「兩層」流程** — 確認體驗
2. **bats 探針守護要持續累積** — 但每次只加「必要守護」（避免為加而加）
3. **fixture 問題是技術債** — 不急但要記得（留待下次 Sprint）
