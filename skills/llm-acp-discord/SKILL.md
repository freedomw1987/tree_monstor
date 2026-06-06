---
name: llm-acp-discord
description: 在 Discord 對話中練習 LLM-ACP 模擬考試。David 打 `acp` 抽題、覆 A/B/C/D 即時批改 + 入 DB。
---

# LLM-ACP Discord Skill 🦞

讓 David 喺 Discord 直接抽題溫書 — 零摩擦，唔使開 browser，所有答題記錄會寫入 web app 嘅同一個 SQLite DB。

## 觸發條件

**任何 David 訊息以 `acp` 開頭**（case-insensitive，前面可以有空白/標點）。

```
acp                  → 抽 1 條 random 題
acp 5                → 抽 5 條 random 題
acp 20               → 抽 20 條 random 題
acp wrong            → 抽錯題本 1 條
acp wrong 5          → 抽錯題本 5 條
acp seq 42           → 抽第 42 題（按 Excel 序號）
acp stats            → 顯示當前 stats
acp help             → 顯示指令表
```

**當抽咗題之後**，David 直接覆答案就自動批改：
```
A / B / C / D        → 答單選
AB / CD / ABCD       → 答多選（唔使加逗號）
s / skip             → 跳過
reveal               → 直接睇答案（當練習模式）
```

> **2026-06-04 驗證**：David 真實用過 `acp 3`、`acp 5`、`acp help`，全部 trigger 正確。`acp wrong` 抽到錯題 9 條中嘅一條（backend 用 `distinct: [questionId]` 唔會 mark resolved，係 backend 既有行為，唔係 skill 嘅問題）。

> 💡 **多選題一定要喺 footer 提示**：`多選直接 ABCD (唔使逗號)`。
> David 第一次見多選可能會打 `A, B, C` 或 `1,2,3` → backend 會 reject。
>
> 💡 **`q.type` 係 `"single"` 或 `"multiple"`**（細階英文，**唔係** `multi`）。Render 時將 `multiple` 翻譯做「(多選，可揀多個)」。

## Backend API

Skill 用以下 endpoints（**經 nginx `http://localhost:8080/api`**）：

| Method | Path | 用 |
|--------|------|-----|
| GET | `/api/health` | 確認 backend 喺唔喺度 |
| GET | `/api/questions?mode=random&count=1` | 抽 N 題 random（唔包答案） |
| GET | `/api/questions?mode=mock&count=1` | 抽 N 題 random（mock 模式，後端用同一 random 邏輯） |
| GET | `/api/wrong-questions` | 拎錯題本（whole list，自己 random） |
| POST | `/api/attempts` body `{questionIds, mode}` | 開新 attempt |
| POST | `/api/attempts/:id/answer` body `{questionId, userAnswer}` | 提交答案，return `{isCorrect, correctAnswer}` |
| POST | `/api/attempts/:id/finish` | 結束 attempt |
| GET | `/api/stats` | 睇 stats |

> ⚠️ **Backend `/api/questions` 冇 `seq` 參數**。要抽特定 `seq` 嘅題（例如 `acp seq 42`），skill 要 call `mode=sequential&count=256` 拎成個 pool，再 client-side filter `q.seq === "#42"`。

API base URL 透過 env var **`LLM_ACP_API`** 設定，default `http://localhost:8080/api`。Docker 跑緊時 default 就 work，將來 deploy ECS 改呢個 env 就得。

## Workflow

**單題 cycle** (`acp`)：
1. `curl GET /api/questions?mode=random&count=1` → 攞題
2. Render Discord message：題目 + 4 個選項 + 「覆 A/B/C/D」
3. **Hold 狀態**（喺自己 turn 嘅 todo / context 入面記住「當前題 id + seq + 類型 + 選項」）
4. David 覆 A/B/C/D → normalise（uppercase，去空白）→ `POST /api/attempts` (開 attempt) → `POST /api/attempts/:id/answer` body `{questionId: String(q.id), userAnswer}` → 攞 `isCorrect` + `correctAnswer`
5. Render 回饋：✅ / ❌ + 對番正確答案 + 下一題 prompt

**多題 cycle** (`acp 5`)：
1. 開 attempt with 5 條 IDs
2. 一條一條顯示（避免一次過轟炸 2000 char 限制）
3. 答完最後一條 → `POST /finish` → render 總分

## Discord 渲染規則

- Discord 限制 2000 char/msg — 題目長嘅時候用 `embed` 唔得（Hermes 呢個 channel 唔支援），所以**單純長文字 + 適度省略**
- 多選題明示「(多選，可揀多個)」
- 答案判定顯示用 emoji：
  - ✅ 啱 → 「🎉 啱晒」
  - ❌ 錯 → 「❌ 錯」+「正確: B」
- 跳過：顯示答案但唔計分
- 每次顯示加 `🦞 LLM-ACP 練習` header + 進度「(3/20)」

## 答題狀態管理

**重要**：Hermes subagent / skill 唔可以靠 global state，要用以下方法 hold 當前題：

1. **每次 David 答完**就當成"已消耗"嘅題，唔使留 state
2. **新一題** = 開新嘅 `GET /questions` 拎 random（自然唔會重複短期內嘅）
3. **同一條訊息入面抽 N 條** → 順序問，每答完一題就 render 下一題
4. 唔使記 attempt ID 因為每次都新建（單一 attempt 只 for 該 cycle）

**如果 David 中途冇覆**就當 timeout / 跳過，下次 `acp` 開新嘅。

## Pitfalls

> **以下係 live session 撞過嘅、會直接搞死互動嘅 trap**。Render 之前要過呢個 checklist。

### A. Render traps (highest priority — 影響用戶體驗)

1. **題目唔好自己加 `#`** — backend `q.seq` 已經帶 `#` prefix (e.g. `"#14"`)。
   - ❌ `f"**題 #{q.seq}**"` → `**題 ##14**` (double hash, 醜)
   - ✅ `f"**題 {q.seq}**"` → `**題 #14**`
2. **多選題要 explicit 教 David** — 後端接受 `"AB"` / `"ABCD"` 字母 string，**唔使逗號**。
   - David 第一次見多選可能會打 `A, B, C` 或 `1,2,3` → backend 會 reject
   - 觸發 `q.type === "multiple"` 嘅題目，render footer 要寫：`多選直接 ABCD (唔使逗號)`
   - ⚠️ 唔好用 `"multi"` — backend 真正返 `q.type === "multiple"`（2026-06-04 `questions.json` 驗證過：`Types: {'single', 'multiple'}`）
3. **每題批改後加 1 句解題思路** (David 鍾意) — 用 `💡` emoji 講點解啱/錯。
   - 例如：`💡 B 加角色 prefix 喺 retrieval 唔會顯著提升召回`
   - 唔好長過 1 句，跟住出下一題

### B. Batch mode (`acp N`) progress display

- 每答完一題即時 update `得分: X/Y`（cumulative），唔好等 finish 先出
- 最後一題 finish 後出 summary block（render-examples.md Example 5）
- 提示「想再嚟 / 重做錯嘅 / acp stats」三個 quick action

### C. Backend / infra

1. **`oven/bun` backend 唔通**：先 `curl /api/health` 確認 8080 唔通嘅話提示 David `docker compose up -d` 開返
2. **答案格式 normalize**：strip 空白 + uppercase + 字母 only。Backend 拒絕 `"1,2,3"` / `" A "` / `["A","B"]`
3. **Excel 跳過題**：3 條 (#30, #156, #182) 會被 backend 過濾，唔好因為攞唔到就以為 bug
4. **Discord 字數**：如果題目 + 4 選項 > 1800 char，警告「題目超長」並截斷 4 個 option 中間嗰啲
5. **空 `acp`** = `acp 1`，唔好彈 error
6. **作答後冇反應**：檢查有冇 hold 住上一條題；如果唔肯定就 reset，叫 David 重新 `acp`
7. **`seq` 雙 `#` bug** ⚠️：backend `/api/questions` return 嘅 `seq` 已經帶 `#` prefix（例如 `"#14"`）。Render 時**唔好再額外加 `#`**。正確：`題 #14 (single)`；錯誤：`題 ##14`。確認 source of truth 喺 `references/api-shape.md`。
8. **Backend 係 score source of truth** ⚠️：multi-question cycle 嘅 `correctCount` **必須**等 `POST /attempts/:id/finish` 回嘅 `correctCount`，唔好喺 submit answer 階段自己 counter（會 drift，2026-06-04 親身撞過 — 顯示 2/3 但其實係 1/5）。Render 結果前**永遠以 finish endpoint 為準**。
9. **寫 recap 嘅時候都唔好自己 paraphrase「題 N 我以為 X 但 backend 判 Y」** ⚠️：score 雖然由 backend 話事，但係寫回饋文字嗰陣 model 仍會混淆題號 / 答案對應（例如 2026-06-04 文字寫「#152 backend 判 B 錯」但表格寫「❌ (D)」）。**列 raw data table**（題號 / David 答嘅 / backend 判嘅 / isCorrect）最安全，唔好喺敘述句入面 cross-reference 題號同答案。`correctAnswer` 直接 quote backend 返個 field，唔好 memory。
10. **Wrong-questions 唔自動 mark resolved** — 答啱咗都仍喺錯題本（backend `distinct: [questionId]` 唔 update state），render 嗰陣提一句「💡 答啱咗但 backend 仍列喺錯題本」做 UX 補償

### E2E 揭發嘅 backend quirks (2026-06-04)

呢啲係由真實 backend response 抽出嚟，唔係猜。Render 時一定要跟住：

1. **`seq` 帶 `#` prefix** — backend return `"seq": "#14"`，render 唔好再自己加 `#`，否則變「**題 ##14**」。直接用 `q.seq` 就夠，例：`題 {q.seq} ({q.type})`
2. **`id` 同 `seq` 唔同步** — Excel 跳過 3 條 (#30/#156/#182)，所以 seq=203 嘅題可能 `id=200`。Submit answer 時用 **`questionId` = `String(q.id)`**（backend schema 強制 `t.String()`），唔係 `q.seq`
3. **Wrong-questions 唔自動 mark resolved** — `GET /api/wrong-questions` 用 `distinct: [questionId]`，即使你喺錯題本答啱咗，下次抽返都仲會見到。Skill render「答啱」嘅時候順手提示「呢條喺錯題本，但答啱咗仍然會留喺度，係 backend 已知 quirk」
4. **Stats count 變化** — `GET /api/stats` 即時 reflect 新 attempts/answers，唔使 cache
5. **Question type field** — `"single"` 或 `"multiple"` (英文，**唔係** `multi`)，Discord render 將 `multiple` 翻譯做「(多選，可揀多個)」
6. **3 條 Excel 跳過題 (#30/#156/#182)** — backend seed 時已經過濾，random pool 永遠唔會見到；E2E 揾唔到唔係 bug

## Quick Command Reference

```bash
# 健康
curl -s http://localhost:8080/api/health

# 抽 1 題 random
curl -s "http://localhost:8080/api/questions?mode=random&count=1" | jq '.[0]'

# 抽錯題本
curl -s http://localhost:8080/api/wrong-questions | jq 'length'

# 開 attempt
curl -s -X POST http://localhost:8080/api/attempts \
  -H "Content-Type: application/json" \
  -d '{"questionIds":[1,2,3],"mode":"random"}'

# 答題
curl -s -X POST http://localhost:8080/api/attempts/ATTEMPT_ID/answer \
  -H "Content-Type: application/json" \
  -d '{"questionId":"1","userAnswer":"A"}'  # questionId 用 String(q.id)

# Stats
curl -s http://localhost:8080/api/stats | jq
```

## 部署日後改 env

將來 deploy ECS：
```bash
export LLM_ACP_API=https://your-ecs-domain.com/api
```
Skill 內 default 改 `/api/questions` 全部 prepend `LLM_ACP_API` env 即可。

---

## 📎 References

- `references/api-shape.md` — Backend API 嘅真實 request/response schema（2026-06-04 從 `~/www/llm-acp/backend/src/index.ts` 攞），包括 `seq` 帶 `#` 嘅 quirk
- `references/discord-render.md` — Discord message 渲染範本（單題/多題/錯題/stats/help）

---

## Related Files

- `scripts/acp_helper.py` — Python helper 攞 random / wrong / stats / submit，每個 step 一行 `python3 scripts/acp_helper.py <cmd>` 搞得掂。E2E 試過全 work，用嚟 debug / smoke-test backend 唔使再手打 curl
- `references/api-quirks.md` — backend 真實 response 行為紀錄（`id` vs `seq` offset、`#` prefix、wrong-questions 唔 mark resolved 等）
- `references/render-examples.md` — Discord 訊息 render 範例（E2E 試過嘅成功 output）

---

## 🔧 Maintenance / 點更新呢個 Skill

**呢個 skill 唔係 self-contained**。佢係 `~/www/llm-acp/backend` 嘅 mirror，所有 API 行為必須以 backend 源碼為 ground truth，唔係以本 skill 之前嘅 notes 為準。

**Source of truth 兩個 file**（每次想改本 skill 之前先讀）：
1. `~/www/llm-acp/backend/src/index.ts` — 所有 endpoint 行為（Elysia routes、Prisma query、t.* schema）
2. `~/www/llm-acp/questions.json` — `q.type` 等 enum 值、id/seq 對應、跳過題

**Reconciliation workflow**：
1. Read `index.ts` 你要更新嘅 endpoint（grep `\.get\|\.post`）
2. Diff vs `references/api-shape.md` — 唔啱就 patch 嗰 section
3. Diff vs `references/api-quirks.md` — 如果 backend 有新 quirk，加新 section
4. Diff vs `references/render-examples.md` — 確保 type label / payload 結構對齊
5. 加 E2E row 入 `api-shape.md` §8，標日期（例如 `2026-06-XX`）
6. E2E smoke test：`python3 /tmp/acp_helper.py` 或實 `curl` 一次

**過去撞過嘅 skill 毛病**（避免重犯）：
- ❌ **Skill 自己 file 之間矛盾**：寫 `q.type == "multi"` 但 questions.json 真係 `"multiple"`
- ❌ **誇大 claim**：寫咗 `mode=sequential&seq=X` 但 backend 根本冇 `seq` query param
- ❌ **過時 type hint**：寫 `questionId` 接受 int，但 backend schema 強制 `t.String()`
- ❌ **冇 E2E 驗證就 patch**：render 完先發現 backend 唔接受個 payload

**判斷「skill 啱唔啱」嘅金標準**：可以靠 `references/api-shape.md` + `curl` 對住 backend 真實 response 砌出一個 working 嘅 `acp_helper.py` 嗎？如果有矛盾 = skill 錯。

> **用戶核心原則**（2026-06-04）：「請按後端API 的答案為最終依歸」。
> 將來如果發現 skill 同 backend 唔啱，**永遠 patch skill 嚟追 backend**，唔好 patch backend（除非 user 明確指示改 backend）。
