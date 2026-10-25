# Dav Reconciler — CHANGELOG

> 本檔為 dav-reconciler 的完整變動歷史。引用：同套 SKILL.md 變動歷史章節
>
> 從 v1.0 起，變動歷史即外移到本檔；主檔只保留最近 3 條以節省 LLM 注意力。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|------|
| v1.1 | 2026-10-26 | 配套探針修正 + 檢查工具收緊：RECON-007 解析器改 python3（修 BSD grep 交替分支上限 bug）；`check-doc-drift.py` 的 `--from-date` 改為格式驗證 + fail-closed（rc=2）；新增 DOC-DRIFT-036/037 | 第 6 輪對帳：RECON-007 v1.0 的 `grep -oE` 在 BSD grep 2.6 上只認 2 個交替分支 → 探針本身紅 → mutant 守護整表中止（4 支從未被真的跑到）；`--from-date` 傳入非法值會讓 D8 硬門檻被靜默關掉 → 假綠。兩者皆為**工具缺陷**，非需求缺口。V03 Reviewer 二審見全域 changelog v2.12 |
| v1.0 | 2026-10-26 | 初版：5 步流程（準備輸入 → 獨立 subagent 對帳 → R-ID 覆蓋檢查 → 寫檔 → 交給交付摘要）+ 硬門檻 + 降級路徑 + trust 例外 | TMO-072：使用者回報「用戶提出需求，最後 AI 出來的成果對不上」；pipeline 內沒有任何一環在做「需求 ↔ 成果」比對，交付摘要由執行者自評。V03 Reviewer 二審：第 1 輪 request-changes → 已修，結論見全域 changelog v2.11 二審結論節 |
