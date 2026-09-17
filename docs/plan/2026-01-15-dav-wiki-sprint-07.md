# Sprint 07 計劃 — TD-005 + TD-008 剩餘技術債（2026-01-15）

> **Sprint 主題**：把技術債從 2 推到 0
> **總 SP**：1.5 SP
> **前置**：Sprint 06 ✅ DONE

## 1. Sprint 目標

清掉從 US-001 留下、到現在還沒清的 2 條技術債：
- TD-005：install.sh AC-11a 冪等測試改為精準版本（不依賴 hash）
- TD-008：install.sh magic strings 集中成變數

## 2. Sprint Backlog

| ID | 標題 | SP | 優先級 |
| --- | --- | --- | --- |
| **TD-005** | install.sh AC-11a 改為更精準冪等測試（比對具體檔案而非 hash） | 0.5 | P2 |
| **TD-008** | install.sh Magic strings 集中成變數（`.claude`/`.pi`/`.agents`/marker）| 1 | P3 |

## 3. TD-005 設計

### 現狀

`tests/install.bats:155` 用 hash 比對冪等性：
```bash
@test "AC-11a: install.sh 冪等（重跑結果一致）" {
    # 跑一次 install
    # hash 結果
    # 再跑一次
    # 兩個 hash 比對
}
```

**問題**：
- hash-based 跨平台可能不一致（不同檔案系統的 mtime / permissions）
- 真正要驗的是「具體檔案存在 + 內容相同」

### 新設計

改成「具體檔案清單」冪等：
1. 第一次跑完，列出所有產出的檔案 + 內容 hash
2. 第二次跑完，列出所有產出的檔案 + 內容 hash
3. 兩個清單比對：檔案名清單相同、檔案內容 hash 相同

**更精準**：因為我們只比對 `install.sh` 自己產出的檔案，不比對整個 `$HOME` 目錄。

## 4. TD-008 設計

### 現狀

`install.sh` 中散落：
- `.claude` → 7 處
- `.pi` → 5 處
- `.agents` → 4 處
- `tree-monstor-loader:DO-NOT-EDIT-START` marker → 6 處

**問題**：未來新增 agent 時，要全部找一遍改路徑；marker 改文字要全文搜尋。

### 新設計

集中在 `install.sh` 開頭：
```bash
# === 路徑常數（改這裡就能改所有地方） ===
AGENT_DIRS=(
    "claude:$HOME/.claude"
    "pi:$HOME/.pi"
    "agents:$HOME/.agents"
)
LOADER_MARKER="tree-monstor-loader:DO-NOT-EDIT-START"
LOADER_END_MARKER="tree-monstor-loader:DO-NOT-EDIT-END"
```

把現有函數重構使用這些常數。

## 5. 執行順序

```
[1] TD-008 magic strings 集中（先重構以便後續測試）  [Refactor]
    ↓
[2] TD-005 改冪等測試（用具體檔案比對）  [Test]
    ↓
[3] Sprint 07 reflection + submitter
```

## 6. 成功指標

- bats 全套不退步（110 → 112+）
- TD-005 / TD-008 從 PENDING 移到 DONE
- install.sh magic strings 集中（前 100 行有所有常數）
- AC-11a 冪等測試改為「具體檔案清單比對」
- 技術債總數：2 → 0

## 7. 對話記錄

- 用戶決策：2026-01-15 選擇「A 跑 TD-005 + TD-008」
- 規劃模式：dav-planner（單輪決策）