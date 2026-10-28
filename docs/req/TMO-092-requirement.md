# TMO-092 需求錨點

> US: TMO-092 | 建立: 2026-10-27 | 來源: 用戶決策（拆 Jev Oracle 做獨立 skill）

## 用戶原話（唯讀）

- R1: 「好，做 ②」（← 上一輪建議嘅選項 ② ＝「`dav-developer` 再瘦身（context 2,098 行）」，
  建議內容 ＝「拆『Jev Oracle』做獨立 skill → dav-developer 返到 ~800 行」）

## 澄清後驗收句

- R1: Jev Oracle 相關內容（`jev-oracle.md`、`examples.md`、`api-contract.md`、`output-format.md`、
  `PoC/`、4 支探針）要**拆成獨立 skill `dav-jev-oracle`**，令：
  ① `dav-developer` 專注「寫測試 → 紅變綠 → 探針同回歸 → Reviewer 二審」；
  ② `dav-jev-oracle` 自足（PoC ＋ 探針 ＋ 文件）；③ 兩邊指標互指、冇死引用。

## 執行約束（repo 既有規則，唔屬驗收句）

- 改 skill → 依 `dav-skill-creater` v2.3 修改流程（M-Step 1-3）＋ `AGENTS.md` §1.5 V03 二審
- 文檔行數限制（v2.8）：主檔 ≤150（硬）／子檔 ≤300（硬）／context ratchet（只可下唔可上）
- frontmatter 必須係合法 YAML（`description:` 單行或 `>-` block scalar）

## 變更歷史

| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-10-27 | 初版 | 用戶決策整理成錨點 |
