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
#     skills/dav-wiki/tests/wiki-video-audio.bats 的功能探針一起兜底）

# 確認 python3
python3 --version
# python-pptx：pptx-slim 探針（skills/pptx-slim/tests/pptx-slim.bats 造 fixture、verify G3b 開檔）的硬依賴
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

# python-pptx：pptx-slim 探針（skills/pptx-slim/tests/pptx-slim.bats 造 fixture、verify G3b 開檔）的硬依賴
python3 -m pip install python-pptx
```

## 跑測試

```bash
# 建 PoC venv（httpx + PyYAML；v2.1-jev-poc.bats 的 40 條需要）
bash skills/dav-jev-oracle/PoC/setup-venv.sh
# 重建：--force 會 rm -rf 目標目錄（TMO-040 護欄：危險路徑如 $HOME、/private/tmp、/usr
# 直接拒；自訂 POC_VENV_DIR 且目錄已存在時需輸入目錄名確認，非互動腳本加 --yes）

# 跑全套 bats tests
bats tests/

# 跑單一測試
bats skills/dav-wiki/tests/wiki-cleanup.bats

# 跑邊緣案例
bats skills/dav-wiki/tests/wiki-cleanup.bats --filter "E1"
```

```bash
# 跑突變測試（TMO-065／066）：在 working tree 的**副本**上把 52 支 mutant 逐一種回去，
# 每支都必須讓對應探針變紅（紅＝探針真的咬得住）；working tree 不會被改到（md5 自證）
python3 scripts/ci/mutant-must-die.py
# 只跑幾支（除錯用）：python3 scripts/ci/mutant-must-die.py --only V-M1,IMG-M3
# 改了表內任何目標檔的碼（pptx-slim 腳本、dav-wiki 腳本、dav-developer 的文件／gates.md），
# 就要同步更新 scripts/ci/mutants.tsv：
# 表的「原文」是整行精確比對，錨點對不上會直接 FAIL（不是 skip）；
# 新增防呆／護欄時請補一列 mutant，否則 CI 不會知道你補的東西有沒有被測到。
```

> ⚠️ **本機綠 ≠ CI 綠**（2026-10-27 TMO-084 降級後，呢個差距由「CI 閘」變成「本機閘要自己補齊」）：
> CI 是 clean clone，拿不到未版控的檔案，也**沒有 `OPENROUTER_API_KEY` 與暖快取**。
> 若新增測試素材，必須真的 `git add`（`skills/dav-jev-oracle/tests/poc-clean-clone.bats` 會擋）；
> fixture 內也不得寫自己機器的絕對路徑。
> → CI 而家係偵測器（唔阻你），但呢啲坑會令佢紅：**本機閘要自己守住呢一邊** ——
> 新增素材一定要 `git add`；跑閘前先 `git add -A`（框架體重守門量嘅係 git tracked 檔，
> 未 staged 嘅新檔量唔到 → 提交後守門先轉紅）。
>
> 會呼叫 Jev oracle 的 CLI（`fix_proposal*.py`）必須離線可跑：
> 用版控的 `PoC/fixtures/US-101-run.json` + `PoC/cache-fixtures/` +
> `JEV_CACHE_DIR=<dir>`（詳見 `PoC/cache-fixtures/README.md`）；
> 探針內也要加 `JEV_ENV_FILE=/dev/null`（TMO-045），否則本機 `PoC/.env` 會在
> cache miss 時拿真 key 去打 API，把「fixture 不够用」掩蓋成假綠。
>
> `skills/dav-jev-oracle/tests/poc-clean-clone.bats` 的 `CLEAN-POC-f` 會把**所有提到 oracle 的測試檔**
> （目前即 `skills/dav-jev-oracle/tests/v2.1-jev-poc.bats`，100 條）在「無 key／無暖快取／`.env` 已封」的
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

# 文檔行數限制（v2.11 減法版；由探針 tests/skill-size.bats 機械守）：
#   主檔 ≤50 行／子檔 ≤150 行／單 skill context ≤400 行（example/template/fixture/PoC 檔除外）→ 寫完自己量
git ls-files skills/<name> | grep '\.md$' | grep -viE 'example|template|fixture|poc' | xargs -r cat | wc -l
```

### 文檔行數限制（v2.11 減法版：**機械探針**守 ＋ 規範承擔）

2026-10-27 減法曾把機械守門（`scripts/ci/check-framework-weight.py` ＋ 兩支 bats）刪走，
改由規範承擔 → 實測失效（2026-10-28：11 個 skill **全部**主檔超 50 行、7 支子檔超 150 行）。
2026-10-28 改版：**上限收緊 ＋ 探針返嚟**（`tests/skill-size.bats`，repo 級、逐個 skill 掃）。

| 守乜 | 上限 | 類型 |
|------|------|------|
| **主檔** `SKILL.md` | ≤ 50 行 | 硬上限（過長必拆子檔）|
| **單一支援子檔** | ≤ 150 行 | 硬上限（拆檔或壓成清單）|
| **單 skill context 總量**（主檔 ＋ 支援 .md）| ≤ 400 行 | 硬上限（先減法：去重 → 列表化 → 指標化 → 拆 skill）|

**例外口徑**：支援檔嘅路徑或檔名命中 `example` / `template` / `fixture` / `poc` 者**唔計**
（樣例資料、可填充模板、demo 實作）→ 唔准靠改名喺呢個口徑下逃避上限。

寫完／改完自己量（**量已 commit 嘅檔**；探針 `tests/skill-size.bats` 用 `find`，
連**未 commit** 嘅新檔都計 → 探針嚴過手量法，冇規則漏洞）：

```bash
git ls-files skills/<name> | grep '\.md$' | grep -viE 'example|template|fixture|poc' | xargs -r cat | wc -l
```

**點解要有探針**：50 行上限係「每加一個新 skill 都要守」嘅規則，靠自律會漏 →
探針逐個 skill 目錄掃，**之後新造嘅 skill 自動受約束**。

### markdownlint 政策（TMO-037 後）

- 上限 **MD013 line_length = 120**（見 `.markdownlint.json`）；表格列、程式碼區塊、標題豁免。
- 清債原則是**改文件**（折行 / 轉義 `\|`），不是**放寬規則**（調大上限、縮小 glob）；動規則會被
  `tests/markdownlint-guard.bats` MLG-3/4/5/8 擋下。
- `.venv/`、`node_modules/` 必排除（見 `.markdownlint-cli2.jsonc`），否則 PoC venv 會灌入假錯誤。
- 表格列內若出現 `\|`、`||`、`a|b` 這類管線，需寫成 `\|`，否則整列會被當成非表格列（MD056 + 連帶 MD013）。

## 術語（用同一套詞語）

本專案嘅專屬術語以 [`docs/glossary_list.md`](docs/glossary_list.md) 為準，三條規則：

1. 新寫嘅文件／對話用**「術語」欄**嘅寫法（英文 key ＋ 中文對照）
2. **唔好用「勿用寫法」清單**入面嘅講法（會指錯嘢嗰啲）；「同義寫法」欄只係俾你理解同一件事
3. 發現新術語 → **A-Z 插入同一張表**（唔好各自發明叫法）

## 完成條件（閘）

> **TMO-084 決策（2026-10-27，用戶）**：CI **降級為「偵測器」**，唔再係完成條件。

| 嘢 | 定位 | 阻唔阻你 |
|-----|------|---------|
| **本機探針**（`bats tests/` ＋ skill-local ＋ mutant 全死） | **閘** | ✅ 紅就唔算完成 |
| **本機 lint**（markdownlint / shellcheck / bash -n / heredoc / 文件漂移） | **閘** | ✅ 紅就唔算完成 |
| **改規範自查行數上限**（V03：主檔 ≤50 行／子檔 ≤150 行／context ≤400 行；代碼改動嘅品質把關走對應 skill 嘅 Gate） | **閘** | ✅ 未過唔算完成 |
| **CI（GitHub Actions）** | **偵測器** | ❌ 唔阻 merge、唔係完成條件 |

**點解**：本 repo 係**平時自用嘅技能庫**，唔係要出貨嘅產品 → 唔需要另一部機做發佈閘。

**開發 loop → 用 `--changed`（快 6–10 倍）**；**push 前 → 跑全量**：

```bash
# 開發中（改完即跑）：只驗受改動影響嘅探針 ＋ 受影響嘅 mutant 列（≈ 20–40 秒）
bash scripts/check-all.sh --changed
bash scripts/check-all.sh --changed=origin/master   # 同遠端比（PR 前用）

# push 前（最後一道閘）：全量 11 步（≈ 4 分鐘）
bash scripts/check-all.sh
```

> `--changed` 會明講邊步驟跳過同點解跳（唔會靜靜哋當通過）；base 打錯 → rc=2、冇改動 → rc=1（fail-closed）。
> **注意**：`--changed` **唔等於全量閘通過** → 報告交付時要講明驗過嘅範圍。

**本機 pre-push 閘**（可選；裝一次就長期生效，push 前自動跑**全量**嗰條 `bash scripts/check-all.sh`）：

```bash
bash scripts/install-local-hooks.sh       # 安裝
SKIP_LOCAL_CI=1 git push                   # 一次性繞過（CI 仍然會跑）
bash scripts/install-local-hooks.sh --uninstall
```

> 本機閘嘅守門探針：`tests/local-ci-guard.bats`（LC-1..LC-8）—— 佢會**按 step 名**雙向對齊 `ci.yml` 同本機
> runner（CI 有嘅 step 本機冇 → 紅；本機有嘅 CI 冇 → 紅），並用 mutant `LC-M1` 證明「有步驟失敗時整體一定紅」。
> ⚠️ 對齊只及於 step **名**同 markdownlint glob／doc-drift `--from-date`（由 ci.yml 抽），**唔及於 step body**。

## 測試喺邊、點跑（2026-10-27 探針 skill-local 化）

| 位置 | 內容 | 幾時跑 |
|---|---|---|
| `tests/*.bats` | **repo 級**測試（install.sh、本機閘、等價性、mutant harness、secret 遮罩⋯⋯）| 改 repo 級嘢時 |
| `skills/<name>/tests/*.bats` | **每個 skill 自己**嘅測試（跟 skill 搬；共用 repo 級 `tests/helpers/test-env.bash` → **離開 repo 就跑唔到**，唔係獨立套件）| 改**個別 skill** 時 |

```bash
# 改一個 skill → 只跑嗰個 skill（唔使等成 repo 套件）
bash scripts/test-skill.sh dav-developer
bash scripts/test-skill.sh dav-wiki pptx-slim     # 可以一次過幾個
bash scripts/test-skill.sh --list                 # 列有測試嘅 skill

# 或者直接用 bats（同一件事）
bats skills/dav-jev-oracle/tests/

# 全套（repo 級 ＋ 所有 skill 級）
bash scripts/check-all.sh
```

> 搬動探針時注意：`skills/<name>/tests/` 嘅探針**唔可以用** `load 'helpers/test-env'`
> （相對路徑相對 `BATS_TEST_DIRNAME`，搬咗 skill 就搵唔到）→ 用絕對路徑：
> `REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"; load "$REPO_ROOT/tests/helpers/test-env"`。

## dav-developer 嘅 CI：本機跑（唔喺 GitHub）

> **2026-10-27 用戶決策**：「dav-developer 的 ci 在本地跑都得，不用在 github 上跑」
> → 原本嘅 GitHub Actions workflow **已刪除**（探針 `CI-f` 鎖住唔准加返）。

```bash
bash skills/dav-jev-oracle/PoC/run_ci.sh list          # 列 subcommand
bash skills/dav-jev-oracle/PoC/run_ci.sh probes       # 跑探針（唔使 API key）
OPENROUTER_API_KEY=sk-or-v1-... bash skills/dav-jev-oracle/PoC/run_ci.sh pipeline US-101
bash skills/dav-jev-oracle/PoC/run_ci.sh matrix        # 預設 US-101 / US-M62 / US-M63
bash skills/dav-jev-oracle/PoC/run_ci.sh cleanup-scan  # 文件減法盤點
bash skills/dav-jev-oracle/PoC/run_ci.sh all           # probes → matrix → cleanup-scan
```

**Return code**：`0` 綠｜`2` 黃（警告）｜`1` 紅（擋）｜`3` 用法／環境錯誤。
詳見 [`docs/ci/dav-jev-oracle.md`](docs/ci/dav-jev-oracle.md)。

## CI / GitHub Actions（偵測器，唔係閘）

> **定位（TMO-084，2026-10-27）**：CI 係**跨環境偵測器**，唔係完成條件；亦**刻意唔開** branch protection
> （即係 CI 紅都 merge 得 —— 呢個係**有意識**嘅選擇，唔係「未設定」）。
> 佢仲有價值嘅唯一原因：CI 係**另一部機**（clean clone、雙 OS、乾淨依賴、冇 API key、冇暖快取）——
> 呢啲係你部機**結構上**捉唔到嘅。已知真實案例（2026-10-05 CI 首跑）：shellcheck apt 0.9 vs 本機 0.11
> 嘅 SC2002 差異、macOS runner bash 3.2 令 31 條測試被靜默丟棄、clean clone 缺未版控 fixture 令 34 條紅、
> ffmpeg 8 移除 `-vsync`。
> → **CI 紅唔一定係你做錯**（多數係環境差異），但值得望一眼；真 bug 就要修。

每個 PR 會自動跑（見 `.github/workflows/ci.yml`）：

1. **bats 測試**（macOS + Linux；先建 PoC venv、裝 ffmpeg）：repo 級 `tests/` ＋ 各 skill 自帶 `skills/*/tests/`
2. **markdownlint**（全 repo：`skills/**/*.md`、`docs/**/*.md`、`tests/**/*.md`、`*.md`）
   ——**阻擋式**（TMO-037 清完 270 個錯後已移除 `continue-on-error: true`）
3. **bash -n** 驗證 CLI 腳本語法
4. **Python heredoc 平衡檢查**
5. **文件漂移檢查**（D1–D8；`bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26`）
6. **突變測試**（`python3 scripts/ci/mutant-must-die.py`）：把 `scripts/ci/mutants.tsv` 的 52 支
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
awk -F'\t' '$1 !~ /^#/ && NF &&  $2 ~ /\.(py|sh|bash|bats)$/' scripts/ci/mutants.tsv | wc -l   # 行為鎖 49
awk -F'\t' '$1 !~ /^#/ && NF && $2 !~ /\.(py|sh|bash|bats)$/' scripts/ci/mutants.tsv | wc -l   # 文件／資料契約鎖 3
```

   另有 `MUTANT(text-lock):` 前綴慣例，只給「目標檔是程式、卻只想鎖文字」的罕見情況用。
   數它要用下面這一行（直接 `grep` 會命中表頭註解段，數出來不為 0）：

```bash
awk -F'\t' '$1 !~ /^#/ && /MUTANT\(text-lock\)/' scripts/ci/mutants.tsv | wc -l   # 目前 0
```

   注意：**沒有「行為鎖」身份就沒有註解豁免權**——「換成」欄若讓目標檔語法壞掉（parse error），
   突變紅了也不算咬住（死因與語意無關），runner 在載入期就會用 `SYNTAX_LANGS` 的語法哨兵擋掉，
   這一類列連 `--list` 都過不了（`tests/mutant-must-die.bats` MMD-6 ⑦ 實測）。

CI badge：見 [README.md](README.md) 頂部。badge 仍然反映真實狀態（紅就係紅），但唔代表你未完成工作 ——
閘喺本機（見上面「完成條件（閘）」）。

## 提 PR 流程

> TMO-084 之後：**閘喺本機**，CI 係輔助偵測（見上面「完成條件（閘）」）。

1. Fork → 開 feature branch（`feature/xxx` 或 `fix/xxx`）
2. 本機跑 `bash scripts/check-all.sh` 確認全綠（≈ 5 分鐘；一條指令跑齊探針 ＋ lint ＋ mutant）
3. 提 PR → CI 自動跑（**唔阻你**：冇 branch protection，CI 紅都 merge 得；值得望一眼）
4. 等待 review

## 程式碼風格

- bash：使用 `while ... case ... shift` 旗標解析模式（見 `skills/dav-wiki/scripts/wiki-cleanup.sh`）
- markdown：遵守 `.markdownlint.json` 規則（MD013=120, MD022/MD032/MD040 等禁用）
- YAML frontmatter：`docs/wiki/` 文件需含 `keywords` 欄位（3-5 個）
- Skill 文件：SKILL.md ≤ 50 行、支援子檔 ≤ 150 行、單 skill context ≤ 400 行（上限見上面表格 ＋ `editor-guide.md`）

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
- 守衛行為（會不會覆寫／刪掉使用者自有內容）最好也**各補一支 mutant row**，
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

## 批次 / SOP

本專案有一條 SOP（**規則本體喺各自承載它嘅 skill**），但**不是每個任務都要走**。需要時走：
1. **規劃** (dav-planner)
2. **設計** (dav-designer)
3. **執行** (3 Gate: TDD / lint / regression；`dav-developer`，自動段)
4. **審核 ＋ 反省 ＋ 提交** (`dav-reviewer`：**人手觸發** —— Gate 4 品質審核 ＋ Gate 4.5 需求對帳 → 交付摘要 ＋ 六維度反省 → 更新受影響文檔同 `docs/backlog.md`)

Gate 的定義在**各自的 skill**（Gate 1/2/3 → `dav-developer`、Gate 4 → `dav-reviewer`〔人手觸發〕），
就係唯一本（`skills/dav-developer/gates.md`、`skills/dav-reviewer/gates.md`）；
任務分流 ＋ 違規防線喺 `dav-router` skill；`AGENTS.md` 只放行為準則（§1 ＋ §1.5），唔含流程細節。
