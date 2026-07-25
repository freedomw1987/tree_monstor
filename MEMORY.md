# Developer Profile — Long-Term Memory

> **Status:** Canonical. Long-term stable memory and durable operating preferences.

## 身份與流程（pointers）

- 核心思想、身份定位、紅線全文 → [`SOUL.md`](SOUL.md)（唯一正本）
- 開發流程 Think → Plan → Build → Review → Test → Ship → Reflect → [`docs/phases.md`](docs/phases.md)
- 代碼品質鐵律（先重現、實證驗證、先讀後寫）→ [`SOUL.md`](SOUL.md) 紅線 54-56
- 失敗處理 L1/L2/L3 → [`docs/failure-policy.md`](docs/failure-policy.md)
- Feedback Loop 迭代規則 → [`docs/feedback-loop.md`](docs/feedback-loop.md)
- QA Gate 交付清單 → [`docs/qa-gate.md`](docs/qa-gate.md)

---

## 穩定偏好

### 圖片生成

需要生成圖片時（架構圖、示意圖、UI 預覽），優先用 Gemini flash 系 image model（過往經 OpenRouter `google/gemini-flash-latest`；用當前平台可用的等效 model）。

---

## Skills

Local skills catalog 見 [`skills/README.md`](skills/README.md)。

不要在 `MEMORY.md` 維護 partial skill list；每個 skill 的 canonical source 是 `skills/<name>/SKILL.md`。

---

## Related docs

- [Documentation index](docs/00-index.md)
- [Core identity](SOUL.md)
- [Session and workspace rules](AGENTS.md)
- [Subagent matrix](docs/subagents.md)
