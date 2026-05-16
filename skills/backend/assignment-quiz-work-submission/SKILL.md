---
name: assignment-quiz-work-submission
description: Student assignment (作品題) upload + teacher download flow for UMAC AI — S3 presigned URLs, answers JSON storage, filename metadata pattern, nullable score
---

# Assignment / Work Submission Pattern

Student assignment (作品題) submission flow for UMAC AI project.

## Flow

1. **Student uploads file** → `POST /api/upload/presign` → S3 direct upload → `POST /api/quiz/:quizId/submit-assignment`
2. **Teacher views/download** → `GET /api/quiz/attempts/:attemptId/download`

## Backend: submit-assignment

```ts
// frontend sends: { questionId, fileUrl: s3Key, fileName: originalName }
// answers JSON stores both S3 key and original filename
const answers: Record<string, string> = {
  [body.questionId]: body.fileUrl,
  [body.questionId + "_fileName"]: fileName,  // metadata key
};
// create QuizAttempt with score: null (no auto-grading)
```

## Backend: download endpoint

```ts
// Parse answers JSON, skip _fileName metadata keys
for (const [qId, value] of Object.entries(answers)) {
  if (typeof value !== "string" || !value.startsWith("attachments/") || qId.endsWith("_fileName")) continue;
  const fileName = (answers as Record<string,string>)[qId + "_fileName"] 
    || value.split("/").pop()?.replace(/^\d+-(\d+)-/, "")  // fallback: strip S3 timestamp prefix
    || "作品檔案";
  const downloadUrl = await generateDownloadUrl(value);
  assignmentFiles.push({ questionId: qId, fileName, fileUrl: downloadUrl });
}
return { files: assignmentFiles };
```

## S3 Key Format

```
attachments/{timestamp}-{random}-{originalFilename}
```
e.g., `attachments/1778906803551-912794464-0hl186osquhs33ivs0mgpeukkd.png`

The `generateUploadUrl` in `backend/src/services/s3.ts` prepends timestamp-random prefix.

## Frontend: AssignmentSubmit component

```tsx
// Upload mutation sends filename alongside s3Key
await api.post(`/quiz/${quizId}/submit-assignment`, {
  questionId,
  fileUrl: s3Key,
  fileName: file.name,  // must send original filename
})
```

## Frontend: Teacher score display

```tsx
// nullable score → show dash
{a.score ?? '—'}%

// Download button with filename
data.files.forEach((f: { fileName: string; fileUrl: string }) => {
  const a = document.createElement('a')
  a.href = f.fileUrl; a.download = f.fileName; a.click()
})
```

## Prisma: QuizAttempt.score is nullable

```prisma
score Int?  // null = pending manual grading (TEXT/ASSIGNMENT only quiz)
```

## Key Lessons

- **Never rely on S3 key containing original filename** — S3 key has timestamp prefix, original name lost unless stored explicitly
- **Store metadata in answers JSON** with suffix pattern (`questionId_fileName`) — avoids schema changes
- **Download endpoint must return fileName** — filename is needed for `a.download` attribute to give downloaded file proper name
- **QuizAttempt.score nullable** — assignment-only quizzes should not return `0`, return `null` and let teacher grade manually
- **submit-assignment must upsert** — use `findFirst` + `create`/`update` instead of always creating new `QuizAttempt`; otherwise student gets duplicate records
- **Teacher view: consolidate all attempts per student** — a student may upload assignment (attempt A) then submit normal answers (attempt B with `{}`), creating two records. Latest-by-timestamp dedup would discard the file. Instead, fetch ALL attempts per student, then merge answers from all into one display record:
  ```ts
  // After findMany with orderBy submittedAt desc:
  const latestByUser = new Map<string, typeof attempts[0]>();
  for (const a of attempts) {
    if (!latestByUser.has(a.userId)) latestByUser.set(a.userId, a);
  }
  const mergedByUser = new Map<string, Record<string, string>>();
  for (const a of attempts) {
    const merged = mergedByUser.get(a.userId) || {};
    Object.assign(merged, JSON.parse(a.answers));
    mergedByUser.set(a.userId, merged);
  }
  const latestAttempts = Array.from(latestByUser.values()).map(a => ({
    ...a,
    answers: JSON.stringify(mergedByUser.get(a.userId)),
  }));
  ```
