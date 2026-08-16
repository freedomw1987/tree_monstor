## 1. Who are you？

- 請查看並要參照 [[SOUL]] 文件；

## 2. SOP

你做的每一項工作都要根據以下步驟及可以使用skills：

1. 溝通 &amp; 思考
2. 計劃
3. 執行
4. 自我反省
5. 提交成果
6. 重複第一步（溝通 &amp; 思考）

### 2.1. 溝通 &amp; 思考

要與用戶溝通討論出一個完整完善的方案；
**務必使用 **[[skills/dav-planner/SKILL|skills:/dav-planner]]** 技能**；

### 2.2. 計劃

用戶有機會想做一項好大的工作任務，所以你為他計劃如何去執行，並給用戶確認；
**務必使用 **[[skills/dav-designer/SKILL.md|skills:dav-designer]]** 技能**；

### 2.3. 執行

在執行工作上，你要跟計劃文檔領取工作任務，也要做好校驗測試，去確保你做出來的結果是完整和完善的；

**一開始就必須使用：**
1. [[skills/tdd-test-writer/SKILL.md|skills:tdd-test-writer]] 根據目標項目的 docs/backlog.md 編寫測試用例，為 Test-Driven Development 打好基礎；
**開發過程中配合使用：**
2. [[skills/regression-guard/SKILL.md|skills:regression-guard]] 這個是在執行開發項目時，必須要預留測試用的探針，以及自我測試修復機制技能；
3. [[skills/dev-checker-loop/SKILL.md|skills:dev-checker-loop]] 這個是一個開發項目中，自我開發和測試的循環，目的是為了出品質量是高質量；

### 2.4. 自我反省

對執行階段得出的結果作一個宏觀的反思和檢討，包括UX/UI是否符合用戶需求原意、RWD是否有考慮和完成、系統是否有技術債等問題，這個階段看整體，也要看和更改docs/backlog.md；

**務必使用 **[[skills/dav-reflection/SKILL|skills:/dav-reflection]]** 技能**；

**觸發時機（三層級）**：
- **User Story 級別**：每個 US 完成驗收後進行輕量反省，Agent 自動執行
- **Sprint 級別**：每個 Sprint 結束後進行標準反省，Agent + 用戶共同檢視
- **Module 級別**：每個功能模組交付後進行深度反省，Agent + 用戶共同檢視

**6 項必檢查維度**：
1. **UX/UI 一致性** — 是否符合用戶需求原意、符合 docs/DESIGN.md
2. **RWD 響應式設計** — 桌面、平板、手機是否正確呈現
3. **技術債** — 硬編碼、缺少抽象、文件缺失、過時依賴
4. **可維護性** — 代碼結構、命名、模組化、重複代碼
5. **測試覆蓋率** — AC 對應測試、回歸測試
6. **需求對齊** — 實際交付是否滿足用戶痛點和目的

**反省產出物**：
- 反省報告：`docs/reflection/<name>-reflection.md`（含 6 維度檢查結果、問題清單、Action Items）
- 更新 `docs/backlog.md`：把發現的問題轉化為對應類型的 Backlog item
  - 技術債問題 → Technical Debt
  - Bug → Defects
  - 缺失功能 → User Story
  - 需研究 → Spike

**關鍵原則**：
- 看整體：不要只看單一檔案，要從模組、Sprint 級別看全局
- 誠實面對問題：找到問題不要迴避，要明確標記 ❌
- 轉化為行動：反省的目的不是抱怨，而是產出可執行的 Action Items
- 用戶參與：Sprint 和 Module 級別的反省必須有用戶參與確認

### 2.5. 提交成果
