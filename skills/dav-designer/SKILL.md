---
name: dav-designer
description: 當用戶在設計階段時候，都要根據項目目錄中docs/backlog.md 去進行分析和計劃backlog 的Story Point和分拆Sprint，設計或修改UX/UI規劃的docs/design.md，修改和新增系統架構設計docs/system-design.md，之後按功能模組去修改和新增PRD文檔
---
## 1. Backlog 的分析

把項目目錄中docs/backlog.md 去進行分析，PENDING狀態的backlog item 拿出來分析，按以下方式去計劃：
1. 更新或新增 UX/UI規劃；
2. 更新或新增 技術架構設計；
3. 更新或新增 PRD（按照功能模組）；
## 2. 編寫UX/UI規劃

- 請根據 https://stitch.withgoogle.com/docs/design-md/specification/ 的格式去編寫 UX/UI規劃並放在項目目錄中 docs/DESIGN.md；
- 按照Backlog 的需求，要在設計階段就要時常關注 docs/DESIGN.md 是否需要變動，並按需求更新它；

## 3. 技術架構設計

- 按照Backlog 的需求定義好項目的：技術棧、系統組成部件（前端、後端、數據庫或其他服務等），以及按功能模組(Module)去劃分整個項目系統，更新或編寫在 docs/system-design.md；
- 劃分功能模組(Module)的目的是為每一個模組各自有一套完善的流程：執行、測試（自我反省）、提交成果的，一個模組(Module)的變更和問題，不會導致全局項目出現問題；
- 在docs/backlog.md更新Backlog中用戶故事(User Story)對應的Module，方便之後可以針對每一個Module進行執行開發或其後的工作，也評估用戶故事(User Story)按照重要性和難度去評估出Story Point;

## 3. 編寫 PRD

- 按功能模組(Module)去修改和新增PRD文檔在項目目錄中 `docs/prd/<序號-module-name>.md`，例如: docs/prd/01-user-login.md、docs/prd/02-dashboard.md；
- 在PRD文檔中，要列出Module中，所有功能清單 (FR)，方便後面進行開發；