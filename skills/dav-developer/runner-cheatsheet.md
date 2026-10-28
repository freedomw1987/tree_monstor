# Runner Cheatsheet — TTY Fail-Fast 對照表

> 本檔為 `dav-developer` 嘅「主流 runner TTY fail-fast 對照表」子檔（v2.1 累積；v2.11 減法版壓縮）。
> **禁用**：會卡住等 stdin 嘅 watch／interactive 模式；**使用**：一次性跑完嘅指令。

## 對照表

- **vitest** — ❌ 禁用：`vitest`／`npx vitest`；✅ 使用：`vitest run`／`npx vitest --run`
- **jest** — ❌ 禁用：`jest`／`npm test`（若 script 帶 watch）；✅ 使用：`jest --ci`／`CI=1 npm test -- --watchAll=false`
- **npm test** — ❌ 禁用：視 package.json 設定；✅ 使用：加 `CI=1` 前綴 ＋ 顯式 `--watchAll=false` 或 `--run`
- **bats** — ❌ 禁用：—；✅ 使用：`bats tests/`（預設 OK）
- **pytest** — ❌ 禁用：`pytest --watch`；✅ 使用：`pytest`／`pytest -x`
- **playwright** — ❌ 禁用：`playwright test --ui`；✅ 使用：`playwright test`（預設 headless）
- **cargo test** — ❌ 禁用：—；✅ 使用：`cargo test`
- **go test** — ❌ 禁用：—；✅ 使用：`go test ./...`

## 通用保險：TTY 強制關閉

不確定 runner 行為 → **一律在指令後加 `< /dev/null`**（例：`npm test < /dev/null`），
或設 `CI=1`（多數 runner 自動關 watch，例：`CI=1 npm test`）。

## Fail-fast 自檢

執行後出現以下任一情況 = **Gate 3 失敗**：

- shell 卡住 > 30 秒無輸出
- 輸出末端出現 `Watch Usage`／`press h to show help`／`Waiting for file changes`
- 進程未退出、要 `Ctrl+C` 才能結束

正確做法：kill 進程 → 補上前綴規則 → 重跑。
