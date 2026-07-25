# LLM-ACP Backend API Quirks

E2E 試過嘅真實行為。當 backend 行為變咗就 update 呢個 file。

## 1. `seq` 帶 `#` prefix

Backend response:
```json
{"id": 1, "seq": "#1", "type": "single", ...}
```

**唔好** render 為 `題 #1 (single)` 用 `f"題 #{q.seq}"` — 會變 `題 ##1`。
**要** 直接用 `q.seq`：`f"題 {q.seq} ({q.type})"` → `題 #1 (single)` ✅

## 2. `id` 同 `seq` 唔同步 (off-by-N)

Excel 跳過咗 3 條題（#30, #156, #182），所以 seed 入 DB 嗰陣 `id` 唔同 `seq` 嘅 row 對唔上。

實測：
- seq=#203 → id=200 (差 3)
- seq=#53  → id=52  (差 1, 因為 #30 已跳)
- seq=#143 → id=142 (差 1)

**Submit answer 一定要用 `q.id` (number)，唔好用 `q.seq` 做 `questionId`**：
```python
submit_answer(attempt_id, q["id"], user_answer)  # ✅
submit_answer(attempt_id, q["seq"], user_answer)  # ❌ backend 會搵唔到
```

## 3. Wrong-questions 唔會 mark resolved

`GET /api/wrong-questions` SQL:
```ts
prisma.answer.findMany({
  where: { isCorrect: false },
  distinct: ["questionId"],
})
```

`distinct` 只係去重複，**唔會**將答啱嘅題從錯題本刪走。E2E 答啱咗一條之後再 call，仍見到 9 條（之前 8 條 + 嗰條）。

**要清**：
- 開一個 admin endpoint 清表（未做）
- 或者 `docker compose down -v` 鏟 DB（連 web app 記錄都冇）

Skill 渲染嗰陣可以提一句「呢條答啱咗但仍喺錯題本」做 UX 補償。

## 4. Stats 反映即時

`GET /api/stats` 每次 call 都重新 query Prisma，無 caching。Skill 直接 call 唔使擔心 stale data。

## 5. Question type enum

`type` field 係 `"single"` 或 `"multiple"`（**唔係** `multi`，細階英文）。Discord render：
- `single` → 「(單選)」
- `multiple` → 「(多選，可揀多個)」

唔好假設係中文，亦唔好用 `"multi"` 做條件判斷 — 條件寫 `q.type === "multiple"`。

> 2026-06-04 驗證：`python3 -c "import json; print({q['type'] for q in json.load(open('questions.json'))})"` 返 `{'single', 'multiple'}`。

## 6. 答案 userAnswer 格式

Backend 接受：
- `"A"` 單選
- `"AB"`、`"ABCD"` 多選（會自動 sort）

Backend 唔接受：
- `"1,2,3"` 數字格式
- `" A "` 有空白（要 normalize）
- `["A","B"]` JSON array

**Skill normalize**：strip 空白 + uppercase + 字母 only。

## 7. 3 條 Excel 跳過題

Excel 有 3 條題答案格式異常，seed 階段已經 filter 走，random pool 永遠唔會見到：
- Excel #30
- Excel #156
- Excel #182

唔好因為 random 抽到嘅 seq 唔連續就以為 bug。

## 8. `/api/questions` 冇 `seq` query param

Backend 抽題 endpoint：
```ts
.get("/api/questions", ({ query }) => {
  const mode = (query.mode as string) || "sequential"
  const count = Number(query.count) || 20
  // ...冇 query.seq 處理
})
```

**影響**：「抽第 N 條」呢個 command 唔可以靠 query string 做到。

**解法**：client-side filter——
```ts
const pool = await fetch(`${API}/api/questions?mode=sequential&count=256`).then(r => r.json())
const target = pool.find(q => q.seq === "#42")
```

或者直接 read `questions.json`（但要同 backend 同步，假設 backend 已經 load 過）。
