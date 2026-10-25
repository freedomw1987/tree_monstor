#!/usr/bin/env bats
#
# tests/agents-md.bats
#
# Black-box tests for tree_monstor/AGENTS.md and SOUL.md consistency.
# Ensures pi will actually load the soul principles at startup
# (since pi does NOT read SOUL.md — see pi docs/usage.md:100).

setup() {
  load 'helpers/test-env'
  REPO_AGENTS="$REPO_ROOT/AGENTS.md"
  REPO_SOUL="$REPO_ROOT/SOUL.md"
}

# ---------- All SOUL bullets must be inlined into AGENTS.md ----------
@test "SOUL-1: every SOUL.md bullet appears verbatim in AGENTS.md" {
  while IFS= read -r bullet; do
    [[ -z "$bullet" ]] && continue
    grep -F -q -- "$bullet" "$REPO_AGENTS" || {
      echo "FAIL: missing bullet in AGENTS.md: $bullet" >&2
      return 1
    }
  done < <(grep -E '^- ' "$REPO_SOUL")
}

@test "SOUL-2: AGENTS.md does not reference [[SOUL]] (Obsidian-only syntax)" {
  ! grep -q '\[\[SOUL' "$REPO_AGENTS"
}

@test "SOUL-3: AGENTS.md has the same bullet count in the principles section as SOUL.md" {
  soul_count=$(grep -cE '^- ' "$REPO_SOUL")
  # 只數「§1 萬事原則」那一段：到下一個 `## ` 標題為止（不綁特定下一節名稱，改節名不會壞）
  agents_count=$(awk '/^## §1 萬事原則/{flag=1; next} /^## /{flag=0} flag' "$REPO_AGENTS" | grep -cE '^- ')
  # 防空過：兩邊都要數到東西才比（段落被刪或改名 → 0 → 紅）
  [ "$soul_count" -gt 0 ] || { echo "FAIL: SOUL.md 讀不到原則 bullet" >&2; return 1; }
  [ "$agents_count" -gt 0 ] || {
    echo "FAIL: AGENTS.md 找不到 §1 萬事原則 段落（或段落內沒有 bullet）" >&2
    return 1
  }
  [ "$soul_count" -eq "$agents_count" ] || {
    echo "FAIL: SOUL.md 有 $soul_count 條、AGENTS.md §1 有 $agents_count 條" >&2
    return 1
  }
}

@test "SOUL-4: AGENTS.md explicitly notes that pi does not read SOUL.md" {
  # v2.0 may say "pi / Claude Code 不會讀" (broader phrasing)
  grep -F -q "不會讀" "$REPO_AGENTS"
}

# ---------- Skill references must use pi-recognised /skill:name form ----------
# pi does not parse Obsidian wiki-link syntax [[skills/...]]. See
# pi docs/skills.md#skill-commands: skills are invoked via /skill:name.
@test "SKILL-REF-1: AGENTS.md does not use Obsidian [[skills/...]] syntax" {
  ! grep -qE '\[\[skills/' "$REPO_AGENTS"
}

@test "SKILL-REF-2: every /skill:<name> reference in AGENTS.md / SOUL.md / handbook / skills resolves" {
  # 舊版只掃 AGENTS.md 的「務必使用」行。2026-10-26 起 AGENTS.md 不再路由 skill
  # → 那個迴圈會變成 0 次迭代的**空過**（永遠綠）。改成掃全 repo 的文件面：
  # 任何 /skill:<name> 都必須指向真的存在的 skill（防打字錯誤、防改名漏改）。
  local installed hits n=0 f name
  installed=$(ls "$REPO_ROOT/skills")
  hits=$(grep -rhoE '/skill:[a-z][a-z0-9-]*' \
    "$REPO_AGENTS" "$REPO_SOUL" \
    "$REPO_ROOT"/docs/sop/handbook/*.md \
    "$REPO_ROOT"/skills/*/SKILL.md 2>/dev/null | sort -u)
  [ -n "$hits" ] || {
    echo "FAIL: 全 repo 找不到任何 /skill: 引用（列舉壞了或檔案被搬走）→ 不得空過" >&2
    return 1
  }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    name="${f#/skill:}"
    n=$((n + 1))
    grep -Fxq "$name" <<< "$installed" || {
      echo "FAIL: 引用了不存在的 skill：$f" >&2
      return 1
    }
  done <<< "$hits"
  [ "$n" -ge 1 ] || { echo "FAIL: 沒有驗到任何 /skill: 引用（空過）" >&2; return 1; }
}

# ---------- TD-017: AGENTS.md slimmed down + handbook exists ----------

@test "TD-017 AC-1: AGENTS.md stays slim (under 60 lines)" {
  # 2026-10-26：AGENTS.md 只留「你是誰 + 萬事原則」（35 行）。上限收到 60 是回歸守護：
  # 一旦有人把 SOP / Gate 表 / handbook 索引貼回來，這條會先紅。
  local line_count
  line_count=$(wc -l < "$REPO_AGENTS")
  [ "$line_count" -lt 60 ] || {
    echo "FAIL: AGENTS.md 有 $line_count 行（上限 60）→ SOP 表是不是又被貼回來了？" >&2
    return 1
  }
  echo "OK: AGENTS.md has $line_count lines"
}

@test "TD-017 AC-2: AGENTS.md no longer embeds the SOP/Gate table (gates live in their skills)" {
  # 2026-10-26：AGENTS.md 只留「你是誰 + 萬事原則」；Gate 定義改由各自的 skill 承載
  # （見 tests/gate-in-skill.bats）。本條是回歸守護 —— 不要把整張 SOP 表再貼回來。
  # 正向斷言（不可只有負向）：AGENTS.md 必須指名 Gate 的擁有者，否則讀者無從得知去哪找。
  local s
  for s in tdd-test-writer regression-guard dev-checker-loop dav-reconciler; do
    grep -qF -- "$s" "$REPO_AGENTS" || {
      echo "FAIL: AGENTS.md 沒指名 Gate 的擁有者 skill：$s" >&2
      return 1
    }
  done
  if grep -qE 'mandatory_phrase|pass_criteria|docs/sop/handbook/2\.[0-9]' "$REPO_AGENTS"; then
    echo "FAIL: AGENTS.md 又內嵌了 SOP/Gate 表或 handbook 章節索引（定義應留在 skill）" >&2
    grep -nE 'mandatory_phrase|pass_criteria|docs/sop/handbook/2\.[0-9]' "$REPO_AGENTS" >&2
    return 1
  fi
}

@test "TD-017 AC-3: every handbook chapter file exists and is non-empty" {
  local files=(
    "docs/sop/handbook/2.1-planning.md"
    "docs/sop/handbook/2.2-design.md"
    "docs/sop/handbook/2.3-execution.md"
    "docs/sop/handbook/2.4-reflection.md"
    "docs/sop/handbook/2.5-submission.md"
    "docs/sop/handbook/2.6-general-task.md"
    "docs/sop/handbook/2.7-violations.md"
    "docs/sop/handbook/changelog.md"
  )
  for path in "${files[@]}"; do
    [ -f "$REPO_ROOT/$path" ] || { echo "FAIL: missing file $path"; return 1; }
    [ -s "$REPO_ROOT/$path" ] || { echo "FAIL: empty file $path"; return 1; }
  done
}

# ---------- TD-018 follow-up: handbook link paths match installed locations ----------

@test "TD-018 AC-6: AGENTS.md is self-contained (no dependency on installed handbook paths)" {
  # 舊版要求 AGENTS.md 同時連結 ~/.pi/sop/handbook 與 ~/.claude/sop/handbook。
  # 2026-10-26 起 AGENTS.md 不再內嵌 SOP → 它必須**自足**：讀到它就懂行為準則，
  # 不必先找到安裝後的 handbook。負向斷言搭配正向，避免恆真。
  if grep -qE '/\.pi/sop|\.claude/sop' "$REPO_AGENTS"; then
    echo "FAIL: AGENTS.md 仍依賴安裝後的 handbook 路徑（應自足）" >&2
    return 1
  fi
  grep -qF "## §1 萬事原則" "$REPO_AGENTS" || {
    echo "FAIL: AGENTS.md 缺 §1 萬事原則（自足性正向斷言失敗）" >&2
    return 1
  }
  local bullets
  bullets=$(awk '/^## §1 萬事原則/{flag=1; next} /^## /{flag=0} flag' "$REPO_AGENTS" | grep -cE '^- ')
  [ "$bullets" -ge 7 ] || {
    echo "FAIL: AGENTS.md §1 的原則 bullet 只有 $bullets 條（< 7）" >&2
    return 1
  }
}

# ---------- TD-017 AC-4: live docs must not route to the removed AGENTS.md §2 ----------

# 為什麼要有這條：改動當下的自證指令是 `grep -rn "AGENTS\.md §2"`，但它命不中兩種常見寫法 ——
#   ① CONTRIBUTING 型：`` `AGENTS.md` §2 ``（反引號夾在中間，或中間夾少量字）
#   ② README 型：**標題**寫「## 工作流程：看 AGENTS.md」，底下的表格列寫「§2.0 任務分類」——
#      整列根本沒有 `AGENTS.md` 字串，逐行 grep 永遠命不中。
# 所以掃描做兩種檢查：① 同行寬鬆 pattern；② **區段式**（標題點名 AGENTS.md → 該區段內任何 `§2` 皆違規）。
# 用 python 統一處理（絕對路徑、UTF-8、區段狀態、每個 glob 家族各自非空斷言）。
_ac4_scan() {
  python3 - "$1" "${2:-15}" <<'PYEOF'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
min_files = int(sys.argv[2]) if len(sys.argv) > 2 else 15

fixed = ["README.md", "CONTRIBUTING.md", "AGENTS.md", "SOUL.md",
         "docs/system-design.md", "docs/DESIGN.md", "docs/install-reference.md"]
files = [root / f for f in fixed if (root / f).is_file()]

# 每個 glob 家族都要**各自**非空斷言：否則某個家族悄悄不匹配時，
# 彙總計數（len(files) >= min_files）仍會過 → 那是「掃不到就空過」。
families = ("docs/*.md", "docs/ci/*.md", "docs/prd/*.md", "docs/sop/handbook/2.*.md",
            "skills/*/SKILL.md", "skills/*/*.md", "skills/*/*/*.md",
            "docs/ac/*.md", "docs/ac/*.html", "docs/reconcile/*.md", "docs/req/*.md")
for pat in families:
    matched = sorted(root.glob(pat))
    if not matched and min_files >= 15:          # fixture 模式（min_files=1）不做家族斷言
        print(f"FAIL: glob「{pat}」比對到 0 個檔案 → 該家族悄悄不匹配（彙總計數不會發現）")
        sys.exit(1)
    files += matched

# 排除清單與理由：
#   - CHANGELOG.md / changelog.md / docs/backlog.md / docs/deliverable/ 都是**歷史體裁**
#     （append-only 記錄，刻意保留當時寫法），不是 live 規範
#   - tests/（含 tests/fixtures/mock-tree-monstor/**，那棵樹是 install 素材、刻意不與真實結構同步）
#     與 install.sh 不收：它們是程式碼／fixture，註解必然要引述「本探針在守哪一段」
# docs/backlog.md 是歷史記錄（主題欄刻意保留當時寫法），不是 live 規範。
files = [f for f in files
         if f.name not in ("CHANGELOG.md", "changelog.md", "backlog.md")
         and "docs/deliverable" not in f.as_posix()]
files = sorted(set(files))

if len(files) < min_files:
    print(f"FAIL: 只列舉到 {len(files)} 個檔案（< {min_files}）→ 掃描覆蓋退化，不得空過")
    sys.exit(1)

# 同行：AGENTS.md 與 §2 之間容許反引號／空白／少量夾字（例「見 `AGENTS.md` 的 §2 流程」）
SAME_LINE = re.compile(r"AGENTS\.md[^\n§]{0,12}§2")
# 反向寫法（「§2 流程請見 AGENTS.md」）——只驗單向會漏。
# 必須綁讀取動詞，否則「§2 的 live 引用 … 已實作 `AGENTS.md`」這類正當敘述會誤判。
REV_LINE = re.compile(r"(見|詳見|詳閱|參考|讀|讀取|查|搜|掃)[^\n]{0,10}§2[^\n]{0,24}AGENTS\.md")
SEC_ANY2 = re.compile(r"§2")
HISTORY_HEADING = re.compile(r"變動歷史|歷史版本")
# 明確標示「已移除／已搬走／當時值」的行視為歷史註記，不算 live 斷鏈。
# 注意：`已於` 必須與 `移除` 同列才算（單寫「已於」會把真違規放行）。
ANNOTATED = re.compile(r"已移除|已歸檔|已作廢|起改由|當時值|已於.{0,24}移除|~~")

viol = []
for f in files:
    rel = f.relative_to(root)
    try:
        lines = f.read_text(encoding="utf-8", errors="replace").split("\n")
    except OSError:
        continue
    sec_names_agents = False
    in_history = False
    for i, ln in enumerate(lines, 1):
        # 任何層級標題都重算旗標 —— 否則 `### Q: 改了 AGENTS.md` 之類的子標題
        # 會把旗標一路帶到同一條 `## ` 段落結束，讓後續正當的 §2 引用被誤判
        if ln.startswith("#"):
            sec_names_agents = "AGENTS.md" in ln
            # 「變動歷史」段落內是**歷史表格列**（記錄當時寫法），不是 live 規範
            in_history = bool(HISTORY_HEADING.search(ln))
        if in_history:
            continue
        if ANNOTATED.search(ln):
            continue
        if SAME_LINE.search(ln) or REV_LINE.search(ln):
            viol.append(f"{rel}:{i}: {ln.strip()[:90]}")
        elif sec_names_agents and SEC_ANY2.search(ln):
            viol.append(f"{rel}:{i}: [區段標題含 AGENTS.md] {ln.strip()[:90]}")

if viol:
    print(f"FAIL: {len(viol)} 處 live 文件仍把讀者導向已移除的 AGENTS.md SOP 段：")
    for v in viol:
        print("  -", v)
    sys.exit(1)
print(f"OK: 掃過 {len(files)} 個 live 文件，無任何指向已移除 SOP 段的引用")
PYEOF
}

@test "TD-017 AC-4: no live doc still routes readers to the removed AGENTS.md SOP section" {
  run _ac4_scan "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"OK:"* ]] || {
    echo "FAIL: 預期 OK 訊息，實際：$output" >&2
    return 1
  }
}

@test "TD-017 AC-4b: the AC-4 scanner itself bites (same-line, section, and annotated cases)" {
  # 對照 GATE-SKILL-3：新守護要有**內建 fixture 自證**，否則「掃不到就空過」沒人發現。
  local tmp="$BATS_TEST_TMPDIR/ac4"
  mkdir -p "$tmp"
  printf '# t\n\n## Clean\n\nNothing to see here.\n' > "$tmp/README.md"
  run _ac4_scan "$tmp" 1
  [ "$status" -eq 0 ] || { echo "FAIL: 乾淨 fixture 竟紅（偵測器假咬）：$output" >&2; return 1; }

  # 型①：同行（AGENTS.md 與 §2 中間夾字）
  printf '# t\n\n見 `AGENTS.md` 的 §2 流程。\n' > "$tmp/README.md"
  run _ac4_scan "$tmp" 1
  [ "$status" -ne 0 ] || { echo "FAIL: 同行型違規竟通過" >&2; return 1; }

  # 型②：區段式（標題點名 AGENTS.md，表格列只寫 §2.0）
  printf '# t\n\n## 工作流程：看 AGENTS.md\n\n| 章節 | 內容 |\n|---|---|\n| §2.0 任務分類 | x |\n' > "$tmp/README.md"
  run _ac4_scan "$tmp" 1
  [ "$status" -ne 0 ] || { echo "FAIL: 區段型違規竟通過" >&2; return 1; }

  # 型②b：### 標題點名也算
  printf '# t\n\n### 看 AGENTS.md\n\n§2.1 說明\n' > "$tmp/README.md"
  run _ac4_scan "$tmp" 1
  [ "$status" -ne 0 ] || { echo "FAIL: ### 標題型違規竟通過" >&2; return 1; }

  # 型③：已明確標註移除 → 必須放行（否則歷史註記全部變紅）
  printf '# t\n\n見 `AGENTS.md` §2（已於 2026-10-26 移除）。\n' > "$tmp/README.md"
  run _ac4_scan "$tmp" 1
  [ "$status" -eq 0 ] || { echo "FAIL: 已標註移除的行竟紅（假咬）：$output" >&2; return 1; }

  # 型④：只寫「已於」但沒有「移除」→ 不得被豁免（排除式不可過寬）
  printf '# t\n\nSOP 已於 `AGENTS.md` §2 說明。\n' > "$tmp/README.md"
  run _ac4_scan "$tmp" 1
  [ "$status" -ne 0 ] || { echo "FAIL: 「已於…說明」未被擋（排除式過寬）" >&2; return 1; }

  # 型⑤：`min_files=15` 時，某個 glob 家族比對到 0 檔 → 必須紅
  #   （否則「每個家族各自非空」這條防空過守護自己沒有守護）
  local big="$BATS_TEST_TMPDIR/ac4_families"
  mkdir -p "$big/docs"
  printf '# t\n\n## Clean\n' > "$big/README.md"
  run _ac4_scan "$big" 15
  [ "$status" -ne 0 ] || { echo "FAIL: 家族為空竟通過（防空過守護未自證）" >&2; return 1; }
  [[ "$output" == *"比對到 0 個檔案"* ]] || {
    echo "FAIL: 應報「glob … 比對到 0 個檔案」：$output" >&2
    return 1
  }
}
