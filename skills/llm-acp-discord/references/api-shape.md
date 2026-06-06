# LLM-ACP Backend API 真實 Shape

> 來源：`~/www/llm-acp/backend/src/index.ts` (2026-06-04)
> Backend stack：Bun 1.2 + Elysia + Prisma 5.22.0 + SQLite
> Base URL（dev / Docker 本機）：`http://localhost:8080/api`（經 nginx proxy）
> Env var override：`LLM_ACP_API`

## ⚠️ 重要 Quirk — `seq` 已經帶 `#`

backend return 嘅 `seq` 字段**已經帶 `#` prefix**：
```json
{ "id": 1, "seq": "#1", "type": "single", ... }
{ "id": 14, "seq": "#14", ... }
```

**錯誤** render：`題 ##14`
**正確** render：`題 #14`

永遠用 `seq` 字段直接輸出，唔好自己加 `#`。

---

## 1. `GET /api/health`

Response：
```json
{ "ok": true, "questions": 256 }
```

用嚟 detect backend 通唔通（skill 開頭必 call）。

---

## 2. `GET /api/questions?mode=<m>&count=<n>`

Query params：
- `mode`: `random` | `mock` | `sequential` (default `sequential`)
  - `random` / `mock` 都係 `pool.sort(() => Math.random() - 0.5)`，行為一樣
  - `sequential` 係 `[...allQuestions]` 原本 order
- `count`: int, default 20

> ⚠️ **冇 `seq` query param**。要抽特定 `seq` 嘅題（例如 #42），client 要 call `mode=sequential&count=256` 拎成個 pool，再 filter `q.seq === "#42"`。

**Response**（stripped of `answer` field）：
```json
[
  {
    "id": 1,
    "seq": "#1",
    "type": "single",            // "single" | "multiple"  (留意: 唔係 "multi")
    "question": "開發醫療問答系統...",
    "options": [
      { "key": "A", "text": "..." },
      { "key": "B", "text": "..." },
      { "key": "C", "text": "..." },
      { "key": "D", "text": "..." }
    ]
  }
]
```

**留意**：
- `id` ≠ `seq` 嘅數字。Excel 跳過 3 題（#30, #156, #182）後，`id=200` 可能對應 `seq=#203`
- `options` 係 array of `{key, text}`，唔係 array of string
- `count > allQuestions.length` 會自動 cap

---

## 3. `POST /api/attempts`

Body：
```json
{ "questionIds": [1, 2, 3], "mode": "random" }
```

Response：
```json
{ "attemptId": "cmpyg2nmx0003atcr08l1y176", "totalCount": 3 }
```

---

## 4. `POST /api/attempts/:id/answer`

Body：
```json
{ "questionId": "1", "userAnswer": "A" }     // 單選
{ "questionId": "1", "userAnswer": "ABC" }   // 多選，唔使逗號
```

> ⚠️ `questionId` 雖然睇落似要 int，schema `t.String()` 接受 string。用 `String(q.id)` 保險，唔好用 `q.seq`（off-by-3 問題，id 係整數 row id）。

Response：
```json
{
  "isCorrect": true,
  "correctAnswer": "ABC",
  "userAnswer": "ABC"          // 已經 sort 過
}
```

---

## 5. `POST /api/attempts/:id/finish`

無 body。

Response：
```json
{
  "attemptId": "cmpyg2nmx0003atcr08l1y176",
  "totalCount": 3,
  "correctCount": 2
}
```

> **🎯 永遠以呢個 endpoint 嘅 `correctCount` 做最終 score**。
> Skill 唔好喺 submit answer 階段自己 counter — drift 風險高。
> 2026-06-04 親身撞過：cycle 顯示自己 counter 寫 2/3 但 finish 返回 1/5。

---

## 6. `GET /api/wrong-questions`

Response（無 `correctAnswer` field，係 stripped version）：
```json
[
  {
    "id": 2,
    "seq": "#2",
    "type": "single",
    "question": "...",
    "options": [{ "key": "A", "text": "..." }, ...]
  }
]
```

**限制**：
- 用 `distinct: ["questionId"]` —— 即使答啱咗**都唔會** mark resolved
- 解決要手動清 DB：`docker compose down -v` 鏟 volume
- 或者將來改 backend schema 加 `resolvedAt` 字段

---

## 7. `GET /api/stats`

Response：
```json
{
  "totalAttempts": 10,
  "totalAnswers": 29,
  "accuracy": "51.7",           // string, percent
  "wrongQuestionCount": 14,
  "recentAttempts": [
    { "id": "...", "mode": "random", "total": 5, "correct": 1,
      "startedAt": "...", "finishedAt": "..." }
  ],
  "wrongQuestions": [ /* 同 wrong-questions 格式 */ ]
}
```

---

## 8. E2E Test（2026-06-04 驗證過）

| 場景 | 結果 |
|------|------|
| `health` | `{"ok":true,"questions":256}` ✅ |
| `random 1` | 返條 stripped 題 ✅ |
| `random 3` + submit 3 answers + finish | `correctCount: 0/3` 啱 ✅ |
| `random 5` | 5 條 random, types: 5×single ✅ |
| `wrong` | 返 9 條錯題 ID 列表 ✅ |
| `stats` | `totalAnswers: 5 → 17 → 29` 同步累加 ✅ |
| Backend multi-q sequence | attemptId 維繫到 finish，DB 寫入正確 ✅ |
| `questions.json` type enum | `{'single', 'multiple'}`（**唔係** `multi`） ✅ |
| `seq=#N` 直接 query | ❌ backend 冇 `seq` 參數，要 client-side filter ✅ |

> **Test script**：`/tmp/acp_helper.py`（唔屬於 repo，係 skill 嘅 companion test）
