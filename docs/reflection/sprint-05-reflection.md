# Sprint 05 反省 — TD-021 cleanup 強化（2026-01-15）

> 對應 SOP §2.4 dav-reflection 階段

## 1. Sprint 概覽

| 項目 | 計畫 | 實際 |
| --- | --- | --- |
| 範圍 | TD-021.1 ~ TD-021.7（7 子任務） | 100% 涵蓋 |
| Story Point | 2.75 SP | 2.75 SP |
| Sprint 期間 | 1 輪對話 | 1 輪對話 |
| P1 問題 | 預期 0 | self-review 找到 6（實測時揭露，全部已修） |
| P2 + P3 | 預期 8 條（Sprint 04 reviewer） | 0 條（已在 TD-021.2/021.3/021.4/021.5 全部修） |

## 2. 6 維度反省

### 2.1 用戶體驗

**結論**：✅ 通過

- V01/V02 紀律嚴格遵循
- Sprint 05 把 Sprint 04 留下的「未實作」項目補完，使用者不會再撞到「預期與實際不符」的問題

**亮點**：
- `--purge` 模式不重建 README（測試覆蓋）— 用戶可放心清掉
- README 重建現在是 cleanup 工具的標準動作，無需手動跑

**待改善**：
- README 重建格式仍較簡陋（只有 categories / tags 統計），未來可加「最近更新」「熱門 tag」等

### 2.2 RWD / 跨平台

**結論**：⚠️ 部分注意

- Python heredoc 嵌入 bash 在 macOS + Linux 行為應一致 ✅
- 但**沒實機在 Linux 跑過**（TD-006 仍未做）— 仍是監控項

### 2.3 技術債

**結論**：✅ TD-021 全清，**0 個 P1 技術債**

#### 本 Sprint 還的債
- ✅ TD-021.1：cleanup README 重建
- ✅ TD-021.2：errors counter 修
- ✅ TD-021.3：cross-ref tie 排序
- ✅ TD-021.4：cleanup 程式碼風格
- ✅ TD-021.5：cross-ref 旗標解析風格
- ✅ TD-021.6：examples.md 範例 1 keywords
- ✅ TD-021.7：7 個邊緣案例測試（E1-E7）

#### Sprint 04 留下的債
- ✅ Sprint 04 reviewer 找的 3 P1（SKILL.md typo / smoke-test 過度承諾 / cleanup handbook 註明未實作）已修
- ✅ Sprint 04 reviewer 找的 5 P2 + 3 P3 已在 Sprint 05 處理

#### 本 Sprint 揭露的新債
- ⚠️ P1-1：Python heredoc 語法錯誤（原本 Sprint 03 US-009 寫的，遺留 bug）— 已修
- ⚠️ P1-2 ~ P1-5：原有功能沒被測試抓到，self-review 實測時揭露 — 已修

### 2.4 可維護性

**結論**：✅ 通過

- README 重建從 `docs/sop/handbook/dav-wiki-cleanup.md` step [9] 完整描述
- 兩個 CLI 旗標解析統一（`while ... case ... shift` 模式）
- 7 個邊緣案例測試保證未來迴歸會被即時抓到

**亮點**：
- 「實測 fixture」揭露 4 個既有 bug（heredoc / unbound variable / path 邏輯 / original_path 邏輯）— 證明 fixture-based self-review 有效

### 2.5 測試覆蓋

**結論**：✅ 105/105 全綠（+9 新增，0 破壞）

| 套件 | 通過/總數 | 變化 |
| --- | --- | --- |
| wiki-cleanup | 17/17 | +6（E1-E4 + TD-021 README + --purge 不重建）|
| wiki-cross-ref | 10/10 | +3（E5-E7）|

**邊緣案例覆蓋率**：E1-E7 全綠 + README 重建測試覆蓋。

### 2.6 需求對齊

**結論**：✅ 100% 對齊 TD-021 AC

| 需求 | 達成 |
| --- | --- |
| TD-021.1：cleanup README 重建 | ✅（含 categories + tags 統計）|
| TD-021.2：errors counter 修 | ✅ |
| TD-021.3：cross-ref tie 排序 | ✅ |
| TD-021.4：cleanup 風格 | ✅ |
| TD-021.5：cross-ref 風格 | ✅ |
| TD-021.6：examples.md 範例 1 | ✅ |
| TD-021.7：7 邊緣案例 | ✅（E1-E7）|

## 3. 行動項目

### 必修
（無）

### 監控項
- README 重建格式可再豐富（加入「最近更新」「熱門 tag」等）
- TD-006（GitHub Actions CI）仍未做
- Linux 實機測試仍未做

## 4. 學習

1. **實測 fixture 比程式碼靜態讀更有效**：self-review 實測 fixture 一次抓出 4 個 P1（heredoc 語法 / unbound variable / 路徑邏輯 / 絕對路徑），靜態讀幾乎不可能抓出。
2. **reviewer subagent `find /` 是危險操作**：未來 reviewer 提示詞要明確禁止全檔案系統掃描。
3. **Python heredoc 嵌入 bash 容易出 bug**：每改必實測。

## 5. 結論

Sprint 05 成功交付 2.75 SP，4 Gate 全綠，105/105 tests pass。

- TD-021 7 個子任務全完成
- Sprint 04 reviewer 找的 11 條問題全清
- self-review 揭露 6 個新 P1（已修）
- 揭露 1 個 Sprint 03 遺留 bug（Python heredoc）

技術債：0 個 P1，整個 cleanup / cross-ref 工具鏈進入「可上 production」狀態。

下一個 Sprint 候選：
- A. 跑 TD-006（GitHub Actions CI + Linux 實機驗證）
- B. 換方向（installer 加強 / 新功能 / 其他）
- C. 休息消化成果