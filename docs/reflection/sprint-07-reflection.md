# Sprint 07 反省 — TD-005 + TD-008 剩餘技術債（2026-01-15）

> 對應 SOP §2.4 dav-reflection 階段

## 1. Sprint 概覽

| 項目 | 計畫 | 實際 |
| --- | --- | --- |
| 範圍 | TD-005 + TD-008 | 100% 涵蓋 |
| Story Point | 1.5 SP | 1.5 SP |
| Sprint 期間 | 1 輪對話 | 1 輪對話 |
| P1 問題 | 預期 0 | self-review 找到 2（自我引用 / 路徑分隔符，已修）|

## 2. 6 維度反省

### 2.1 用戶體驗

**結論**：✅ 通過

- install.sh 路徑常數集中在 Defaults 區塊，未來新增 agent 只需加一行 `DIR_XXX`
- AC-11a 冪等測試更具體，debug 時容易看是哪個檔案 hash 不同

### 2.2 RWD / 跨平台

**結論**：✅ 通過

- 新 AC-11a 用 realpath / shasum，跨平台行為一致
- install.sh 重構後功能不變，跨平台測試不退步

### 2.3 技術債

**結論**：✅ **技術債從 2 推到 0** 🎉

#### 本 Sprint 還的債
- ✅ TD-005：AC-11a 改為更精準冪等測試（用具體檔案清單 + sha256）
- ✅ TD-008：install.sh magic strings 集中成 `DIR_*` / `LOADER_*` 常數

#### 技術債清零

```
之前（US-001 reflection 列出 11 條）：
✅ TD-1 / TD-2 / TD-3 / TD-4：US-007 / DE-002 / TD-014 / TD-016 已修
✅ TD-5（AC-11a 精準測試）：Sprint 07 修
✅ TD-6（CI）：Sprint 06 修
✅ Magic strings 集中：Sprint 07 修

剩餘：0 條 🎉
```

### 2.4 可維護性

**結論**：✅ 通過

- `DIR_*` 常數集中在 Defaults，未來改路徑只需改 1 處
- `LOADER_MARKER` 統一，未來改 marker 文字只需改 1 處
- AC-11a 測試更具體，失敗時容易 debug

### 2.5 測試覆蓋

**結論**：✅ 110/110 全綠（+0 破壞、AC-11a 重寫）

| 套件 | 通過/總數 | 變化 |
| --- | --- | --- |
| install | 41/41 | AC-11a 重寫，更精準 |
| 其他 6 套件 | 69/69 | — |

### 2.6 需求對齊

**結論**：✅ 100% 對齊

| 需求 | 達成 |
| --- | --- |
| TD-005 AC-11a 改為更精準 | ✅ |
| TD-008 magic strings 集中 | ✅ |

## 3. 行動項目

### 必修
（無）

### 監控項
- 11 個 log_plan 顯示字串仍寫死（給用戶看的 plan strings，未來改路徑時記得同步）

## 4. 學習

1. **`readonly VAR="${VAR}"` 是自我引用 bug**：會得到空字串且 `set -u` 下觸發錯誤
2. **bash 字串拼接分隔符**：必用 `${VAR}/${X}` 明確分隔
3. **find 排序跨平台不可靠**：用具體清單 + sha256 是穩定的冪等測試模式
4. **技術債從 US-001 累積到現在**：歷經 7 個 Sprint 終於清零

## 5. 結論

Sprint 07 成功交付 1.5 SP，4 Gate 全綠，110/110 tests pass。

- TD-005 + TD-008 全完成
- 技術債從 2 推到 0 🎉
- 從 US-001 留下來的 11 條技術債全清（歷經 7 個 Sprint）

**里程碑**：技術債清零

下一步建議：
- A. 換方向（installer 加強 / 新功能 / 其他）
- B. 慶祝一下 🎉
- C. 把跨 Sprint 的 magic strings log_plan 也一起集中（清理最後的 11 處）