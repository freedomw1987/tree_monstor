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

# 安裝媒體工具（AC-A* / AC-W* / AC-V* 等 26 條 ffmpeg 探針依賴，缺了會紅）
brew install ffmpeg poppler pandoc tesseract

# ffmpeg 版本底線：>= 5.1（-fps_mode 自 5.1 起取代 -vsync）
#   CI 兩平台實測：ubuntu-latest（apt，6.x）、macos-latest（brew，8.x）
#   檢查方式：bash scripts/ci/check-ffmpeg-version.sh
#     （①比版本底線 ②用本 repo 真的在用的旗標組合實測能力，缺一即 rc=1）
# 移除/改名清單（本 repo 已改用新寫法，勿再引入舊旗標）：
#   -vsync        → 已於 ffmpeg 8 移除，改用 -fps_mode（AC-V11 靜態擋）
#   （下一個移除的旗標無法預期 → 靠 check-ffmpeg-version.sh 的能力實測 +
#     tests/wiki-video-audio.bats 的功能探針一起兜底）

# 確認 python3
python3 --version
```

### Linux (Ubuntu)

```bash
# 安裝媒體工具（ffmpeg/ffprobe 是 26 條媒體探針的硬依賴）
sudo apt-get update
sudo apt-get install -y ffmpeg poppler-utils pandoc tesseract-ocr

# 安裝 bats：同 macOS 的釘版做法（不要用發行版套件，版本會漂移）
git clone --branch v1.14.0 --depth 1 https://github.com/bats-core/bats-core.git
sudo ./bats-core/install.sh /usr/local

# 安裝 markdownlint
npm install -g markdownlint-cli2
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

## 工具

- `skills/dav-wiki/scripts/wiki-cleanup.sh`：清理 deprecated 文件
- `skills/dav-wiki/scripts/wiki-cross-ref.sh`：交叉引用演算法
- `tools/install.sh`：安裝 agent config

## Sprint / SOP

本專案遵循 SOP（`docs/sop/`），每個 Sprint 走：
1. **規劃** (dav-planner)
2. **設計** (dav-designer)
3. **執行** (4 Gate: TDD / lint / regression / reviewer)
4. **反省** (dav-reflection)
5. **提交** (dav-submitter)

詳見 `AGENTS.md` §2 與各 `skills/*/SKILL.md`。
