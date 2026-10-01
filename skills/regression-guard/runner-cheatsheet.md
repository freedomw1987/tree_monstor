# Runner Cheatsheet — TTY Fail-Fast 對照表

> 本檔為 regression-guard 的「主流 runner TTY fail-fast 對照表」章節（v2.1 累積）。
> 引用：`SKILL.md` 對應章節
>
> 從 SKILL.md v2.9 起，本檔獨立。理由：對照表 37 行屬於「執行前才查」，不在「skill 用法」主流程上。

## 主流 runner TTY fail-fast 對照表

| Runner | ❌ 禁用（會卡） | ✅ 使用（一次性跑完） |
|---|---|---|
| **vitest** | `vitest` / `npx vitest` | `vitest run` / `npx vitest --run` |
| **jest** | `jest` / `npm test`（若 script 帶 watch）| `jest --ci` / `CI=1 npm test -- --watchAll=false` |
| **npm test** | 視 package.json 設定 | 加 `CI=1` 前綴 + 顯式 `--watchAll=false` 或 `--run` |
| **bats** | — | `bats tests/`（預設 OK）|
| **pytest** | `pytest --watch` | `pytest` / `pytest -x` |
| **playwright** | `playwright test --ui` | `playwright test`（預設 headless）|
| **cargo test** | — | `cargo test` |
| **go test** | — | `go test ./...` |

## 通用保險：TTY 強制關閉

若不確定 runner 行為，**一律在指令後加 `< /dev/null`**：

```bash
npm test < /dev/null
npx vitest < /dev/null
```

或設定 `CI=1`（多數 runner 自動關 watch）：

```bash
CI=1 npm test
```

## Fail-fast 自檢

執行後若出現以下任一情況 = **Gate 3 失敗**：
- shell 卡住 > 30 秒無輸出
- 輸出末端出現 `Watch Usage` / `press h to show help` / `Waiting for file changes`
- 進程未退出、`Ctrl+C` 才能結束

正確做法：kill 進程 → 補上前綴規則 → 重跑。
