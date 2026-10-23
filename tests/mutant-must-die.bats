#!/usr/bin/env bats
#
# tests/mutant-must-die.bats
#
# TMO-065：突變測試（mutation testing）過去是**一次性人工動作** —— pptx-slim 的 26 支 mutant
#   只有在「當時那個 commit」被證明咬得住。之後任何人把 gate 改成恒真、把護欄拿掉、
#   把精確比對改成子字串，都不會有探針紅，也不會有人記得重跑那張清單。
#   本檔把「那張清單」變成 CI 會跑的檢查（實作：scripts/ci/mutant-must-die.py + scripts/ci/mutants.tsv）。
#
# TMO-066：表擴到 39 支（+6 dav-wiki「缺工具不得降級」／+3 探針機密遮罩／+4 regression-guard
#   TTY fail-fast 文件一致性）；二審後再 +1 → 40 支。dav-wiki 與 regression-guard 的護欄從「人工種過一次」變成 CI 每次跑。
#   註：RG 原本還有一支「SKILL.md 把 **TTY fail-fast** 改成 fail-slow」——實測 mutant 活著：
#   SKILL.md 內同字串另有兩處（規則表、對照表標題），單點改字不影響規則仍在 → 無害突變，不放進表。
#
# 本檔的關注點（不是「跑一次 mutant」而是「這支檢查本身可信」）：
#   MMD-1 突變表的契約（欄位數、id 唯一、錨點唯一、探針名真的存在、覆蓋到決策所在的碼）
#   MMD-2 真的在**副本**上突變（working tree 逐位元不變）而且 mutant 真的死
#   MMD-3 mutant 活著時必須回報失敗（否則整支檢查是假綠：工具自己永遠說 OK）
#   MMD-4 錨點腐化（程式碼改了、表沒改）必須大聲失敗，不是靜默空過
#   MMD-5 CI 真的在跑它（不是「有檔案但沒人叫」的孤兒檢查）
#   MMD-6 突變表的結構錯誤（欄數／空欄／等價突變／id 重複／重複列／空表）在**載入期**就要擋下
#
# TMO-066 二審（claude-code，verdict = request-changes）後追加：
#   * DW-M5：原本只能當「文字契約鎖」（咬 WTM-6 的『檔案不得出現 EXIT_TOOLMISSING』）；
#     後改成**真行為鎖**——先把 `tests/wiki-ocr.bats` 的 AC-O4/AC-O6 由「只驗非零」收緊為
#     驗 2／驗 1（測名本來就這樣寫，只驗非零已是假綠），再看 mutant「把 EXIT_NOINPUT 改成 1」
#     是否會被咬住（會）。約定 `MUTANT(text-lock):` 仍保留，目前表內 0 列。
#   * SM-M1 重寫：舊版把 `sed -E \` 換成 `cat #...` 掉了續行反斜線（rc=127 假死因）。
#     現在 helper 的 sed 程式刻意寫成**單行**，mutant 才能一行換成 `cat`（真・直通）。
#   * 新增 LK-M1：把掃描器的 `git ls-files -co --exclude-standard` 改回 `-c`（＝untracked 盲點回歸）；
#     搭配 `lint-shell-var-nonascii.py --self-test` 新增的「未追蹤檔必須入列」契約，兩者一起紅。
#   * 表 39 → 42 支。
#
# Usage:
#   bats tests/mutant-must-die.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  MMD="$REPO_ROOT/scripts/ci/mutant-must-die.py"
  TABLE="$REPO_ROOT/scripts/ci/mutants.tsv"
  # 可用環境變數覆寫（探針自測用：拿假的 ci.yml 進來說「應該要紅」）
  CI_YML="${CI_YML:-$REPO_ROOT/.github/workflows/ci.yml}"
  W="$BATS_TEST_TMPDIR"
  export REPO_ROOT MMD TABLE CI_YML W
}

# 跑 mmd 並把 rc 與輸出留在 $status / $output（run 會覆蓋，故集中在此）
run_mmd() {
  run python3 "$MMD" "$@"
}

@test "MMD-1: 突變表契約（欄位齊、id 唯一、錨點唯一、探針名存在、覆蓋到決策碼）" {
  [ -x "$MMD" ] || { echo "FAIL: $MMD 不存在或不可執行" >&2; return 1; }
  run_mmd --list
  [ "$status" -eq 0 ]
  # 只取真正的資料列（4 欄）：`--list` 的統計行走 stderr，會被 bats 併進 $output
  printf '%s\n' "$output" | awk -F'\t' 'NF==4' > "$W/list.txt"
  local n
  n=$(grep -c . "$W/list.txt")
  [ "$n" -ge 40 ] || { echo "FAIL: 只列到 $n 支 mutant（預期 >= 40）→ 有人在偷偷刪表" >&2; return 1; }

  local -a ids=() targets=()
  local line id target probe_file probe
  while IFS=$'\t' read -r id target probe_file probe; do
    [ -n "$id" ] || continue
    ids+=("$id"); targets+=("$target")
    [ -n "$probe_file" ] && [ -n "$probe" ] || { echo "FAIL: $id 欄位不齊" >&2; return 1; }
    [ -f "$REPO_ROOT/$target" ] || { echo "FAIL: $id 指到不存在的檔案 $target" >&2; return 1; }
    [ -f "$REPO_ROOT/$probe_file" ] || { echo "FAIL: $id 指到不存在的探針 $probe_file" >&2; return 1; }
    grep -qF -- "$probe" "$REPO_ROOT/$probe_file" ||
      { echo "FAIL: $id 的探針名 '$probe' 在 $probe_file 內找不到（打錯字＝假紅）" >&2; return 1; }
  done < "$W/list.txt"

  local uniq
  uniq=$(printf '%s\n' "${ids[@]}" | sort -u | grep -c .)
  [ "$uniq" -eq "${#ids[@]}" ] || { echo "FAIL: mutant id 有重複（${#ids[@]} 列 vs $uniq 個唯一）" >&2; return 1; }

  # 覆蓋範圍：決策所在的 5 支 py 都要有 mutant，加上 ffmpeg 版本鎖
  local t
  for t in pptx-shrink-media.py pptx-shrink-images.py pptx-repack.py pptx-verify.py pptx_common.py; do
    printf '%s\n' "${targets[@]}" | grep -qF "skills/pptx-slim/scripts/$t" ||
      { echo "FAIL: 突變表沒有覆蓋 skills/pptx-slim/scripts/$t" >&2; return 1; }
  done
  printf '%s\n' "${targets[@]}" | grep -qF 'scripts/ci/check-ffmpeg-version.sh' ||
    { echo "FAIL: 突變表沒有覆蓋 scripts/ci/check-ffmpeg-version.sh" >&2; return 1; }

  # TMO-066：其他 skill 的護欄也在表內（dav-wiki「缺工具不得降級」、regression-guard
  # TTY fail-fast 文件一致性）。少了就紅，避免有人只保留 pptx-slim 那段而靜默丟掉別人的護欄。
  local d
  for d in skills/dav-wiki/scripts/wiki-extract-audio.sh \
           skills/dav-wiki/scripts/wiki-extract-media.sh \
           skills/dav-wiki/scripts/wiki-cleanup.sh \
           skills/dav-wiki/SKILL.md \
           skills/regression-guard/SKILL.md; do
    printf '%s\n' "${targets[@]}" | grep -qF "$d" ||
      { echo "FAIL: 突變表沒有覆蓋 ${d}（TMO-066 的跨 skill 護欄）" >&2; return 1; }
  done

  # 註：欄數／等價突變／id 重複屬 runner 的載入契約（`Mutant.__init__`），由 MMD-6 以合成表實測紅；
  # 這裡不再重寫一份同樣的邏輯（免得兩邊漂移）——MMD-1 只管「真表 vs 真檔」這一段。

  # 錨點唯一性（在真檔上驗一次；這才是「表會隨程式碼腐化」的那道鎖）
  # 注意：用 `grep -oF | grep -c .` 數**出現次數**，不是 `grep -cF` 的**行數**——
  # 同一行出現兩次時行數仍是 1，會讓「恰好 1 次」的保證失效（二審 F3）。
  local field file hits
  while IFS=$'\t' read -r id file field; do
    [ -n "$id" ] || continue
    hits=$(grep -oF -- "$field" "$REPO_ROOT/$file" | grep -c .)
    [ "$hits" -eq 1 ] ||
      { echo "FAIL: $id 的錨點在 $file 內出現 $hits 次（應為恰好 1 次）" >&2; return 1; }
  done <<< "$(grep -v '^#' "$TABLE" | cut -f1,2,3)"
}

@test "MMD-2: mutant 真的死在副本上，working tree 逐位元不變" {
  local before after
  before=$(cd "$REPO_ROOT" && git status --porcelain | sort)
  run_mmd --only IMG-M3,FF-M2
  [ "$status" -eq 0 ] || { echo "FAIL: mmd rc=$status" >&2; printf '%s\n' "$output" | tail -20 >&2; return 1; }
  # 兩支都要真的紅，不能只是「跑完沒報錯」
  [ "$(printf '%s\n' "$output" | grep -c 'mutant 死了')" -eq 2 ] ||
    { echo "FAIL: 沒有兩支 mutant 死亡紀錄" >&2; return 1; }
  [[ "$output" == *"OK:"* ]]
  # 副本外掛載點：working tree 不能被動到（工具自己也自證，這裡獨立再驗一次）
  after=$(cd "$REPO_ROOT" && git status --porcelain | sort)
  [ "$before" = "$after" ] || { echo "FAIL: mmd 動到了 working tree" >&2; return 1; }
}

@test "MMD-3: mutant 活著時整支檢查必須回報失敗（否則它是假綠）" {
  # 造一張「無害突變」表：改動真實發生、但對受測行為沒影響 → 探針必綠 → 必須被當成 survivor。
  # （不可用「原文＝換成」當無害案例：那叫等價突變，載入期就被擋掉了，見 MMD-6。）
  printf 'NOOP-1\tskills/pptx-slim/scripts/pptx-verify.py\t        bad = zf.testzip()\t        bad = zf.testzip()  # MUTANT: 無害改動（只加註解，行為不變）\ttests/pptx-slim.bats\tPPTX-SLIM-12\n' > "$W/noop.tsv"
  run_mmd --table "$W/noop.tsv"
  [ "$status" -eq 1 ] || { echo "FAIL: 無害突變竟然回報成功（rc=${status}）→ 這支檢查會永遠說 OK" >&2; return 1; }
  [[ "$output" == *"還活著"* ]] || { echo "FAIL: 沒有回報 survivor" >&2; return 1; }
}

@test "MMD-6: 突變表結構錯誤（欄數／空欄／等價突變／id 重複／重複列／空表）必須在載入期就擋下" {
  local anchor='        bad = zf.testzip()'
  # ① 欄數 5
  printf 'MUT-A\tskills/pptx-slim/scripts/pptx-verify.py\ta\tb\tc\n' > "$W/cols.tsv"
  run_mmd --table "$W/cols.tsv" --list
  [ "$status" -ne 0 ] || { echo "FAIL: 5 欄的表竟然通過" >&2; return 1; }
  [[ "$output" == *"6 欄"* ]] || { echo "FAIL: 沒指出欄數（${output}）" >&2; return 1; }

  # ② 等價突變（原文＝換成）——二審 F3 的主角
  printf 'MUT-A\tskills/pptx-slim/scripts/pptx-verify.py\t%s\t%s\ttests/pptx-slim.bats\tPPTX-SLIM-12\n' \
    "$anchor" "$anchor" > "$W/noop.tsv"
  run_mmd --table "$W/noop.tsv" --list
  [ "$status" -ne 0 ] || { echo "FAIL: 等價突變竟然通過（會變成灌水列）" >&2; return 1; }
  [[ "$output" == *"等價"* ]] || { echo "FAIL: 沒指出等價突變（${output}）" >&2; return 1; }

  # ③ id 重複
  printf 'MUT-A\tskills/pptx-slim/scripts/pptx-verify.py\t%s\t        bad = None\ttests/pptx-slim.bats\tPPTX-SLIM-12\nMUT-A\tskills/pptx-slim/scripts/pptx-verify.py\t%s\t        bad = None\ttests/pptx-slim.bats\tPPTX-SLIM-12\n' \
    "$anchor" "$anchor" > "$W/dup.tsv"
  run_mmd --table "$W/dup.tsv" --list
  [ "$status" -ne 0 ] || { echo "FAIL: id 重複竟然通過" >&2; return 1; }
  [[ "$output" == *"id 重複"* ]] || { echo "FAIL: 沒指出 id 重複（${output}）" >&2; return 1; }

  # ④ 空表（只有註解）——空過也是假綠
  printf '# 只有註解\n' > "$W/empty.tsv"
  run_mmd --table "$W/empty.tsv" --list
  [ "$status" -ne 0 ] || { echo "FAIL: 空表竟然通過（空過＝假綠）" >&2; return 1; }
  [[ "$output" == *"空的"* ]] || { echo "FAIL: 沒指出表是空的（${output}）" >&2; return 1; }

  # ⑤ 某欄空白（探針名空）——空欄會讓 `--list` 統計靜默失真
  printf 'MUT-A\tskills/pptx-slim/scripts/pptx-verify.py\t%s\t        bad = None\ttests/pptx-slim.bats\t\n' \
    "$anchor" > "$W/emptyfield.tsv"
  run_mmd --table "$W/emptyfield.tsv" --list
  [ "$status" -ne 0 ] || { echo "FAIL: 空欄竟然通過" >&2; return 1; }
  [[ "$output" == *"是空的"* ]] || { echo "FAIL: 沒指出哪一欄是空的（${output}）" >&2; return 1; }

  # ⑥ 重複列（同目標檔／原文／換成，只換 id）＝把「40 支」灌大
  printf 'MUT-A\tskills/pptx-slim/scripts/pptx-verify.py\t%s\t        bad = None\ttests/pptx-slim.bats\tPPTX-SLIM-12\nMUT-B\tskills/pptx-slim/scripts/pptx-verify.py\t%s\t        bad = None\ttests/pptx-slim.bats\tPPTX-SLIM-12\n' \
    "$anchor" "$anchor" > "$W/duprow.tsv"
  run_mmd --table "$W/duprow.tsv" --list
  [ "$status" -ne 0 ] || { echo "FAIL: 同一個突變拆成兩列竟然通過" >&2; return 1; }
  [[ "$output" == *"重複列"* ]] || { echo "FAIL: 沒指出重複列（${output}）" >&2; return 1; }
}

@test "MMD-4: 錨點腐化（碼改了、表沒改）必須大聲失敗，不是靜默空過" {
  printf 'ROT-1\tskills/pptx-slim/scripts/pptx-verify.py\tTHIS_ANCHOR_DOES_NOT_EXIST_ANYWHERE\tx\ttests/pptx-slim.bats\tPPTX-SLIM-12\n' > "$W/rot.tsv"
  run_mmd --table "$W/rot.tsv"
  [ "$status" -ne 0 ]
  [[ "$output" == *"錨點"* ]] || { echo "FAIL: 沒有指出錨點失效" >&2; return 1; }
}

# 檢查一個 ci.yml「是否真的會跑全表」。合格回 0；不合格印原因回 1。
# 只看非註解行，並把空白／大小寫正規化——否則 `||true`、`continue-on-error: True`、
# `if: false` 這些寫法會繞過（reviewer round-2 P1-1／P2-1；in-repo 先例 MLG-2／MLG-9）。
ci_runs_full_table() {
  local file=$1 block compact runline
  block=$(awk '/name: Verify probes still kill mutants/{flag=1} flag{print} /^      - name:/&&flag&&!/Verify probes still kill mutants/{exit}' "$file")
  [[ -n "$block" ]] || { echo "找不到跑 mutant-must-die.py 的 step"; return 1; }
  [[ "$block" == *"mutant-must-die.py"* ]] || { echo "step 沒有叫 mutant-must-die.py"; return 1; }
  compact=$(printf '%s\n' "$block" | grep -v '^[[:space:]]*#' | tr -d '[:space:]' | tr 'A-Z' 'a-z')
  case "$compact" in
    *"if:"*) echo "step 帶 if: 條件（可被停用＝突變表不保證跑）"; return 1 ;;
    *"continue-on-error:true"*) echo "step 帶 continue-on-error（失敗不會紅）"; return 1 ;;
    *"||true"*) echo "step 用 || true 短路（失敗不會紅）"; return 1 ;;
  esac
  runline=$(printf '%s\n' "$block" | grep -v '^[[:space:]]*#' | grep -F 'mutant-must-die.py')
  # 真的在「叫 python 跑那支腳本」嗎？否則 `run: echo 假裝有跑 mutant-must-die.py` 也算過關
  case "$runline" in
    *python*"scripts/ci/mutant-must-die.py"*) : ;;
    *) echo "run 不是真的用 python 跑 scripts/ci/mutant-must-die.py"; return 1 ;;
  esac
  case "$runline" in
    *--list*) echo "只列清單（--list 不跑任何 mutant）"; return 1 ;;
    *--only*) echo "只跑部分 mutant（--only）"; return 1 ;;
    *--no-baseline*) echo "略過 baseline（失去自證）"; return 1 ;;
  esac
  return 0
}

# 造一個只含該 step 的最小 ci.yml（$1＝run 行內容，$2＝step 內額外一行）
fake_ci() {
  printf 'jobs:\n  m:\n    steps:\n      - name: Verify probes still kill mutants\n        run: %s\n' "$1"
  [ -z "${2:-}" ] || printf '        %s\n' "$2"
}

@test "MMD-5: CI 真的跑全表（不得 || true／continue-on-error／if:／--list／--only／--no-baseline）" {
  run ci_runs_full_table "$CI_YML"
  [ "$status" -eq 0 ] || { echo "FAIL: 真的 ci.yml 沒通過檢查：$output" >&2; return 1; }

  # 反向自測（probe-of-the-probe）：這支檢查自己必須咬得住 10 種假綠，否則它只是恒綠裝飾
  local v extra
  for v in "if: false" "if: runner.os == 'Linux'" "continue-on-error: true" "continue-on-error:true"; do
    fake_ci "python3 scripts/ci/mutant-must-die.py ." "$v" > "$BATS_TEST_TMPDIR/fake.yml"
    run ci_runs_full_table "$BATS_TEST_TMPDIR/fake.yml"
    [ "$status" -ne 0 ] || { echo "FAIL: 假綠「${v}」沒有被咬住" >&2; return 1; }
  done
  for v in "python3 scripts/ci/mutant-must-die.py . || true" \
           "python3 scripts/ci/mutant-must-die.py .||true" \
           "python3 scripts/ci/mutant-must-die.py . --list" \
           "python3 scripts/ci/mutant-must-die.py . --only IMG-M1" \
           "python3 scripts/ci/mutant-must-die.py . --no-baseline" \
           "echo 假裝有跑 mutant-must-die.py"; do
    fake_ci "$v" "" > "$BATS_TEST_TMPDIR/fake.yml"
    run ci_runs_full_table "$BATS_TEST_TMPDIR/fake.yml"
    [ "$status" -ne 0 ] || { echo "FAIL: 假綠「${v}」沒有被咬住" >&2; return 1; }
  done
}
