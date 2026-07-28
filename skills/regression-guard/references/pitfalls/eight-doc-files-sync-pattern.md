# ⚠️ Pitfall — 8 份 doc file 嘅 doc sync pattern (紅線 10/11/13/14)

**場景**:每次 ship 一個有架構性嘅 feature(新 schema、新 package、新 route family),紅線 10 要求 8 份 doc 必須 commit:

| File | 必填時機 | Owner |
|------|---------|-------|
| `docs/PROJECT-OVERVIEW.md` | Plan 結束(隨首個 code commit) | 你 |
| `docs/PRD.md` | 改 US 嘅同時必更新 | 你 |
| `docs/DESIGN.md` | 設計定稿時 | 你 |
| `docs/architecture/NNNN-*.md` | 每個重大架構決策即時 | 你 |
| `docs/API.md`(如有 API) | 每個 endpoint 上線前 | 你 |
| `docs/TEST-COVERAGE.md` | 每個 sprint 結束時 | 你 |
| `docs/QA-TRACKER.md` | 改 PRD 嘅同時必更新 | 你 |
| `docs/REGRESSION-GUARD.md` | 每個 bug fix | 你 |

**Anti-pattern**(2026-06-07 crm-system 親驗):5 個 task 嘅 code + backend smoke 全部 ship,**但 8 份 doc 一份都冇** — 「**冇文件嘅 code 唔可以 merge**」嘅紅線 10 直接踩。David 嘅 spec:「更新了docs 未」一問先知。

**正確 audit-driven fix flow**:
```
recon 結論(懷疑 T2/T3 缺 infrastructure)
    ↓
完整 audit(DB schema / routes / frontend / RBAC 全部)
    ↓
確認 3 個 audit bug(RG-002 env-var drift / RG-003 503 translation / RG-004 缺 permission)
    ↓
每個 bug 修 + 寫 RG-XXX entry(invariant 必須語句化,例如 "MUST NEVER read OPENAI_API_KEY env var")
    ↓
8 份 doc 同步寫 — 一個 commit series 3 個 atomic commit:
  1. backend / 2. frontend / 3. docs
    ↓
DB smoke + curl smoke + commit message 引用 RG ID + push
```

**Doc scope 速查**(每份 file 寫咩):

| Doc | 必含 sections |
|-----|---------------|
| PROJECT-OVERVIEW | one-line summary / tech stack / repo layout / day-by-day history / Day-N feature 一段講晒 |
| PRD | Epic + US + status legend + backlog + change log |
| DESIGN | 視覺語言 tokens / layout / component lib / page patterns / Day-N UI specifics / RWD |
| API | Conventions(URL/auth/err shape)/ 全 endpoint per resource / Day-N 新 endpoint 完整 |
| TEST-COVERAGE | Test layers 定義 / US→test matrix / manual smoke checklist |
| QA-TRACKER | US status table / Day-N batch audit table / smoke test results / open follow-ups |
| architecture/NNNN- | Status / Context(其他 option)/ Decision / Rationale / Consequences / Alternatives |
| REGRESSION-GUARD | RG-XXX entry template(發現日 / root cause 技術+process / invariant / prevention)+ 索引表 |

**Lesson**:**ship 完整 feature 嘅 closing loop 永遠係「code + smoke + doc + RG entry + push」5 步**。漏 doc = 紅線 10 違規 = 用戶問「更新了docs 未」= 你要返嚟重做。
