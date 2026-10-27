# Runner Cheatsheet — TTY Fail-Fast 對照表

> 本檔為 dav-developer 的「主流 runner TTY fail-fast 對照表」章節（v2.1 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：拆檔當時 對照表 37 行屬於「執行前才查」，不在「skill 用法」主流程上。

## 主流 runner TTY fail-fast 對照表

- **vitest**
  - ❌ 禁用（會卡）：`vitest` / `npx vitest`
  - ✅ 使用（一次性跑完）：`vitest run` / `npx vitest --run`
- **jest**
  - ❌ 禁用（會卡）：`jest` / `npm test`（若 script 帶 watch）
  - ✅ 使用（一次性跑完）：`jest --ci` / `CI=1 npm test -- --watchAll=false`
- **npm test**
  - ❌ 禁用（會卡）：視 package.json 設定
  - ✅ 使用（一次性跑完）：加 `CI=1` 前綴 + 顯式 `--watchAll=false` 或 `--run`
- **bats**
  - ❌ 禁用（會卡）：—
  - ✅ 使用（一次性跑完）：`bats tests/`（預設 OK）
- **pytest**
  - ❌ 禁用（會卡）：`pytest --watch`
  - ✅ 使用（一次性跑完）：`pytest` / `pytest -x`
- **playwright**
  - ❌ 禁用（會卡）：`playwright test --ui`
  - ✅ 使用（一次性跑完）：`playwright test`（預設 headless）
- **cargo test**
  - ❌ 禁用（會卡）：—
  - ✅ 使用（一次性跑完）：`cargo test`
- **go test**
  - ❌ 禁用（會卡）：—
  - ✅ 使用（一次性跑完）：`go test ./...`

## 通用保險：TTY 強制關閉

若不確定 runner 行為，**一律在指令後加 `< /dev/null`**：

```bash
np
m test < /dev/null

npx vitest < /dev/null
```

或設定 `CI=1`（多數 runner 自動關 watch）：

```bash
CI
=1 npm test
```

## Fail-fast 自檢

執行後若出現以下任一情況 = **Gate 3 失敗**：
- shell 卡住 > 30 秒無輸出
- 輸出末端出現 `Watch Usage` / `press h to show help` / `Waiting for file changes`
- 進程未退出、`Ctrl+C` 才能結束

正確做法：kill 進程 → 補上前綴規則 → 重跑。
