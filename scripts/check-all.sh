#!/usr/bin/env bash
# scripts/check-all.sh — 本機 CI 等價 runner（TMO-084）
#
# 做咩：把 `.github/workflows/ci.yml` 嘅檢查步驟喺本機跑一次，令 push 前就知結果，
#        唔使事後等 5–7 分鐘睇 GitHub Actions。（TMO-084 之後 CI 係偵測器、唔係閘。）
# 背景：本 repo 嘅「本機綠 ≠ CI 綠」係已知嘅坑（CI 係 clean clone、雙 OS、乾淨依賴、冇 API key、
#        冇暖快存；真實案例：shellcheck 0.11 vs 0.9 嘅 SC2002 差異、macOS runner bash 3.2 令 31 條
#        測試被靜默丟棄）→ 本機 runner 係「提早揭盲」，**取代唔到** CI。
#
# 設計重點（守門探針 `tests/local-ci-guard.bats` 鎖住）：
#   ① 單一真相來源：ci.yml 嘅 markdownlint glob、doc-drift `--from-date` 全部**執行時由 ci.yml 抽**
#      （唔硬編）→ ci.yml 改咗，本機自動跟。
#   ② 雙向對齊：每個本機步驟都帶 ci-ref（ci.yml 對應 step 名），探針雙向比對（CI 有本機冇／反之 → 紅）。
#   ③ fail-closed：任何一步失敗 → 整體非 0 退出。全檔冇 fail-open 寫法。
#   ④ 機械可比對：`--list`（步驟清單）同 `--plan`（解析後嘅實際指令）畀探針直接比。
#
# 用法：bash scripts/check-all.sh [--only <id>] [--keep-going] [--changed[=<base>]] [--list] [--plan]
#   --changed[**<base>**]：**只跑受改動影響**嘅探針（git diff <base> + 未追蹤檔 → 相關 skill 嘅
#              probe 檔 ＋ 目標檔被改過嘅 mutant 列）。開發 loop 用（4 分鐘 → ~20-40 秒）；
#              `--changed origin/master` = 同遠端比（PR 前用）。
#              push 前照樣可以跑全量（唔加 --changed）。skip 嘅步驟會明講「點解跳」，
#              唔會靜靜哋當通過（fail-closed 語義不變）。
# 退出碼：0 = 全部通過；1 = 有步驟失敗；2 = 用法／環境錯誤
# ⚠️ 自我測試 seam：`LOCAL_CI_SELF_TEST_FAIL=<step_id>` 會**強制**嗰一步失敗。佢係**只會令嘢變紅**
#    嘅 seam（冇辦法令嘢變綠）→ 用嚟證明「有步驟失敗時整體一定紅」（探針 LC-8 靠佢做行為自證）。

set -euo pipefail

if ! REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "FAIL: 唔喺 git repo 入面（git rev-parse --show-toplevel 失敗）" >&2
  exit 2
fi
[ -n "$REPO_ROOT" ] || { echo "FAIL: git rev-parse --show-toplevel 回傳空字串" >&2; exit 2; }
cd "$REPO_ROOT"

CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
die2() { echo "FAIL: $*" >&2; exit 2; }

# ── 由 ci.yml 抽參數（單一真相來源）────────────────────────────────────
# （step 名嘅雙向對齊由守門探針做，唔喺呢度做 → 避免同一件事兩份實作）
[ -f "$CI_YML" ] || die2 "搵唔到 $CI_YML"

# ⚠️ 抽取條件要夠精準：`markdownlint-cli2` 呢個字串喺 ci.yml **第一個**出現嘅地方係
#    `npm install -g markdownlint-cli2`（安裝行，冇 glob）→ 用 head -1 會抽錯行 → glob 抽唔到。
#    所以要求「同一行、命令後面即刻有引號括住嘅 glob」。
MD_LINE="$(grep -E 'markdownlint-cli2[[:space:]]+".*"' "$CI_YML" | head -1)"
[ -n "$MD_LINE" ] || die2 "由 ci.yml 抽唔到 markdownlint-cli2 嘅執行行（格式變咗？→ 更新本腳本）"
MD_GLOBS=""
while IFS= read -r g; do
  [ -n "$g" ] || continue
  MD_GLOBS="$MD_GLOBS \"$g\""
done <<EOF
$(printf '%s\n' "$MD_LINE" | grep -oE '"[^"]+"' | tr -d '"')
EOF
[ -n "$MD_GLOBS" ] || die2 "由 ci.yml 抽唔到 markdownlint 嘅 glob"

DRIFT_LINE="$(grep -F 'check-doc-drift.sh' "$CI_YML" | head -1)"
[ -n "$DRIFT_LINE" ] || die2 "由 ci.yml 抽唔到 check-doc-drift.sh 嘅執行行"
DRIFT_FROM_DATE="$(printf '%s\n' "$DRIFT_LINE" \
  | grep -oE -- '--from-date[[:space:]]+[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 | awk '{print $2}')"
[ -n "$DRIFT_FROM_DATE" ] || die2 "由 ci.yml 抽唔到 doc-drift 嘅 --from-date"

# ── 步驟定義 ───────────────────────────────────────────────────────────
# 順序＝**便宜 → 昂貴**（fail-fast 時唔好為咗一個 0.1 秒嘅紅等 3 分鐘）。
# ci-ref ＝ ci.yml 對應嘅 step 名（多個用 | 分隔）；本機可能以「等價檢查」代替「安裝」
# （依賴只驗在不在，唔重裝）——刻意為之，守門探針 LC-5 雙向比對時以此為準。
STEPS=(deps ffmpeg shellcheck bashn heredoc drift mdlint venv bats skill-tests mutant)

step_meta() {
  case "$1" in
    deps)         printf '%s\t%s\n' 'Install test dependencies (Linux)|Install test dependencies (macOS)' '本機依賴齊備（CI 的安裝步驟：只驗在不在，唔重裝）' ;;
    ffmpeg)       printf '%s\t%s\n' 'Verify ffmpeg version and flags' 'ffmpeg 版本底線同旗標組合' ;;
    shellcheck)   printf '%s\t%s\n' 'ShellCheck every tracked shell file' 'shellcheck 全量（自我列舉）' ;;
    bashn)        printf '%s\t%s\n' 'Verify bash syntax' 'bash -n 全量（含列舉器下限 tripwire）' ;;
    heredoc)      printf '%s\t%s\n' 'Verify Python heredoc syntax' 'Python heredoc 平衡' ;;
    drift)        printf '%s\t%s\n' 'Verify no document drift (D1-D8)' '文件漂移檢查（D1–D8）' ;;
    mdlint)       printf '%s\t%s\n' 'Lint all markdown files' 'markdownlint（全 repo glob）' ;;
    venv)         printf '%s\t%s\n' 'Build PoC venv (httpx + PyYAML)' 'PoC venv（httpx + PyYAML）' ;;
    bats)         printf '%s\t%s\n' 'Run bats tests' 'repo 級 bats 探針' ;;
    skill-tests)  printf '%s\t%s\n' 'Run skill-local tests' '各 skill 自帶探針（skills/*/tests/）' ;;
    mutant)       printf '%s\t%s\n' 'Verify probes still kill mutants' '突變測試（mutant 必須死）' ;;
    *)            return 2 ;;
  esac
}

# 每一步嘅實際指令（**字串**）。點解用字串：①`--plan` 印嘅同真正跑嘅係同一份 → 冇「說明同實作」漂移；
# ②每步用 `bash -c` 喺**獨立 process** 跑 → 內部 `set -euo pipefail` 真係生效（喺 `if` 條件入面叫
#   function 時 bash 會豁免成個 body 嘅 errexit → 寫成 function 會有「步驟失敗但繼續行」嘅假綠陷阱）。
step_code() {
  case "$1" in
    deps) cat <<'EOF'
set -euo pipefail
missing=0
for t in bats shellcheck markdownlint-cli2 python3 ffmpeg ffprobe pdftoppm pandoc tesseract; do
  command -v "$t" >/dev/null 2>&1 || { echo "缺工具：${t}（安裝方法見 CONTRIBUTING.md）"; missing=1; }
done
python3 -c 'import pptx' >/dev/null 2>&1 || { echo "缺 Python 套件：python-pptx"; missing=1; }
[ "$missing" -eq 0 ] || exit 1
echo "OK: 本機依賴齊備"
EOF
      ;;
    ffmpeg)       printf '%s\n' 'set -euo pipefail' 'bash scripts/ci/check-ffmpeg-version.sh' ;;
    shellcheck)   printf '%s\n' 'set -euo pipefail' 'shellcheck --version | head -3' "shellcheck -x -S style \$(git ls-files '*.sh' '*.bash')" ;;
    bashn) cat <<'EOF'
set -euo pipefail
n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  bash -n "$f" || exit 1
  n=$((n + 1))
done <<< "$(git ls-files '*.sh' '*.bash')"
[ "$n" -ge 15 ] || { echo "FAIL: 只列舉到 $n 個 shell 檔（< 15）→ 列舉器壞了"; exit 1; }
echo "OK: $n shell files syntax-checked"
EOF
      ;;
    heredoc)      printf '%s\n' 'set -euo pipefail' 'bash scripts/ci/check-python-heredocs.sh' ;;
    drift)        printf '%s\n' 'set -euo pipefail' "bash scripts/ci/check-doc-drift.sh --from-date $DRIFT_FROM_DATE" ;;
    mdlint)       printf '%s\n' 'set -euo pipefail' "markdownlint-cli2$MD_GLOBS" ;;
    venv) cat <<'EOF'
set -euo pipefail
# 已存在而且 import 得 → 唔重裝（省時間，亦令離線機唔使為咗「確認」而下網）
VENV="skills/dav-developer/PoC/.venv"
if [ -x "$VENV/bin/python" ] && "$VENV/bin/python" -c 'import httpx, yaml' >/dev/null 2>&1; then
  echo "OK: PoC venv 已存在而且依賴齊（唔重裝）"
  exit 0
fi
bash skills/dav-developer/PoC/setup-venv.sh
EOF
      ;;
    bats)         printf '%s\n' 'set -euo pipefail' 'bats tests/' ;;   # --changed 會另外收窄
    skill-tests) cat <<'EOF'
set -euo pipefail
# 探針跟 skill 搬咗入 skills/*/tests/（2026-10-27）→ 呢一步跑晒所有 skill 自帶探針。
# ⚠️ fail-closed：glob 冇匹配到檔（有人搬走／改名）→ 唔准靜靜哋當通過。
n=0
for f in skills/*/tests/*.bats; do
  [ -f "$f" ] || continue
  n=$((n + 1))
done
[ "$n" -ge 1 ] || { echo "FAIL: 搵唔到任何 skill 自帶探針（skills/*/tests/*.bats）→ glob 失效"; exit 1; }
bats skills/*/tests/*.bats
EOF
      ;;
    mutant)       printf '%s\n' 'set -euo pipefail' 'python3 scripts/ci/mutant-must-die.py' ;;
    *)            return 2 ;;
  esac
}

# ── 參數 ───────────────────────────────────────────────────────────────
MODE=run
ONLY=""
KEEP_GOING=0
CHANGED_ONLY=0
CHANGED_BASE="HEAD" 

usage() {
  cat <<'EOF'
用法：bash scripts/check-all.sh [--only <id>] [--keep-going] [--changed[=<base>]] [--list] [--plan] [-h]
  --list        印步驟清單（id<TAB>ci-ref<TAB>label）　--plan  印解析後嘅實際指令
  --only <id>   只跑指定步驟（id 見 --list）　　　--keep-going  唔 fail-fast
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --list)       MODE=list ;;
    --plan)       MODE=plan ;;
    --only)       shift; [ $# -gt 0 ] || die2 "--only 需要參數"; ONLY="$1" ;;
    --keep-going) KEEP_GOING=1 ;;
    --changed)   CHANGED_ONLY=1 ;;
    --changed=*)  CHANGED_ONLY=1; CHANGED_BASE="${1#--changed=}" ;;
    -h|--help)    usage; exit 0 ;;
    *)            die2 "未知參數：${1}（用 --help 睇用法）" ;;
  esac
  shift
done

if [ -n "$ONLY" ]; then
  found=0
  for id in "${STEPS[@]}"; do
    [ "$id" = "$ONLY" ] && found=1
  done
  [ "$found" -eq 1 ] || die2 "未知步驟：${ONLY}（用 --list 睇清單）"
fi

# ── --changed：計「受改動影響」嘅探針 ＋ mutant 列 ────────────────────────
# 判定規則（刻意保守：唔肯定就當「要跑」）：
#   改動檔案喺 skills/<name>/ 下      → 跑 skills/<name>/tests/*.bats
#   改動檔案喺 tests/ scripts/ lib/ install.sh → 跑 repo 級 tests/
#   改動檔案喺 docs/ .github/          → 跑 drift ＋ mdlint 步驟
#   改動檔案喺其他位置（README 等）    → 跑 mdlint
# mutant：只跑「目標檔喺改動清單入面」嘅列（`mutant-must-die.py --only`）
changed_files() {
  { git diff --name-only "$CHANGED_BASE" 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null; } | sort -u
}
CHANGED_SKILL_PROBES=()
CHANGED_REPO_PROBES=()
CHANGED_MUTANTS=()
CHANGED_DOCS=0
CHANGED_REPO_ALL=0
compute_changed_scope() {
  local f skill
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    case "$f" in
      skills/*/tests/*.bats) ;;                 # 探針自己改咗 → 跑佢
      skills/*/*)
        skill="${f#skills/}"; skill="${skill%%/*}"
        [ -d "skills/${skill}/tests" ] && CHANGED_SKILL_PROBES+=("skills/${skill}/tests/"*.bats)
        ;;
      tests/*.bats)    CHANGED_REPO_PROBES+=("$f") ;;
      tests/*|scripts/*|lib/*|install.sh) CHANGED_REPO_ALL=1 ;;   # 核心工具改咗 → 跑晒 repo 級套件（保守）
      docs/*|.github/*) CHANGED_DOCS=1 ;;
      *.md)             CHANGED_DOCS=1 ;;
    esac
  done < <(changed_files)
  # 去重（同一個 skill 好多個檔改 → glob 會重複加 → ARG_MAX 爆）
  if [ "${#CHANGED_SKILL_PROBES[@]}" -gt 0 ]; then
    mapfile -t CHANGED_SKILL_PROBES < <(printf '%s\n' "${CHANGED_SKILL_PROBES[@]}" | sort -u)
  fi
  if [ "${#CHANGED_REPO_PROBES[@]}" -gt 0 ]; then
    mapfile -t CHANGED_REPO_PROBES < <(printf '%s\n' "${CHANGED_REPO_PROBES[@]}" | sort -u)
  fi
  # mutant：目標檔被改動嘅列
  while IFS=$'\t' read -r mid mtarget _rest; do
    [ -n "${mid:-}" ] || continue
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ "$f" = "$mtarget" ]; then
        CHANGED_MUTANTS+=("${mid}")
        break
      fi
    done < <(changed_files)
  done < <(grep -v '^#' scripts/ci/mutants.tsv | cut -f1,2)
}

case "$MODE" in
  list)
    for id in "${STEPS[@]}"; do
      IFS=$'\t' read -r refs label <<< "$(step_meta "$id")"
      printf '%s\t%s\t%s\n' "$id" "$refs" "$label"
    done
    exit 0
    ;;
  plan)
    for id in "${STEPS[@]}"; do
      IFS=$'\t' read -r refs label <<< "$(step_meta "$id")"
      printf '### %s\t%s\n' "$id" "$label"
      step_code "$id"
      printf '\n'
    done
    exit 0
    ;;
esac

# ── 跑 ─────────────────────────────────────────────────────────────────
# ⚠️ **防遙歸（重要）**：本 runner 會叫 `bats tests/`，而 `tests/` 入面嘅探針 ENV-EQ-19
#    會用「**冇參數**」嘅方式執行每一支 `scripts/ci/*.sh`（包括本檔）→ 冇防遙歸就會
#    bats → runner → bats → … 無限遞歸（本機實測：套件由 213 秒變成 >900 秒卡死）。
#    判斷：bats 執行探針時會**export** `BATS_TEST_FILENAME`／`BATS_RUN_TMPDIR`／
#    `BATS_TEST_TMPDIR`（⚠️ `BATS_TEST_DIRNAME` **唔係** exported → 唔可以用佢判斷；
#    本機實測過）。→ 偵測到就只跑**輕量**步驟（跳過會叫 bats 嗰三支），並喺輸出講明。
HEAVY="bats skill-tests mutant"
INNER=0
if [ -n "${BATS_TEST_FILENAME:-}" ] || [ -n "${BATS_RUN_TMPDIR:-}" ] || [ -n "${BATS_TEST_TMPDIR:-}" ]; then
  INNER=1
fi
# 第二層：結構性遙歸守門。萬一 env 嗅探失效（例如有人用 `env -i` 乾淨環境叫），
# 唔好無限跑 → depth ≥ 1 而又唔係 bats 內層 → fail-fast 報「遞歸」。
# ⚠️ 順序要紧：INNER 優先（bats 內層呼叫係正常嘅，唔可以當遞歸）。
if [ "$INNER" -eq 0 ] && [ "${LOCAL_CI_DEPTH:-0}" -ge 1 ]; then
  echo "FAIL: 偵測到遞歸呼叫（LOCAL_CI_DEPTH=${LOCAL_CI_DEPTH}）→ 唔會再跑落去" >&2
  exit 2
fi
export LOCAL_CI_DEPTH=$(( ${LOCAL_CI_DEPTH:-0} + 1 ))

echo "tree_monstor 本機 CI 等價 runner"
echo "repo：$REPO_ROOT"
echo "步驟：${#STEPS[@]} 個（--list 睇清單／--plan 睇實際指令）"
echo "注意：本機跑唔到跨 OS／跨版本差異 → CI 仍然係最終偵測器"
if [ "$INNER" -eq 1 ]; then
  echo "內層呼叫（偵測到 bats 環境）→ 會跳過重步驟（${HEAVY}）以免遞歸"
fi

if [ "$CHANGED_ONLY" -eq 1 ]; then
  compute_changed_scope
  echo "── --changed 模式 ──"
  echo "改動檔案：$(changed_files | wc -l | tr -d ' ') 個"
  echo "受影響 repo 級探針：${#CHANGED_REPO_PROBES[@]} 個｜受影響 skill 探針：${#CHANGED_SKILL_PROBES[@]} 個｜受影響 mutant：${#CHANGED_MUTANTS[@]} 支"
fi

overall_rc=0
results=""
failed_count=0

for id in "${STEPS[@]}"; do
  if [ -n "$ONLY" ] && [ "$ONLY" != "$id" ]; then
    continue
  fi
  if [ "$INNER" -eq 1 ]; then
    case " $HEAVY " in
      *" $id "*) continue ;;
    esac
  fi
  IFS=$'\t' read -r refs label <<< "$(step_meta "$id")"
  # --changed：呢步要唔要跑？用邊個指令？（skip 會明講原因，唔會靜靜哋當通過）
  cmd="$(step_code "$id")"
  skip=""
  if [ "$CHANGED_ONLY" -eq 1 ]; then
    case "$id" in
      bats)
        if [ "$CHANGED_REPO_ALL" -eq 1 ]; then
          cmd="set -euo pipefail
bats tests/"
        elif [ "${#CHANGED_REPO_PROBES[@]}" -eq 0 ]; then
          skip="冇 repo 級探針檔受改動影響"
        else
          cmd="set -euo pipefail
bats ${CHANGED_REPO_PROBES[*]}"
        fi ;;
      skill-tests)
        if [ "${#CHANGED_SKILL_PROBES[@]}" -eq 0 ]; then
          skip="冇 skill 探針檔受改動影響"
        else
          cmd="set -euo pipefail
bats ${CHANGED_SKILL_PROBES[*]}"
        fi ;;
      mutant)
        if [ "${#CHANGED_MUTANTS[@]}" -eq 0 ]; then
          skip="冇 mutant 嘅目標檔受改動影響"
        else
          ids="$(IFS=,; echo "${CHANGED_MUTANTS[*]}")"
          cmd="set -euo pipefail
python3 scripts/ci/mutant-must-die.py --only ${ids}"
        fi ;;
      drift|mdlint)
        if [ "$CHANGED_DOCS" -eq 0 ]; then
          skip="冇文件／CI 相關改動"
        fi ;;
    esac
  fi
  if [ -n "$skip" ]; then
    printf '\n=== [%s] %s ===\n' "$id" "$label"
    echo "SKIP（--changed：${skip}）"
    results="${results}${id}  SKIP  ${skip}"$'\n'
    continue
  fi
  printf '\n=== [%s] %s ===\n' "$id" "$label"
  start="$(date +%s)"
  rc=0
  bash -c "$cmd" || rc=$?
  end="$(date +%s)"
  secs=$((end - start))
  if [ "${LOCAL_CI_SELF_TEST_FAIL:-}" = "$id" ]; then
    echo "SELF-TEST: LOCAL_CI_SELF_TEST_FAIL=$id → 強制判定呢一步失敗"
    rc=1
  fi
  if [ "$rc" -ne 0 ]; then
    overall_rc=1
    failed_count=$((failed_count + 1))
    results="${results}${id}  FAIL  ${secs}s"$'\n'
    if [ "$KEEP_GOING" -ne 1 ]; then
      break
    fi
  else
    results="${results}${id}  OK    ${secs}s"$'\n'
  fi
done

printf '\n===== 匯總 =====\n'
printf '%s' "$results"
if [ "$failed_count" -gt 0 ]; then
  echo "結果：${failed_count} 步失敗 → 唔好 push（詳見上面嘅紅）"
elif [ "$CHANGED_ONLY" -eq 1 ]; then
  echo "結果：受改動影響嘅步驟全部通過（--changed 模式；**唔等於全量閘通過** → push 前請跑全量）"
else
  echo "結果：全部通過（本機 CI 等價）"
fi
exit "$overall_rc"
