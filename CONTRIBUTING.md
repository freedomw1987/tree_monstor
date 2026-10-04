# Contributing to tree_monstor

歡迎貢獻！本文件說明如何在本機開發、跑測試、提 PR。

## 開發環境

### macOS

```bash
# 安裝 bats
brew install bats-core

# 安裝 markdownlint
npm install -g markdownlint-cli2

# 安裝媒體工具（AC-A* / AC-W* / AC-V* 等 26 條 ffmpeg 探針依賴，缺了會紅）
brew install ffmpeg poppler pandoc tesseract

# 確認 python3
python3 --version
```

### Linux (Ubuntu)

```bash
# 安裝 bats 與媒體工具（ffmpeg/ffprobe 是 26 條媒體探針的硬依賴）
sudo apt-get update
sudo apt-get install -y bats ffmpeg poppler-utils pandoc tesseract-ocr

# 安裝 markdownlint
npm install -g markdownlint-cli2
```

## 跑測試

```bash
# 建 PoC venv（httpx + PyYAML；v2.1-jev-poc.bats 的 38 條需要）
bash skills/regression-guard/PoC/setup-venv.sh

# 跑全套 bats tests
bats tests/

# 跑單一測試
bats tests/wiki-cleanup.bats

# 跑邊緣案例
bats tests/wiki-cleanup.bats --filter "E1"
```

> ⚠️ **本機綠 ≠ CI 綠**：CI 是 clean clone，拿不到未版控的檔案。
> 若新增測試素材，必須真的 `git add`（`tests/poc-clean-clone.bats` 會擋）；
> fixture 內也不得寫自己機器的絕對路徑。

## Lint

```bash
# markdownlint
markdownlint-cli2 "skills/dav-wiki/*.md" "docs/sop/handbook/dav-wiki-cleanup.md"

# bash 語法
bash -n skills/dav-wiki/scripts/wiki-cleanup.sh
bash -n skills/dav-wiki/scripts/wiki-cross-ref.sh

# SKILL.md 行數檢查（≤ 150）
wc -l skills/dav-wiki/SKILL.md
```

## CI / GitHub Actions

每個 PR 會自動跑（見 `.github/workflows/ci.yml`）：

1. **bats 全套測試**（macOS + Linux；先建 PoC venv、裝 ffmpeg）
2. **markdownlint**（SKILL.md、cleanup handbook、所有 markdown）
   ——**目前暫時 non-blocking**（`continue-on-error: true`），lint 債 246 處見 TMO-037
3. **bash -n** 驗證 CLI 腳本語法
4. **SKILL.md 行數檢查**（≤ 150）
5. **Python heredoc 平衡檢查**

CI badge：見 [README.md](README.md) 頂部。

## 提 PR 流程

1. Fork → 開 feature branch（`feature/xxx` 或 `fix/xxx`）
2. 本機跑 `bats tests/` 確認全綠
3. 本機跑 `markdownlint-cli2 "skills/dav-wiki/*.md"` 確認 0 issues
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
