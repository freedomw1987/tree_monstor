# Contributing to tree_monstor

歡迎貢獻！本文件說明如何在本機開發、跑測試、提 PR。

## 開發環境

### macOS

```bash
# 安裝 bats（釘版 v1.14.0：CI 用同一個 tag，發行版版本會漂移 → 本機綠／CI 紅）
git clone --branch v1.14.0 --depth 1 https://github.com/bats-core/bats-core.git
sudo ./bats-core/install.sh /usr/local

# 安裝 markdownlint
npm install -g markdownlint-cli2

# 安裝媒體工具（媒體探針的硬依賴：AC-A* / AC-W* / AC-V* 一組，加上 pptx-slim，缺了會紅）
brew install ffmpeg poppler pandoc tesseract

# ffmpeg 版本底線：>= 5.1（-fps_mode 自 5.1 起取代 -vsync）
#   CI 兩平台實測：ubuntu-latest（apt，6.x）、macos-latest（brew，8.x）
#   檢查方式：bash scripts/ci/check-ffmpeg-version.sh
#     （①比版本底線 ②用本 repo 真的在用的旗標組合實測能力，缺一即 rc=1）
#     ②目前兩組：wiki 抽章節（select/showinfo + -fps_mode vfr）
#                pptx-slim 轉碼（scale 表達式 + libx264 + aac + -movflags +faststart）
# 移除/改名清單（本 repo 已改用新寫法，勿再引入舊旗標）：
#   -vsync        → 已於 ffmpeg 8 移除，改用 -fps_mode（AC-V11 靜態擋）
#   （下一個移除的旗標無法預期 → 靠 check-ffmpeg-version.sh 的能力實測 +
#     tests/wiki-video-audio.bats 的功能探針一起兜底）

# 確認 python3
python3 --version
# python-pptx：pptx-slim 探針（tests/pptx-slim.bats 造 fixture、verify G3b 開檔）的硬依賴
python3 -m pip install python-pptx
```

### Linux (Ubuntu)

```bash
# 安裝媒體工具（ffmpeg/ffprobe 是多組媒體探針的硬依賴，缺了會紅）
sudo apt-get update
sudo apt-get install -y ffmpeg poppler-utils pandoc tesseract-ocr

# 安裝 bats：同 macOS 的釘版做法（不要用發行版套件，版本會漂移）
git clone --branch v1.14.0 --depth 1 https://github.com/bats-core/bats-core.git
sudo ./bats-core/install.sh /usr/local

# 安裝 markdownlint
npm install -g markdownlint-cli2

# python-pptx：pptx-slim 探針（tests/pptx-slim.bats 造 fixture、verify G3b 開檔）的硬依賴
python3 -m pip install python-pptx
```

## 跑測試

```bash
# 建 PoC venv（httpx + PyYAML；v2.1-jev-poc.bats 的 40 條需要）
bash skills/regression-guard/PoC/setup-venv.sh
# 重建：--force 會 rm -rf 目標目錄（TMO-040 護欄：危險路徑如 $HOME、/private/tmp、/usr
# 直接拒；自訂 POC_VENV_DIR 且目錄已存在時需輸入目錄名確認，非互動腳本加 --yes）

# 跑全套 bats tests
bats tests/

# 跑單一測試
bats tests/wiki-cleanup.bats

# 跑邊緣案例
bats tests/wiki-cleanup.bats --filter "E1"
```

```bash
# 跑突變測試（TMO-065／066）：在 working tree 的**副本**上把 58 支 mutant 逐一種回去，
# 每支都必須讓對應探針變紅（紅＝探針真的咬得住）；working tree 不會被改到（md5 自證）
python3 scripts/ci/mutant-must-die.py
# 只跑幾支（除錯用）：python3 scripts/ci/mutant-must-die.py --only V-M1,IMG-M3
# 改了表內任何目標檔的碼（pptx-slim 腳本、dav-wiki 腳本、regression-guard 的文件／gates.json），
# 就要同步更新 scripts/ci/mutants.tsv：
# 表的「原文」是整行精確比對，錨點對不上會直接 FAIL（不是 skip）；
# 新增防呆／護欄時請補一列 mutant，否則 CI 不會知道你補的東西有沒有被測到。
```

> ⚠️ **本機綠 ≠ CI 綠**：CI 是 clean clone，拿不到未版控的檔案，也**沒有 `OPENROUTER_API_KEY` 與暖快取**。
> 若新增測試素材，必須真的 `git add`（`tests/poc-clean-clone.bats` 會擋）；
> fixture 內也不得寫自己機器的絕對路徑。
>
> 會呼叫 Jev oracle 的 CLI（`fix_proposal*.py`）必須離線可跑：
> 用版控的 `PoC/fixtures/US-101-run.json` + `PoC/cache-fixtures/` +
> `JEV_CACHE_DIR=<dir>`（詳見 `PoC/cache-fixtures/README.md`）；
> 探針內也要加 `JEV_ENV_FILE=/dev/null`（TMO-045），否則本機 `PoC/.env` 會在
> cache miss 時拿真 key 去打 API，把「fixture 不够用」掩蓋成假綠。
>
> `tests/poc-clean-clone.bats` 的 `CLEAN-POC-f` 會把**所有提到 oracle 的測試檔**
> （目前即 `tests/v2.1-jev-poc.bats`，100 條）在「無 key／無暖快取／`.env` 已封」的
> CI 等價環境下**整檔**重跑，任何一條回頭依賴真 API 或本機快取都會紅；
> `CLEAN-POC-h` 另鎖「`PoC/.env` 與 `PoC/cache/` 不得被 git 追蹤」，
> `CLEAN-POC-i` 則反向驗證 `JEV_ENV_FILE` seam 真的封得住兩個 .env 來源。
>
> **探針輸出不得外洩密鑰**（TMO-053 / NYH-2）：任何把「被測程式的輸出」寫進 FAIL 訊息或 log 的
> 地方，都要先過共用 helper 的 `mask_secrets`（`tests/helpers/test-env.bash`；其他檔不得自己
> 再定義一份）。靜態鎖 `scripts/ci/lint-probe-secrets.py`（鎖 4）會擋真 `sk-or-v1-` 前綴、擋「碰
> `_load_api_key` 卻整檔沒有遮罩呼叫（註解提到名字不算）」、擋「FAIL 訊息直接展開 `$output` /
> `${output}`」、擋「在共用 helper 以外重新定義 `mask_secrets`」。斷言需要的假字面（例如
> `*"sk-or-v1-"*` 樣式）在該行標 `SECRET-OK: <理由>` 就地豁免。
> 標記是**顯式、可 grep 的人工豁免**，不是自動防濫用——它只擋「標在無關行」與「沒寫理由」，
> 審查時請以掃描器印出的標記總數當錨點。
>
> 本機想驗 CI 等價：`env -u OPENROUTER_API_KEY HOME=/tmp/fakehome JEV_ENV_FILE=/dev/null bats tests/`
> （本機有 key 或 `.env` 會讓依賴 oracle 的探針假綠）。

## Lint

```bash
# markdownlint（與 CI 同一組 glob；本機先 `npm install -g markdownlint-cli2`）
markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"

# shellcheck（Gate 2；-x 讓它跟隨 source；全嚴重度 -S style 需歸零）
# 自我列舉：新增任何 .sh / .bash 都會自動納入，不會漏掃（ENV-EQ-13 鎖住這個性質）
shellcheck -x -S style $(git ls-files '*.sh' '*.bash')

# bash 語法（CI 用 glob 掃全部 9 支）
bash -n skills/dav-wiki/scripts/wiki-cleanup.sh
bash -n skills/dav-wiki/scripts/wiki-cross-ref.sh
for f in skills/dav-wiki/scripts/*.sh; do bash -n "$f"; done

# SKILL.md 行數檢查（≤ 150）
wc -l skills/dav-wiki/SKILL.md
```

### markdownlint 政策（TMO-037 後）

- 上限 **MD013 line_length = 120**（見 `.markdownlint.json`）；表格列、程式碼區塊、標題豁免。
- 清債原則是**改文件**（折行 / 轉義 `\|`），不是**放寬規則**（調大上限、縮小 glob）；動規則會被
  `tests/markdownlint-guard.bats` MLG-3/4/5/8 擋下。
- `.venv/`、`node_modules/` 必排除（見 `.markdownlint-cli2.jsonc`），否則 PoC venv 會灌入假錯誤。
- 表格列內若出現 `\|`、`||`、`a|b` 這類管線，需寫成 `\|`，否則整列會被當成非表格列（MD056 + 連帶 MD013）。

## CI / GitHub Actions

每個 PR 會自動跑（見 `.github/workflows/ci.yml`）：

1. **bats 全套測試**（macOS + Linux；先建 PoC venv、裝 ffmpeg）
2. **markdownlint**（全 repo：`skills/**/*.md`、`docs/**/*.md`、`tests/**/*.md`、`*.md`）
   ——**阻擋式**（TMO-037 清完 270 個錯後已移除 `continue-on-error: true`）；由
   `tests/markdownlint-guard.bats` 鎖住「必須存在、必須會擋、glob 不得縮小」
3. **bash -n** 驗證 CLI 腳本語法
4. **SKILL.md 行數檢查**（≤ 150）
5. **Python heredoc 平衡檢查**
6. **突變測試**（`python3 scripts/ci/mutant-must-die.py`）：把 `scripts/ci/mutants.tsv` 的 58 支
   mutant 在副本上重跑一次（各類分佈見該檔本身——手寫明細會漂，交給 `awk` 自查），
   每支都必須讓對應探針變紅——人工種 mutant 只在「當下那個 commit」
   證明得了探針咬得住，之後把某個 gate 改成恒真不會有人知道；`tests/mutant-must-die.bats`
   鎖住「這一步必須存在、必須跑全表（不得 `--list`／`--only`／`--no-baseline`）、不得被 `if:` 條件停用、不得 OR 短路或 `continue-on-error`」

   **突變的兩種性質（TMO-066 二審後明文化）**：分類不看註解、看**目標檔類型**（機械可判定）：
     - **行為鎖**：目標檔是程式／腳本（`.py`／`.sh`／`.bash`／`.bats`）→ 突變改的是「程式做了什麼」
       （回傳值／分支／旗標），證明「行為變了會被咬到」，死因必須是語意差。
     - **文件／資料契約鎖**：目標檔是 `.md`／`.json` 等 → 探針只斷言檔案文字（例如
       `refute_file_contains`「這個字串不得再出現」）。它證明「文字契約會被抓到」，
       **不是**「行為變了會被抓到」。

   數目用這兩行自查（數字會隨表成長變動，記得同樣用這兩行重查；本行為最近一次查得的值）：

```bash
awk -F'\t' '$1 !~ /^#/ && NF &&  $2 ~ /\.(py|sh|bash|bats)$/' scripts/ci/mutants.tsv | wc -l   # 行為鎖 48
awk -F'\t' '$1 !~ /^#/ && NF && $2 !~ /\.(py|sh|bash|bats)$/' scripts/ci/mutants.tsv | wc -l   # 文件／資料契約鎖 10
```

   另有 `MUTANT(text-lock):` 前綴慣例，只給「目標檔是程式、卻只想鎖文字」的罕見情況用。
   數它要用下面這一行（直接 `grep` 會命中表頭註解段，數出來不為 0）：

```bash
awk -F'\t' '$1 !~ /^#/ && /MUTANT\(text-lock\)/' scripts/ci/mutants.tsv | wc -l   # 目前 0
```

   注意：**沒有「行為鎖」身份就沒有註解豁免權**——「換成」欄若讓目標檔語法壞掉（parse error），
   突變紅了也不算咬住（死因與語意無關），runner 在載入期就會用 `SYNTAX_LANGS` 的語法哨兵擋掉，
   這一類列連 `--list` 都過不了（`tests/mutant-must-die.bats` MMD-6 ⑦ 實測）。

CI badge：見 [README.md](README.md) 頂部。

## 提 PR 流程

1. Fork → 開 feature branch（`feature/xxx` 或 `fix/xxx`）
2. 本機跑 `bats tests/` 確認全綠
3. 本機跑 `markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"` 確認 0 issues
4. 提 PR → CI 自動跑
5. 等待 review

## 程式碼風格

- bash：使用 `while ... case ... shift` 旗標解析模式（見 `skills/dav-wiki/scripts/wiki-cleanup.sh`）
- markdown：遵守 `.markdownlint.json` 規則（MD013=120, MD022/MD032/MD040 等禁用）
- YAML frontmatter：`docs/wiki/` 文件需含 `keywords` 欄位（3-5 個）
- Skill 文件：SKILL.md ≤ 150 行，超出需在附件引用

## 改共用程式碼的兩條規則

### 1. 共用 helper 的守衛行為 → 加參數，不改共用預設

同一支 helper 需要**依呼叫端不同**的守衛行為時（例：`ensure_merged_skill()` 遇到「使用者自有
symlink」時，Claude／Pi 走 repair、Qoder 走 skip-and-warn），正確做法是**加一個明確參數**
（`protect_foreign`），**不是**直接改 helper 的共用預設。

- 理由：共用預設一改，**所有**呼叫端行為同時變，reviewer 與 regression 難以分辨
  「這是預期變更」還是「順手改壞」。
- 新參數的預設值必須**維持舊行為**（如 `${3:-0}`），沒跟著改的呼叫端不受影響。
- 新參數必須有**兩種值各一支探針**：既有預設路徑（回歸）＋ 新路徑（新行為）。
  只測新值＝舊的呼叫端沒人守護。
- 守衛行為（會不會覆寫／刪掉使用者自有內容）最好也**各補一支 mutation row**，
  證明「守衛被拿掉 → 探針會紅」（見上方突變測試段）。

### 2. 會進 oracle payload 的欄位必須跨 process 穩定

任何會進入 oracle payload 的欄位（cache key、request body、hash 輸入）**不得**使用
`hash()`／`random`／時間戳／PID 等 process-randomized 值——`PYTHONHASHSEED` 預設隨機，
`hash()` 每個 process 都不同，會讓 baseline 與重跑的分佈不一致 → 誤判成 regression。

- 要用「亂數感」就改用**跨 process 穩定**的雜湊（如 `hashlib.sha256(step_id).digest()` 取前 N bytes）。
- oracle 的 fixture 必須**版控**（`PoC/cache-fixtures/`），且探針要完全離線：
  `env -u OPENROUTER_API_KEY` ＋ `JEV_CACHE_DIR=<fixture dir>` ＋ `JEV_ENV_FILE=/dev/null`。
- 改了 payload 組法（欄位、順序、雜湊）→ cache key 會變 → **要重錄 fixture**，
  並同步更新 `PoC/cache-fixtures/README.md` 的索引。

## 工具

- `skills/dav-wiki/scripts/wiki-cleanup.sh`：清理 deprecated 文件
- `skills/dav-wiki/scripts/wiki-cross-ref.sh`：交叉引用演算法
- `tools/install.sh`：安裝 agent config

## Sprint / SOP

本專案有一條 SOP（`docs/sop/`），但**不是每個任務都要走**。需要時走：
1. **規劃** (dav-planner)
2. **設計** (dav-designer)
3. **執行** (4 Gate: TDD / lint / regression / reviewer)
4. **反省** (dav-reflection)
5. **提交** (dav-submitter)

Gate 的定義在**各自的 skill**（`tdd-test-writer` / `regression-guard` / `dev-checker-loop` / `dav-reconciler`），
完整說明見 [`docs/sop/handbook/`](docs/sop/handbook/)。`AGENTS.md` 只放行為準則，不含流程。
