#!/usr/bin/env bats
#
# tests/restruct-zero-cross-read.bats
#
# v2.2 zero-tolerance rule for cross-directory "read" references in skills:
# skills must not contain references like "見 docs/...", "讀 docs/...", or
# "讀 other-skill" because skills must be independently movable.
#
# docs/ is allowed as a WRITE destination (project convention).
# But READING from docs/ or other skill directories breaks portability.
#
# TMO-036（2026-10-05）：
#   ① 動詞表原本不含 `grep`，所以 dav-planner Step 1.5 的「先 grep `docs/concepts/`」
#      這種實質跨目錄讀取抓不到 → 動詞表補 `grep` / `讀取` / `查` / `搜` / `掃`。
#   ② 清單原本硬編 9 個 SKILL.md（漏 `skills/ask-me`，且新增 skill 會靜默漏掃）
#      → 改為自動列舉 `skills/**/SKILL.md`；原被排除的 dav-designer 實測乾淨故一併納入。
#   ③ 例外必須「就地自證」：確為**專案端 runtime 路徑**（例：trust mode 的
#      `docs/need-you-help.md`、目標專案的 dav-wiki 知識庫）者，行內需標記「專案端」，
#      不可用探針內部的例外清單（那會變成靜默繞道）。

load 'helpers/test-env'

# 2026-10-05：動詞表（讀取語意）+ 專案端標記
READ_VERBS='(見|詳見|詳閱|參考|讀|讀取|grep|查|搜|掃)'
RUNTIME_MARK='專案端'

# 自動列舉：skills/ 下所有 SKILL.md（不再硬編，避免新增 skill 靜默漏掃）
skill_files() {
  (cd "$REPO_ROOT" && find skills -name 'SKILL.md' | LC_ALL=C sort)
}

@test "ZERO-CROSS-READ: no skill says 'read docs/backlog.md'" {
  while IFS= read -r rel; do
    local abs="$REPO_ROOT/$rel"
    if grep -qE '讀 `?docs/backlog\.md' "$abs"; then
      echo "FAIL: $rel reads docs/backlog.md directly" >&2
      grep -nE '讀 `?docs/backlog\.md' "$abs" >&2
      return 1
    fi
  done < <(skill_files)
}

@test "ZERO-CROSS-READ: no skill says 'see/read/grep docs/...' for cross-file reference" {
  while IFS= read -r rel; do
    local abs="$REPO_ROOT/$rel"
    local hits
    hits=$(grep -nE "$READ_VERBS \`?docs/" "$abs" | grep -v "$RUNTIME_MARK" || true)
    if [ -n "$hits" ]; then
      echo "FAIL: $rel 有跨目錄 docs/ 讀取引用（確為專案端 runtime 路徑者，行內需標記「${RUNTIME_MARK}」）" >&2
      echo "$hits" >&2
      return 1
    fi
  done < <(skill_files)
}

@test "ZERO-CROSS-READ: no skill says 'see other-skill/SKILL.md'" {
  while IFS= read -r rel; do
    local abs="$REPO_ROOT/$rel"
    # Look for cross-skill markdown references: "見 `skills/other-skill/..."
    # Excludes same-dir subfiles (./template.md, ./examples.md)
    if grep -qE '(見|詳見|詳閱|參考) `?skills/' "$abs"; then
      local hits
      hits=$(grep -nE '(見|詳見|詳閱|參考) `?skills/' "$abs" | grep -vE '`\./skills/' || true)
      if [ -n "$hits" ]; then
        echo "FAIL: $rel references other-skill" >&2
        echo "$hits" >&2
        return 1
      fi
    fi
  done < <(skill_files)
}

@test "ZERO-CROSS-READ: no skill says 'read tests/...'" {
  while IFS= read -r rel; do
    local abs="$REPO_ROOT/$rel"
    if grep -qE '(讀|見|詳見) `?tests/' "$abs"; then
      echo "FAIL: $rel references tests/ directory" >&2
      grep -nE '(讀|見|詳見) `?tests/' "$abs" >&2
      return 1
    fi
  done < <(skill_files)
}

@test "ZERO-CROSS-READ: 動詞表抽取器自我測試（TMO-036，禁空過）" {
  # 正向：grep / 讀取 必須被動詞表咬到（否則本檔的 docs/ 規則就是空過）
  printf '%s\n' '先 grep `docs/concepts/`' | grep -qE "$READ_VERBS \`?docs/" || {
    echo "FAIL: 動詞表咬不到「grep docs/」" >&2; return 1; }
  printf '%s\n' '先讀取 `docs/x.md`' | grep -qE "$READ_VERBS \`?docs/" || {
    echo "FAIL: 動詞表咬不到「讀取 docs/」" >&2; return 1; }
  # 負向：docs/ 是合法**寫入**目的地，不可誤咬
  if printf '%s\n' '寫入 `docs/backlog.md`' | grep -qE "$READ_VERBS \`?docs/"; then
    echo "FAIL: 動詞表誤咬「寫入 docs/」" >&2; return 1
  fi
  if printf '%s\n' '輸出到 `docs/deliverable/`' | grep -qE "$READ_VERBS \`?docs/"; then
    echo "FAIL: 動詞表誤咬「輸出到 docs/」" >&2; return 1
  fi
  # 覆蓋：列舉到的檔案數必須 ≥ 11（目前 11 個 skill），且每個都真的存在
  local n=0
  while IFS= read -r rel; do
    n=$((n + 1))
    [ -f "$REPO_ROOT/$rel" ] || { echo "FAIL: 列舉到不存在的 $rel" >&2; return 1; }
  done < <(skill_files)
  [ "$n" -ge 11 ] || {
    echo "FAIL: 只列舉到 $n 個 SKILL.md（< 11）＝掃描覆蓋退化（硬編或列舉壞掉）" >&2; return 1; }
}

@test "ZERO-CROSS-READ: 專案端標記不得濫用（只能貼在 docs/ 讀取引用行）" {
  while IFS= read -r rel; do
    local abs="$REPO_ROOT/$rel"
    local hit
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      if ! printf '%s' "$hit" | grep -qE "$READ_VERBS \`?docs/"; then
        echo "FAIL: $rel 有「${RUNTIME_MARK}」標記，但該行不是 docs/ 讀取引用（標記濫用＝萬用豁免）" >&2
        echo "$hit" >&2
        return 1
      fi
    done < <(grep -n "$RUNTIME_MARK" "$abs" || true)
  done < <(skill_files)
}

@test "ZERO-CROSS-READ: dav-skill-creater documents v2.2 rule" {
  local skill="$REPO_ROOT/skills/dav-skill-creater/SKILL.md"
  # v2.2: should document zero-tolerance for cross-dir read references
  grep -qE "v2\.2|跨.*讀|zero-tolerance|0 容忍" "$skill" || {
    echo "FAIL: dav-skill-creater should document v2.2 cross-read rule" >&2
    return 1
  }
}

@test "ZERO-CROSS-READ: dav-wiki marks [[xxx]] as teaching example (not link)" {
  local skill="$REPO_ROOT/skills/dav-wiki/SKILL.md"
  # dav-wiki has [[xxx]] examples for Obsidian bidirectional linking
  # v2.2: should mark them as teaching examples, not actual links
  # Check that context around [[xxx]] mentions "教學" or "example"
  grep -B1 -A1 '\[\[xxx\]\]' "$skill" | grep -qiE "教學|example|範例" || {
    echo "FAIL: dav-wiki [[xxx]] should be marked as teaching example" >&2
    return 1
  }
}

@test "ZERO-CROSS-READ: 專案端標記不得用來豁免本 repo 自己的 docs（真 runtime 路徑才能豁免）" {
  # round E P2-7：上一條只保證「標記貼在 docs/ 讀取行」，擋不住濫用——
  # 任何 `讀 docs/backlog.md（專案端）` 都會被放行，於是規則被繞過。
  # 這條把「本 repo 自己的 docs 根」列為不可豁免者；`docs/need-you-help.md`、
  # `docs/concepts/`、`docs/wiki/` 這類**目標專案端** runtime 路徑才是合法豁免。
  # round F P2-6：原本硬編 5 個根（漏 trust-log.md / install-reference.md / DESIGN.md /
  # system-design.md…），註解卻自稱「把本 repo 自己的 docs 根列為不可豁免者」＝名實不符。
  # 改為**列舉 `docs/*` 推導**（新 docs 根自動納入），只放行明確的「目標專案端」runtime 路徑。
  # 豁免清單＝下方 case 的單一來源（round G F6：原本另有一個沒人讀的 `allow` 變數，已刪）
  local forbidden='docs/(' parts='' rel esc
  local n=0
  while IFS= read -r rel; do
    case "$rel" in
      need-you-help.md|concepts|wiki|ac) continue ;;   # 目標專案端 runtime 產物，合法豁免
    esac
    esc=$(printf '%s' "$rel" | sed 's/\./\\./g')
    # 目錄（含 `/`）與檔案（`.md`）分開處理：檔案的結尾邊界要容許反引號／空白／括號，
    # 否則 `` `docs/trust-log.md` `` 這種最常見寫法反而抓不到（round F 突變首測就是這樣漏的）。
    case "$rel" in
      */*) parts="$parts$esc/|" ;;
      *.md) parts="$parts$esc([^A-Za-z0-9_.-]|$)|" ;;
      *)   parts="$parts$esc/|" ;;
    esac
    n=$((n + 1))
  done < <(cd "$REPO_ROOT/docs" && ls -1)
  [ "$n" -ge 5 ] || {
    echo "FAIL: 推導出的不可豁免 docs 根只有 $n 個（<5）→ 列舉可能壞了" >&2
    return 1
  }
  forbidden="$forbidden${parts%|})"
  while IFS= read -r rel; do
    local abs="$REPO_ROOT/$rel" hit
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      if printf '%s' "$hit" | grep -qE "$READ_VERBS \`?$forbidden"; then
        echo "FAIL: $rel 用「${RUNTIME_MARK}」豁免了本 repo 自己的 docs 路徑（不可豁免）：" >&2
        echo "$hit" >&2
        return 1
      fi
    done < <(grep -n "$RUNTIME_MARK" "$abs" || true)
  done < <(skill_files)
}
