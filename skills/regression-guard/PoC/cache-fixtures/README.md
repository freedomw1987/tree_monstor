# cache-fixtures — Jev oracle 離線快取 fixture

## 這是什麼

`fix_proposal.py` / `fix_proposal_v2.py` 會把「失敗步驟 + 3 個問題」送給 Jev
（`typesafe/jev-1.13`，透過 OpenRouter）算信心度，回應會快取在
`PoC/cache/`（本機 state，**不版控**）。

CI（GitHub Actions）既沒有 `OPENROUTER_API_KEY`，也沒有 `PoC/cache/` →
CLI 直接抛 `RuntimeError` → `M6-g` / `M6.1-c` 探針紅。

這個目錄把「跑那兩支 CLI 剛好需要的那幾筆回應」版控起來，讓探針完全離線。

## 檔案

| 檔名 | 內容 |
| --- | --- |
| `e78dab15a3b78026.json` | fix_proposal(v2) 對 `fixtures/US-101-run.json` 的 3 題 noul 回應（problem_summary 0.22 / proposed_fix 0.12 / verification_steps 0.40）|

檔名 = `sha256(payload)`，由 `jev_oracle._cache_key()` 決定；payload 只含
AC 文字與觀察結果（不含機器路徑），所以同一份 run json 在任何機器都命中同一筆。

## 怎麼用

CLI 不認識「fixture 目錄」這個概念——它只是換一個快取目錄：

```bash
env -u OPENROUTER_API_KEY HOME=/tmp/nohome \
    JEV_CACHE_DIR="$PWD/cache-fixtures" \
    .venv/bin/python fix_proposal.py fixtures/US-101-run.json /tmp/fix.md
```

`JEV_CACHE_DIR` 是 `jev_oracle.py` 的環境變數 seam（預設仍是 `PoC/cache`）。

## 怎麼重新產生

改了 `fixtures/US-101-run.json`（或改了送給 Jev 的問題）就會 miss → 必須重錄：

```bash
cd skills/regression-guard/PoC
rm -rf cache-fixtures && mkdir -p cache-fixtures
JEV_CACHE_DIR="$PWD/cache-fixtures" OPENROUTER_API_KEY=<key> \
  .venv/bin/python fix_proposal.py fixtures/US-101-run.json /tmp/fix.md
JEV_CACHE_DIR="$PWD/cache-fixtures" OPENROUTER_API_KEY=<key> \
  .venv/bin/python fix_proposal_v2.py fixtures/US-101-run.json /tmp/v2.md
git add cache-fixtures   # 記得只 commit *.json，不要 commit 密鑰
```

## 防線

- `tests/poc-clean-clone.bats` → `CLEAN-POC-f`：動態挑出所有提到 oracle 的測試檔
  （目前是 `tests/v2.1-jev-poc.bats`），把環境清成跟 CI 一樣
  （無 key、`HOME` 換掉、`JEV_CACHE_DIR` 指向空目錄、**`JEV_ENV_FILE=/dev/null`**）
  整檔重跑；任何一條回頭依賴真 API / 本機暖快取 / 本機 `.env` 就會紅。
- `CLEAN-POC-h`：`PoC/.env`、`PoC/.env.local`、`PoC/cache/*` 一律不得被 git 追蹤
  （另驗 `PoC/.env.example` 有在版控、`.gitignore` 真的擋著）。
- `CLEAN-POC-i`：反向驗證 `JEV_ENV_FILE` seam——造假的 `.env` 時讀得到、
  覆寫成 `/dev/null` 時兩個來源（`PoC/.env` 與 `~/.claude/.../PoC/.env`）都讀不到。
- 本檔與 `*.json` 必須**被 git 追蹤**（CLEAN-POC-f 會驗），否則 clean clone 缺檔。

> ⚠️ 本目錄的 `*.json` 是**離線 fixture（可版控）**，與 `PoC/cache/`（本機暖快取、
> 8206 檔、已 gitignore）是兩回事。不要把 `PoC/cache/` 的東西搬進來。
