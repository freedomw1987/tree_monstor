---
name: test-coverage-table
description: Capabilities-table template for spec → implementation → test coverage enforcement. Use at the start of any implementation task to derive a coverage matrix that the spec reviewer can audit.
version: 1.0.0
platforms: [linux, macos, windows]
---

# Test Coverage Table — 強制 Capabilities → Implementation → Test Matrix

## 目的

LLM 寫 test 嘅傾向（per David 痛點二）：
1. **Happens-to-know bias** — agent 知道自己寫咗咩，自然 test 嗰啲
2. **Spec 唔夠 explicit** — User 講「上傳頻道」但 spec 冇列 capability，agent 當作 trivial 漏咗
3. **冇 systematic derivation** — 冇 mechanism 強 agent 由 spec 抽 capability 再對返 test

呢個 skill **強制** agent 由 spec derive 一個 capabilities table，spec reviewer 對返 implementation + test 有冇 cover。

---

## 結構（必須填）

| # | Capability | User Intent | UI Element / API | Test Case | Implementation File | Status |
|---|---|---|---|---|---|---|
| 1 | (動作) | (用戶想做咩) | (UI/API path) | (test 點叫) | (file path) | ☐ |

**Example — 訃文本編輯 + 上傳頻道**：
| # | Capability | User Intent | UI Element / API | Test Case | Implementation File | Status |
|---|---|---|---|---|---|---|
| 1 | 開 editor | 用戶打開訃文編輯頁 | `/editor` route | `test_open_editor` | `pages/editor.tsx` | ☐ |
| 2 | 輸入文字 | 用戶輸入訃文內容 | `<textarea name=body>` | `test_type_text` | `pages/editor.tsx` | ☐ |
| 3 | 上傳附件 | 用戶上傳圖片 / 文件 | `<input type=file>` | `test_upload_file` | `components/Upload.tsx` | ☐ |
| 4 | 儲存草稿 | 用戶 save 草稿 | `Save` button | `test_save_draft` | `api/drafts.ts` | ☐ |
| 5 | 預覽 | 用戶睇預覽 | `Preview` button | `test_preview` | `pages/preview.tsx` | ☐ |
| 6 | 發佈 | 用戶 publish | `Publish` button | `test_publish` | `api/publish.ts` | ☐ |

---

## 派生規則

### For UI features
列 **user journey steps**（用戶點 click / 點 type / 點 upload）：
1. 開 page
2. 見到 element
3. 觸發 action
4. 見到 result
5. (optional) 重新 state

### For API / library
列 **public methods × 行為**：
- `users.create()` — 成功 / 失敗 / edge case
- `users.find_by_email()` — exists / not found / multiple

### For CLI
列 **subcommands × flags**：
- `myapp build` — success / config error / build fail
- `myapp deploy` — dry-run / actual / rollback

---

## Spec Reviewer Checklist（MANDATORY）

Spec reviewer 收到 implementation 之後，**必須** verify 下列全部：

- [ ] Plan 入面有 capabilities table（喺 `## Capabilities Table` section）
- [ ] Table 至少 1 row
- [ ] **Reverse-engineer spec**：抽 spec 入面**所有 noun + verb**，對返 table — 有冇 capability 漏咗？
  - 例：spec 寫「JWT」table 冇「JWT generation」→ 漏咗
  - 例：spec 寫「file upload」table 冇「validate file type」→ 可能漏
- [ ] Implementation 對應每個 capability（file/function exist per row）
- [ ] Test 對應每個 capability（test case exist per row）
- [ ] 任何 capability 缺 implementation / test → **報告 specific row number + 缺咩**（唔係淨講 "spec gap"）

**OUTPUT FORMAT**（reviewer 必須跟）：
```
PASS  OR
FAIL:
- Row #3 (Upload file): 缺 implementation file `components/Upload.tsx`
- Row #5 (Preview): 缺 test case `test_preview`
- Spec noun "JWT" 冇對應 capability row — 建議加 row #7: JWT token generation
```

---

## Quality Reviewer 額外 Check

- [ ] Test assertion 唔係只 smoke test（要 verify output value，唔係 assertTrue(bool)）
- [ ] 邊界 case 有 cover（empty input, large input, error path, concurrent）
- [ ] Integration test（唔係淨 unit test）— UI feature 至少 1 個 e2e test
- [ ] Test names 描述行為（`test_upload_file_rejects_oversized` 好過 `test_upload_2`）

---

## Usage in Subagent-Driven Development

呢個 skill 配合 `subagent-driven-development` 使用：

1. **Plan 階段**（main agent / orchestrator）：
   - 寫 plan 嘅時候，**必須** embed capabilities table
   - 冇 table 嘅 plan 唔可以 dispatch 落 sub-agent

2. **Plan Validation 階段**（gating）：
   - Sub-agent check plan 有冇 capabilities table
   - 冇 table → 報告 "Plan needs capabilities table before implementation"
   - 有 table → 繼續

3. **Implementer 階段**：
   - Sub-agent 跟 table 逐個 capability 寫 code + test
   - 完成後 mark `Status = ✅`

4. **Spec Reviewer 階段**：
   - 用上面 checklist audit
   - Reverse-engineer spec noun/verb
   - 報告 PASS / FAIL（specific row + 缺咩）

5. **Quality Reviewer 階段**：
   - 額外 check test assertion 強度
   - 報告 APPROVED / REQUEST_CHANGES

---

## 永遠唔做

- 唔寫 capabilities table 直接 implement
- Table 冇 reverse-engineer spec noun/verb
- Spec reviewer 寫 "looks good" / "minor gaps" 唔講 specific row
- 任何 capability 行漏咗 spec 但 pass 咗 review
