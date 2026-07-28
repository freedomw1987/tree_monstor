---
name: prisma-circular-relation-debug
description: Debug and fix Prisma schema circular relation errors — User.chatMessages, ChatSession/ChatMessage, relation cycle detection.
triggers:
  - "relation X would create a cycle"
  - "circular relation"
  - "direct relation already exists"
applicability: generic-pattern
---


Last-verified: 2026-07-28
# Prisma 循環關聯（Cycle）問題修復指南

## 徵兆

執行 `bun prisma generate` 或 `bunx prisma db push` 時出現：
```
Error: Relation X would create a cycle detected
```
或
```
Error: Exactly one relation between X and Y must be a direct relation.
```

## 常見原因

### 1. 用戶與訊息的「多對多」反向訪問

錯誤寫法：
```prisma
model User {
  chatMessages ChatMessage[]  // ❌ 直接從 User → ChatMessage
}

model ChatMessage {
  userId String
  user   User @relation(fields: [userId], references: [id])
}
```

正確寫法（透過 ChatSession 中轉）：
```prisma
model User {
  chatSessions ChatSession[]  // ✅ User → ChatSession → ChatMessage
}

model ChatSession {
  id        String @id @default(cuid())
  userId    String
  user      User   @relation(fields: [userId], references: [id])
  messages  ChatMessage[]
}

model ChatMessage {
  sessionId String
  session   ChatSession @relation(fields: [sessionId], references: [id])
}
```

**原則：用戶不直接擁有訊息，而是透過 Session/Conversation 間接擁有。**

### 2. 雙向 @relation 未指定 fields

```prisma
// 錯誤
model A {
  id  String @id
  b   B      @relation(fields: [bId], references: [id])  // 需要 fields
  bId String
  bs  B[]
}

// 正確
model A {
  id   String @id
  bId  String
  b    B     @relation(fields: [bId], references: [id])
  bs   B[]
}
```

## 修復流程

1. 確認出錯的兩個 model（A → B → A 形成 cycle）
2. 找出中間 model（如 ChatSession），讓雙方都指向它
3. 移除直接連接
4. 執行 `bun prisma generate` 確認修復
5. 如果有資料，使用 `bunx prisma db push --force-reset` 或 migrate

## 驗證

```bash
bun prisma generate
# Expected: Generated Prisma Client in Xms
```