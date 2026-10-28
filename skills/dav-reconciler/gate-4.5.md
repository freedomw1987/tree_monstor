# Dav Reconciler — Gate 4.5 需求對帳（§2.3 尾段子閘）

> 本檔為 `dav-reconciler` skill 的子檔，承載 Gate 4.5 嘅定義（pass_criteria / required_evidence / fail_action /
> mandatory_phrase）。入口在同套 `SKILL.md`。

## Gate 定義（本節是 single source 之一；定義本體＝ monorepo 對應 handbook 嘅「Gate 4.5 需求對帳」段）

> **進本 Gate 時必須在對話引用下表嘅 `mandatory_phrase`；不引用＝視為 gate 未觸發**（屬「偽裝通過」，依 SOP 的違規回報規則處理）。

### Gate 4.5 需求對帳（§2.3 尾段子閘）

> Gate 4.5 是**內嵌子閘**，不進 gates 設定檔（該檔嘅 gate `id` 受 schema 限制，只允許整數編號嘅四大 Gate）。佢嘅定義本體在 monorepo 對應 handbook 嘅「Gate 4.5
> 需求對帳」段（本節為該段嘅 skill 端鏡像；鎖兩邊一致嘅探針已於 2026-10-27 減法刪走 → 兩邊要人手同步）。

- **pass_criteria**
  - 內容：① 對帳表覆蓋錨點的全部 R-ID（覆蓋率 100%）② 由未參與實作的獨立 subagent 執行（降級須標註）③ 對帳結果帶入交付摘要，且交付狀態與對帳結果一致
- **required_evidence**
  - 內容：① 需求對帳表（落在目標專案的 reconcile 目錄）② 未參與實作的 subagent 對帳原文回傳 ③ 交付摘要的「需求對帳」段與覆蓋率
- **fail_action**
  - 內容：不可進入 §2.4 反省
- **mandatory_phrase**
  - 內容：依 §2.3 規範，Gate 4.5 (需求對帳) 需要：對帳表覆蓋全部 R-ID + 獨立 subagent 對帳原文 + 交付狀態與對帳結果一致，並在對話貼出對帳表與覆蓋率。
