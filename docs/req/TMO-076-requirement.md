# TMO-076 需求錨點

> US: TMO-076 | 建立: 2026-10-26 | 來源: 用戶對話（2026-10-26 §2.1 前置訪談）

## 用戶原話（唯讀）

- R1: 「我想AGENTS.md 的SOP 也不用了」
- R2: 「因為未必所有任務都要行這麼多步驟」
- R3: 「有些gate 是要寫在Skill中」
- R4: （選項回答）「只改 AGENTS.md，其餘原地保留」

## 澄清後驗收句

- R1: `AGENTS.md` 不再內嵌 SOP（只留「你是誰 + 萬事原則 + 行為紀律」），且沒有留下指向舊 §2 的 live 引用
- R2: 預設不再強制跑流程；只有「要寫 code / 要改規範 / 用戶明示要走正式流程」才進對應的 Gate
- R3: 每道 Gate 的定義（name / pass_criteria / required_evidence / fail_action / mandatory_phrase）
  落在承載它的 skill 內，且與 `docs/sop/gates.json` 逐條一致
- R4: SOP 本體（handbook / `gates.json` / SOP 階段 skill / `lib/install/sop.sh`）全部原地保留，未被刪除

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-10-26 | 初版 | 用戶對話逐字保存（不在 SOP 規劃階段產生，屬規範層調整）|
