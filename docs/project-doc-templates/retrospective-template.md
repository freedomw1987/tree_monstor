# Retrospective — Template

> **When to use:** Reflect 階段，每個 feature / incident 完成後。
> **位置:** `docs/retros/YYYY-MM-DD-<short-name>.md`
> **No-code rule:** 不適用。

## 必填區塊

```markdown
# Retrospective — <Feature> — YYYY-MM-DD

## 概述
- 做了什麼
- 涉及哪些 user stories
- 花了多少時間(預估 vs 實際)

## 做得好的
1. ...
2. ...

## 需要改進的
1. ...
2. ...

## 關鍵教訓 (Lessons Learned)
1. ...
2. ...

## 決策回訪（每次 retro 必做一個）
- 抽查對象: [隨機抽一個過去的 ADR / 技術選擇 / Think-Plan 決策]
- 當初的理由: [當時為什麼這樣選]
- 以現在所知: [會不會選不同？為什麼]
- 結論: [維持 / 需要新 ADR 修正 / 記入 TECH-DEBT]

## 下次改進 Action Items
- [ ] AI: ...
- [ ] Owner: ...
- [ ] Due: YYYY-MM-DD

## 對文件的更新
- [ ] TECH-DEBT.md 新增項目
- [ ] 設計 token 需要更新
- [ ] ADR 需要新增
```

## 規則
- 每個 feature 完成後、每次重大 incident 後、每個 sprint 結束時寫
- **決策回訪 rule**：每次 retro 必須隨機抽一個過去的 ADR / 技術選擇審視；結論係「會」時開新 ADR 或記入 TECH-DEBT，唔可以只留喺 retro