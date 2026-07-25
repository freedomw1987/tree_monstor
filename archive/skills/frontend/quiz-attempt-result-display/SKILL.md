---
name: quiz-attempt-result-display
description: Teacher quiz/assignment results page — score null display, fileName parsing, CSV export, download button logic. UMAC AI project.
---

# Quiz Attempt Result Display — Teacher View

## Context
UMAC AI project — teacher results page for quiz/assignment submissions. Backend: Elysia.js + Prisma + PostgreSQL. Frontend: React + Vite + Tailwind.

## Problem
Teacher needs to see student quiz/assignment results with:
- `score: null` (non-auto-graded) → show "待批改" not "—"
- Text answers (no file attachment, score=null) → show "（文字回答）"
- No file → button "無作品" (not "下載作品"), alert on click
- CSV export must include fileName column, null score → "待批改"

## Backend API Logic (quiz.ts)
```typescript
// GET /api/quiz/:id/attempts — deduplicates to latest per student
const latestByUser = new Map()
for (const a of attempts) {
  if (!latestByUser.has(a.userId)) latestByUser.set(a.userId, a)
}

// Attach fileName parsed from answers JSON (S3 key pattern)
const result = latestAttempts.map(a => {
  const answers = JSON.parse(a.answers || '{}')
  let fileName: string | null = null
  for (const [key, value] of Object.entries(answers)) {
    if (typeof value === 'string' && value.startsWith('attachments/') && !key.endsWith('_fileName')) {
      fileName = answers[key + '_fileName'] || value.split('/').pop()?.replace(/^\d+-(\d+)-/, '') || null
      break
    }
  }
  return { ...a, fileName }
})
```

## Frontend Display Logic (CourseEditor.tsx)
```tsx
// Score display
{a.score === null ? '待批改' : a.score + '%'}

// Text answer label (no file, waiting for grading)
{!a.fileName && a.score === null && <span>（文字回答）</span>}

// Download button
{a.fileName ? (
  <button onClick={() => handleDownload(a.id)}>下載作品</button>
) : (
  <button onClick={() => { alert('這個提交沒有作品文件'); return; }}>無作品</button>
)}

// CSV
const header = ['姓名', '電郵', '分數', '作品檔案', '提交時間']
const csvRows = attempts.map(a => [
  a.user.name,
  a.user.email,
  a.score === null ? '待批改' : `${a.score}%`,
  a.fileName || '',
  new Date(a.submittedAt).toLocaleString('zh-TW'),
])
```

## Testing Approach
When API login is unavailable (password mismatch from prior session), directly query Prisma to verify display logic:

```bash
cd ~/projects/umac_ai/backend
node -e "
const { PrismaClient } = require('@prisma/client')
const prisma = new PrismaClient()
async function main() {
  const attempts = await prisma.quizAttempt.findMany({
    where: { quizId: 'your-quiz-id' },
    include: { user: { select: { name: true, email: true } } },
    orderBy: { submittedAt: 'desc' }
  })
  // deduplicate + simulate display logic
  const latestByUser = new Map()
  for (const a of attempts) { if (!latestByUser.has(a.userId)) latestByUser.set(a.userId, a) }
  latestByUser.forEach((a) => {
    // parse fileName from answers JSON, apply display logic
    console.log(...)
  })
}
main().finally(() => prisma.\$disconnect())
"
```

## Key Files
- `backend/src/routes/quiz.ts` — teacher attempts route (`:id/attempts`)
- `frontend/src/pages/teacher/CourseEditor.tsx` — attempts query and display
- `backend/prisma/schema.prisma` — `QuizAttempt` model with `answers Json`, `score Int?`
