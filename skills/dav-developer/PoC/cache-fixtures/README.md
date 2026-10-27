# cache-fixtures — Jev oracle 離線快取 fixture

## 這是什麼

`fix_proposal.py` / `fix_proposal_v2.py` 會把「失敗步驟 + 3 個問題」送給 Jev
（`typesafe/jev-1.13`，透過 OpenRouter）算信心度，回應會快取在
`PoC/cache/`（本機 state，**不版控**）。

CI（GitHub Actions）既沒有 `OPENROUTER_API_KEY`，也沒有 `PoC/cache/` →
CLI 直接抛 `RuntimeError` → `M6-g` / `M6.1-c` 探針紅。

這個目錄把「跑那兩支 CLI 剛好需要的那幾筆回應」版控起來，讓探針完全離線。

## 檔案

- **`8b68c2cc7c16c510.json`**
  - 內容：
    fix_proposal(v2) 對 `fixtures/US-101-run.json` 的 3 題 noul 回應（problem_summary 0.22 / proposed_fix 0.12 /
    verification_steps 0.40）
- **`bbfaa5bfe583507a.json`**
  - 內容：
    US-M63 journey **第 1 步**（`US-M63-AC01-s1`）的 oracle 回應（verdict=fail）。M6.3 系列探針用：baseline 跑與 sandbox 重跑都靠它拿到同一個
    verdict → `no_change` 斷言才可重現（見下方「M6.3 為什麼需要它」）

檔名 = `sha256(payload)`，由 `jev_oracle._cache_key()` 決定；payload 只含
AC 文字與觀察結果（不含機器路徑），所以同一份 run json 在任何機器都命中同一筆。

> ⚠️ payload 裡的 `Elapsed: N ms` 來自 `journey_runner.stable_step_offset()`
> （**穩定** hash，不是內建 `hash()`——內建的 str hash 有 PYTHONHASHSEED 隨機化，
> 會讓同一 step 每次拿到不同 elapsed → payload 每次不同 → 快取永遠 miss）。
> 改了 `stable_step_offset()` 就必須重錄對應 fixture（檔名也會跟著變）。

## 怎麼用

CLI 不認識「fixture 目錄」這個概念——它只是換一個快取目錄：

```bash
en
v -u OPENROUTER_API_KEY HOME=/tmp/nohome \

    JEV_CACHE_DIR="$PWD/cache-fixtures" \
    .venv/bin/python fix_proposal.py fixtures/US-101-run.json /tmp/fix.md
```

`JEV_CACHE_DIR` 是 `jev_oracle.py` 的環境變數 seam（預設仍是 `PoC/cache`）。

## M6.3 為什麼需要它

M6.3 系列的斷言是「patch 與 AC 無關 → 重跑後 verdict 分布不變 → 判 `no_change`」。
這要求 **baseline 跑與 sandbox 重跑兩次的 verdict 分布一模一樣**。三件事會破壞它：

1. oracle 打得到網路 → 結果隨當下 API 狀態浮動；
2. 本機 `PoC/cache/` 有殘留命中 → 哪一次命中會隨 `elapsed_ms` 變；
3. `PoC/.env` / `~/.claude/.../PoC/.env` 裡的 key。

所以 M6.3 探針一律用這組環境變數（見 `skills/dav-developer/tests/v2.1-jev-poc.bats` 的 `m63_hermetic_env`）：

```bash
en
v -u OPENROUTER_API_KEY \

    JEV_CACHE_DIR="$PWD/cache-fixtures" \
    JEV_ENV_FILE=/dev/null \
    .venv/bin/python run_journey.py journeys/US-M63.yaml --json-output /tmp/before.json
```

- `JEV_CACHE_DIR` → 版控 fixture（唯一可命中的來源）
- `JEV_ENV_FILE=/dev/null` → 等效「本機沒有任何 `.env`」（TMO-045 的 seam）
- `-u OPENROUTER_API_KEY` → 拔掉環境變數來源的 key

結果：US-M63 journey 的第 1 步命中 `bbfaa5bfe583507a.json`（verdict=fail），
第 2 步起 cache miss 且無 key → blocked。before / after 兩次的分布恆為
`{fail: 1, blocked: 14}` → `no_change` **每次都成立**，且全程不碰網路
（約 0.1 秒，原本會打 3 次網路重試 ≈ 4.6 秒）。

## 怎麼重新產生

改了 `fixtures/US-101-run.json`（或改了送給 Jev 的問題）就會 miss → 必須重錄：

```bash
c
d skills/dav-developer/PoC

rm -rf cache-fixtures && mkdir -p cache-fixtures
JEV_CACHE_DIR="$PWD/cache-fixtures" OPENROUTER_API_KEY=<key> \
  .venv/bin/python fix_proposal.py fixtures/US-101-run.json /tmp/fix.md
JEV_CACHE_DIR="$PWD/cache-fixtures" OPENROUTER_API_KEY=<key> \
  .venv/bin/python fix_proposal_v2.py fixtures/US-101-run.json /tmp/v2.md
git add cache-fixtures   # 記得只 commit *.json，不要 commit 密鑰
```

改了 `journey_runner.stable_step_offset()`（或 journey / AC 內容）→
`bbfaa5bfe583507a.json` 也會 miss → 也要重錄，而且**檔名要跟著 payload 的新 key 改**：

```bash
c
d skills/dav-developer/PoC

# 跑一次 journey → 從 stderr 的 "Cache miss" 對照 payload 算出新 key
JEV_CACHE_DIR="$PWD/cache-fixtures" OPENROUTER_API_KEY=<key> \
  .venv/bin/python run_journey.py journeys/US-M63.yaml --json-output /tmp/after.json
# 把錄到的回應存成 cache-fixtures/<新 key>.json，並刪掉舊檔名
```

## 防線

- `tests/poc-clean-clone.bats` → `CLEAN-POC-f`：動態挑出所有提到 oracle 的測試檔
  （目前是 `skills/dav-developer/tests/v2.1-jev-poc.bats`），把環境清成跟 CI 一樣
  （無 key、`HOME` 換掉、`JEV_CACHE_DIR` 指向空目錄、**`JEV_ENV_FILE=/dev/null`**）
  整檔重跑；任何一條回頭依賴真 API / 本機暖快取 / 本機 `.env` 就會紅。
- `CLEAN-POC-h`：`PoC/.env`、`PoC/.env.local`、`PoC/cache/*` 一律不得被 git 追蹤
  （另驗 `PoC/.env.example` 有在版控、`.gitignore` 真的擋著）。
- `CLEAN-POC-i`：反向驗證 `JEV_ENV_FILE` seam——造假的 `.env` 時讀得到、
  覆寫成 `/dev/null` 時兩個來源（`PoC/.env` 與 `~/.claude/.../PoC/.env`）都讀不到。
- 本檔與 `*.json` 必須**被 git 追蹤**（CLEAN-POC-f 會驗），否則 clean clone 缺檔。

> ⚠️ 本目錄的 `*.json` 是**離線 fixture（可版控）**，與 `PoC/cache/`（本機暖快取、
> 8206 檔、已 gitignore）是兩回事。不要把 `PoC/cache/` 的東西搬進來。
