---
name: react-quiz-form-state-debug
description: Debug React quiz forms where submit button stays disabled for mixed question types (choice/text/assignment)
---

# React Quiz Form State Debugging

## Problem
Student "提交答案" (submit quiz) button appears disabled after uploading an assignment file. API works correctly when tested directly, but frontend UX fails silently.

## Root Cause
Quiz forms with mixed question types (choice/text/assignment) often have different answer-state ownership:
- **Choice questions**: write to parent `quizAnswers` state → button `disabled` check counts these
- **Assignment questions**: have internal `submitted` state in child `AssignmentSubmit` component → do NOT write to parent `quizAnswers`

The disabled check was:
```tsx
disabled={Object.keys(quizAnswers).length < quiz.questions.length}
```
This always fails for ASSIGNMENT questions since they never populate `quizAnswers`.

## Fix Pattern
```tsx
// Instead of counting keys:
disabled={Object.keys(quizAnswers).length < quiz.questions.length}

// Check every question's answer status, skipping ASSIGNMENT (handled by child component):
disabled={
  !quiz.questions.every(q => {
    if (q.type === 'ASSIGNMENT') return true // child component handles this
    return quizAnswers[q.id] !== undefined
  })
}
```

## Debugging Steps
1. Test API endpoint directly with curl to confirm backend works
2. Check the disabled condition in button render
3. Determine which question types write to shared state vs internal state
4. Verify each question type's answer flow:
   - Choice: `onChange` → `setQuizAnswers(prev => ({ ...prev, [q.id]: value }))`
   - Text: `onChange` → `setQuizAnswers(prev => ({ ...prev, [q.id]: value }))`
   - Assignment: `setSubmitted(true)` inside child component (not in parent)
5. Add `console.log` or React DevTools to inspect `quizAnswers` vs expected

## Files
- `frontend/src/pages/student/LessonView.tsx` — quiz form with mixed question types
- `AssignmentSubmit` component — handles file upload and has its own `submitted` state

## Prevention
When adding new question types to a quiz system, always document:
1. Does it write to shared answer state or internal state?
2. Does the submit button's disabled check account for this type?
3. Is the "submitted" indicator visible and unambiguous to the student?
