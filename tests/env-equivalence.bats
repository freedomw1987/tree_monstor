#!/usr/bin/env bats
#
# tests/env-equivalence.bats
#
# TMO-041：環境等價／「本機假綠」殘餘防線。
#
# 背景：CI 紅、本機全綠已經發生過三次（TMO-039），根因都是「本機狀態 ≠ CI 狀態」：
#   * bash 版本：macOS 預設 3.2 / CI ubuntu 5.2 / 本機 brew 5.3 —— 同一句展開在三者行為不同
#   * 固定 `/tmp/<name>` 檔名：跨 run 殘留的舊檔會讓「檔案有沒有被寫出來」的斷言假綠
#   * 真網路：本機連得到，oracle 打到真 API 會讓 fixture 缺口被掩蓋
#   * 未 stub 的外部工具（gh / brew）：本機有裝就會「剛好過」
#
# 本檔守 ENV-EQ-1..19（18 條可證偽斷言 + 1 條量測 ENV-EQ-4；11..19 於 TMO-041/2026-10-05 CI 首跑追加）：
#   1. 本機必須有 bash 5.x 可用（缺 → 紅＋安裝指令，不 skip）
#   2. `skills/dav-wiki/tests/wiki-cleanup.bats` 在**每一個**本機可用 bash 版本下都全綠
#      （PATH shim 真的把 bash 換掉；bash 5.x 這條＝CI 的 ubuntu bash 變體 Gate 3）
#   3. shim 機制本身有效（bats 真的跑在目標 bash 上）→ 否則第 2 條等於在跑預設 bash
#   4. 空陣列 × `set -u` 的行為對照表：逐版本實測並印出（**量測，刻意不斷言**；
#      ubuntu bash 5.2 的行為本機無此版本可驗，寫預測會變假紅）
#   5. 探針不得寫入固定 `/tmp/<name>`（要寫就寫 `$BATS_TEST_TMPDIR`；純資料引用標 `TMP-OK`）
#   6. 探針不得直接執行 `gh` / `brew`（工具狀態依賴）
#   7. oracle 子集在「網路黑洞」下必須全綠，且黑洞本身要有 canary 證明真的在擋
#   8. `scripts/ci/` 的護欄腳本不得是「孤兒鎖」（沒有任何探針引用＝等於沒在跑），
#      且每個 `--self-test` 鎖的自我測試都必須自己綠（新增的鎖自動納入＝不會漏）
#   9. 宣告的 `@test` 數 == `bats --count`（防 TMO-026 型「宣告 N／實跑 N-3」）＋ CJK 名稱 canary
#  10. 本機安裝文件必須教「釘版 bats」（CI 已釘 v1.14.0；只鎖 CI 一側＝本機仍是漂移來源）
#
# 註: @test 名稱以純英文為主。
#     ⚠️ **TMO-074 更正**：上一版註解寫「2026-10-05 實測 bats 1.14.0：開頭 CJK／尾綴 CJK 都會跑」——
#     那次實測是在 **LC_ALL=C** 的 locale 下做的，結論只在那個環境成立。
#     2026-10-26 二次實測（bats 1.14.0）——**變因是「bash 版本 × locale」兩個**：
#       bash 3.2 + UTF-8 locale → CJK 名**被丟棄**（`[[:alnum:]]` 認 Unicode 字母 → 函式名對不上）
#       bash 3.2 + C locale   → CJK 名**會跑**
#       bash 5.3 + UTF-8 locale → CJK 名**會跑**   ← CI（ubuntu/macOS 都是 bash 5.x）
#       bash 5.3 + C locale   → CJK 名**會跑**
#     實測被丟棄的有：中文／假名／韓文／西里爾；**不會**被丟棄的有：希臘文、café、全形英數、emoji、→。
#     → **CI 沒有這個病**；受影響的是**本機 bash 3.2**（macOS 預設）→ 本機假綠。
#     處理：①repo 內所有 @test 名一律純 ASCII（2026-10-27 減法：PNA-1 探針已刪 → 改為寫探針時自律）
#           → 讓本機與 CI 跑同一套探針、看到同一個結果；
#           ②本檔 ENV-EQ-9 的 canary 改成**依當前環境實測**的斷言（下方）。

setup() {
  load 'helpers/test-env'
  load 'helpers/probe-scan'
  POC_DIR="$REPO_ROOT/skills/dav-jev-oracle/PoC"
}

# 宣告數普查用：只算 bats 真的會當成 @test 的行 —— heredoc 內容（示範碼）不算。
# 註：bats 前處理器會把 heredoc 內的 `@test` 行改寫成 `bats_test_function ...`
# （實測 1.14.0），所以「用 heredoc 寫 fixture」不能拿來測這個函式，fixture 要用 printf。
#
# ⚠️ TMO-074：掃描器本體已外移到 `tests/helpers/probe-scan.bash`（與 TMO-074 新增的
#    掃描器本體），避免兩份掃描器漂移。
#    這裡保留薄包裝只是為了不動 ENV-EQ-9 的自我測試呼叫點。
count_declared_tests() {
  probe_declared_count "$1"
}

# 找出本機所有可用的 bash（去重：以版本字串為鍵），寫進 ${1}（TSV: version<TAB>binary）
collect_bash_versions() {
  local out="$1" cand v
  : > "$out"
  for cand in "$(command -v bash 2>/dev/null || true)" /bin/bash \
              /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [ -n "$cand" ] && [ -x "$cand" ] || continue
    v=$("$cand" -c 'echo $BASH_VERSION' 2>/dev/null) || continue
    [ -n "$v" ] || continue
    grep -qF "$(printf '%s\t' "$v")" "$out" && continue
    printf '%s\t%s\n' "$v" "$cand" >> "$out"
  done
  [ -s "$out" ]
}

# 找出任一個 bash major >= 5 的執行檔（找不到回空字串）
find_bash5() {
  local cand v
  for cand in /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash 2>/dev/null || true)" /bin/bash; do
    [ -n "$cand" ] && [ -x "$cand" ] || continue
    v=$("$cand" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null) || continue
    [ -n "$v" ] && [ "$v" -ge 5 ] 2>/dev/null && {
      printf '%s\n' "$cand"
      return 0
    }
  done
  return 1
}

@test "ENV-EQ-1: a bash 5.x interpreter is available locally (fail loud, never skip)" {
  local b5
  b5=$(find_bash5) || {
    echo "FAIL: 本機找不到 bash 5.x —— CI 的 ubuntu 用 bash 5.x，本機只用 bash 3.2 測等於沒測" >&2
    echo "      修復（macOS）：brew install bash" >&2
    return 1
  }
  echo "OK: bash 5.x = $b5 ($("$b5" -c 'echo $BASH_VERSION'))" >&2
}

@test "ENV-EQ-2: wiki-cleanup suite is green under every local bash version" {
  local vers="$BATS_TEST_TMPDIR/bash-versions.tsv"
  collect_bash_versions "$vers" || {
    echo "FAIL: 收不到任何可用的 bash（環境異常）" >&2
    return 1
  }
  local ran=0 has5=0 v bin shim got rc notok okn
  while IFS=$'\t' read -r v bin; do
    shim="$BATS_TEST_TMPDIR/shim-$ran"
    mkdir -p "$shim"
    ln -sf "$bin" "$shim/bash"
    # 反空過：shim 必須真的把 PATH 上的 bash 換成這個版本
    got=$(PATH="$shim:$PATH" bash -c 'echo $BASH_VERSION')
    [ "$got" = "$v" ] || {
      echo "FAIL: shim 沒生效（期望 ${v}，得到 ${got}）" >&2
      return 1
    }
    run env PATH="$shim:$PATH" bats "$REPO_ROOT/skills/dav-wiki/tests/wiki-cleanup.bats"
    rc=$status
    printf '%s\n' "$output" > "$BATS_TEST_TMPDIR/wc-$ran.txt"
    okn=$(printf '%s\n' "$output" | grep -c '^ok ' || true)
    notok=$(printf '%s\n' "$output" | grep -c '^not ok ' || true)
    printf '  bash %-28s → rc=%s ok=%s not ok=%s (%s)\n' "$v" "$rc" "$okn" "$notok" "$bin" >&2
    [ "$rc" -eq 0 ] && [ "$notok" -eq 0 ] || {
      echo "FAIL: wiki-cleanup 套件在 bash $v 下紅了（rc=$rc, not ok=${notok}）；輸出見 $BATS_TEST_TMPDIR/wc-$ran.txt" >&2
      grep -A3 '^not ok ' "$BATS_TEST_TMPDIR/wc-$ran.txt" | head -12 >&2
      return 1
    }
    [ "$okn" -ge 20 ] || {
      echo "FAIL: bash $v 只跑了 $okn 條（防空過；預期 >= 20）" >&2
      return 1
    }
    case "$v" in 5.*) has5=1 ;; esac
    ran=$((ran + 1))
  done < "$vers"

  [ "$ran" -ge 1 ] || {
    echo "FAIL: 一個 bash 版本都沒跑到（防空過）" >&2
    return 1
  }
  [ "$has5" -eq 1 ] || {
    echo "FAIL: 這輪沒跑到任何 bash 5.x → 「CI 等價」不成立（見 ENV-EQ-1 的安裝指令）" >&2
    return 1
  }
  echo "OK: $ran 個 bash 版本皆綠（含 5.x）" >&2
}

@test "ENV-EQ-3: the PATH shim really switches the bash that bats uses" {
  local vers="$BATS_TEST_TMPDIR/bash-versions.tsv"
  collect_bash_versions "$vers" || {
    echo "FAIL: 收不到任何可用的 bash" >&2
    return 1
  }
  local defv defmajor
  defv=$(bash -c 'echo $BASH_VERSION')
  defmajor=${defv%%.*}

  # 在 $BATS_TEST_TMPDIR 造一個「只認 bash 5.x」的小測試檔，只有 shim 生效時才會綠
  local mini="$BATS_TEST_TMPDIR/mini-bash5.bats"
  cat > "$mini" <<'MINI'
#!/usr/bin/env bats
@test "declared bash is 5.x or newer" {
  [ "${BASH_VERSINFO[0]}" -ge 5 ]
}
MINI

  local b5 shim rc
  b5=$(find_bash5) || {
    echo "FAIL: 找不到 bash 5.x（ENV-EQ-1 已要求）" >&2
    return 1
  }
  shim="$BATS_TEST_TMPDIR/shim-mini"
  mkdir -p "$shim"
  ln -sf "$b5" "$shim/bash"
  run env PATH="$shim:$PATH" bats "$mini"
  rc=$status
  [ "$rc" -eq 0 ] || {
    echo "FAIL: 在 bash 5.x shim 下小測試檔沒過（rc=${rc}）→ shim 沒生效，ENV-EQ-2 會是假的" >&2
    printf '%s\n' "$output" >&2
    return 1
  }

  # 對照組：預設 bash 若 < 5（macOS 3.2），同一個檔必須紅 → 證明「換 bash」真的換得動
  if [ "$defmajor" -lt 5 ]; then
    run bats "$mini"
    [ "$status" -ne 0 ] || {
      echo "FAIL: 預設 bash $defv 竟然也讓「必須 5.x」的小測試過 → 版本判定壞了" >&2
      return 1
    }
    echo "OK: shim 把 bash 由 $defv 換成 $("$b5" -c 'echo $BASH_VERSION')（對照組紅 ✓）" >&2
  else
    echo "OK: 預設 bash 已是 ${defv}（>= 5）→ 無 3.x 對照組（本機單一版本）" >&2
  fi
}

@test "ENV-EQ-4: empty-array-under-set-u behaviour is measured per bash version" {
  local vers="$BATS_TEST_TMPDIR/bash-versions.tsv"
  collect_bash_versions "$vers" || {
    echo "FAIL: 收不到任何可用的 bash" >&2
    return 1
  }
  # 純量測＋印表（環境等價的證據）。刻意「不斷言某版本必須錯」：CI 當時那條
  # （ubuntu bash 5.2 報 unbound）本機無法重現，硬寫預測會變成假紅。
  local v bin rc out lenform arrform
  local script_len='set -u
a=()
echo "len=${#a[@]}"'
  local script_arr='set -u
a=()
printf "%s\n" "${a[@]}"'
  while IFS=$'\t' read -r v bin; do
    if out=$("$bin" -c "$script_len" 2>&1); then rc=0; else rc=$?; fi
    lenform="$rc/${out##*=}"
    if out=$("$bin" -c "$script_arr" 2>&1); then rc=0; else rc=$?; fi
    case "$out" in
      *unbound*) arrform="unbound(rc=$rc)" ;;
      "") arrform="empty-ok" ;;
      *) arrform="other(rc=$rc)" ;;
    esac
    printf '  bash %-28s  ${#a[@]} → rc=%s   "${a[@]}" → %s\n' "$v" "$lenform" "$arrform" >&2
  done < "$vers"
  echo "OK: 已逐版本量測（上表為環境等價證據；版本清單 = ${vers}）" >&2
}

# 靜態鎖（TMO-041 ③d/③b）：實作抽在 scripts/ci/ 下，避免探針掃到自己
@test "ENV-EQ-5: no probe writes to a fixed /tmp path (cross-run residue lock)" {  # TMP-OK: 只有測試名稱提到 /tmp，本行不寫檔
  local lock="$REPO_ROOT/scripts/ci/lint-probe-tmp-paths.py"
  [ -f "$lock" ] || {
    echo "FAIL: 缺 $lock" >&2
    return 1
  }
  run python3 "$lock" --self-test
  [ "$status" -eq 0 ] || {
    printf '%s\n' "$output" >&2
    echo "FAIL: 鎖 1 自我測試紅了" >&2
    return 1
  }
  printf '%s\n' "$output" >&2
  run python3 "$lock" "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s\n' "$output" >&2
}

@test "ENV-EQ-6: no probe executes gh / brew directly (tool-state lock)" {
  local lock="$REPO_ROOT/scripts/ci/lint-probe-tools.py"
  [ -f "$lock" ] || {
    echo "FAIL: 缺 $lock" >&2
    return 1
  }
  run python3 "$lock" --self-test
  [ "$status" -eq 0 ] || {
    printf '%s\n' "$output" >&2
    echo "FAIL: 鎖 2 自我測試紅了" >&2
    return 1
  }
  printf '%s\n' "$output" >&2
  run python3 "$lock" "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s\n' "$output" >&2
}

@test "ENV-EQ-7: oracle subset stays green with the network black-holed" {
  local py="$POC_DIR/.venv/bin/python"
  [ -x "$py" ] || {
    echo "FAIL: 缺 PoC venv（bash skills/dav-jev-oracle/PoC/setup-venv.sh）" >&2
    return 1
  }
  # 黑洞代理：指向一個不會有人聽的 port → 任何真連線都會立刻被拒
  local proxy="http://127.0.0.1:9"

  # canary：黑洞真的在擋（canary 破了 → 這條測試就是假隔離，必須紅）
  run env HTTP_PROXY="$proxy" HTTPS_PROXY="$proxy" ALL_PROXY="$proxy" \
      no_proxy= NO_PROXY= \
      "$py" -c 'import urllib.request; urllib.request.urlopen("http://example.com", timeout=5)'
  [ "$status" -ne 0 ] || {
    echo "FAIL: 黑洞代理沒擋住連線（canary 破了）→ 本測試無效" >&2
    return 1
  }

  local fails="$REPO_ROOT/skills/dav-jev-oracle/tests/v2.1-jev-poc.bats"
  local filter ok_total=0 notok_total=0 ran=0 rc f
  for f in 'M5-runtime-b' '^M6-g' 'M6.1-c'; do
    run env -u OPENROUTER_API_KEY HOME="$BATS_TEST_TMPDIR/nohome" \
        JEV_ENV_FILE=/dev/null JEV_CACHE_DIR="$POC_DIR/cache-fixtures" \
        HTTP_PROXY="$proxy" HTTPS_PROXY="$proxy" ALL_PROXY="$proxy" \
        no_proxy= NO_PROXY= \
        bats -f "$f" "$fails"
    rc=$status
    printf '%s\n' "$output" > "$BATS_TEST_TMPDIR/oracle-$ran.txt"
    local okn notokn
    okn=$(printf '%s\n' "$output" | grep -c '^ok ' || true)
    notokn=$(printf '%s\n' "$output" | grep -c '^not ok ' || true)
    [ "$rc" -eq 0 ] && [ "$notokn" -eq 0 ] && [ "$okn" -eq 1 ] || {
      echo "FAIL: 黑洞網路下 $f 紅了（rc=$rc, ok=$okn, not ok=${notokn}）；輸出見 $BATS_TEST_TMPDIR/oracle-$ran.txt" >&2
      grep -A5 '^not ok ' "$BATS_TEST_TMPDIR/oracle-$ran.txt" | head -12 >&2
      return 1
    }
    ok_total=$((ok_total + okn))
    notok_total=$((notok_total + notokn))
    ran=$((ran + 1))
  done
  [ "$ran" -eq 3 ] && [ "$ok_total" -eq 3 ] || {
    echo "FAIL: 只跑了 $ran 條／$ok_total ok（防空過；預期 3）" >&2
    return 1
  }
  echo "OK: 3 條 oracle 探針在黑洞網路下全綠（canary 證明黑洞有效）" >&2
}

@test "ENV-EQ-8: every scripts/ci lock is referenced by a probe, and every self-testable lock passes its own self-test" {
  local d="$REPO_ROOT/scripts/ci"
  local -a locks=() orphans=() failed=()
  local f name out
  for f in "$d"/check-*.sh "$d"/lint-probe-*.py; do
    [ -f "$f" ] || continue          # 允許某類尚未存在（不讓 glob 落空變成假綠）
    locks+=("$f")
  done
  [ "${#locks[@]}" -ge 4 ] || {
    echo "FAIL: 只找到 ${#locks[@]} 個 scripts/ci 護欄腳本（<4）→ 抽取器可能壞了（防空過）" >&2
    return 1
  }
  for f in "${locks[@]+${locks[@]}}"; do
    name="$(basename "$f")"
    # (a) 有沒有任何探針引用它（＝有沒有人在跑它；新增鎖不會被漏掉＝自動列舉）
    grep -rqF "$name" "$REPO_ROOT/tests" || orphans+=("$name")
    # (b) 支援 `--self-test` 的鎖（py 靜態鎖）：自我測試必須自己綠（抽取器的正反兩向證明）
    if [ "${name#lint-probe-}" != "$name" ]; then
      if out=$(python3 "$f" --self-test 2>&1); then
        # 自我測試必須真的印出「通過」標記；把 self_test() 掏空成 `return 0` 也會被這條抓到
        printf '%s\n' "$out" | grep -qE 'OK: 鎖 [0-9]+ 自我測試通過' ||
          failed+=("${name}：--self-test 沒印通過標記（自我測試可能被掏空）")
      else
        failed+=("$name")
        printf '%s\n' "$out" >&2
      fi
    fi
  done
  if [ "${#orphans[@]}" -ne 0 ]; then
    echo "FAIL: 孤兒護欄腳本（沒有任何探針引用，等於沒在跑）：${orphans[*]}" >&2
    return 1
  fi
  if [ "${#failed[@]}" -ne 0 ]; then
    echo "FAIL: 這些鎖的自我測試紅了（抽取器壞掉卻沒人知道）：${failed[*]}" >&2
    return 1
  fi
  echo "OK: ${#locks[@]} 個 scripts/ci 護欄腳本都有探針引用；lint-probe-* 的 --self-test 全綠" >&2
}


@test "ENV-EQ-9: no test declaration is silently dropped (repo census + CJK-name canary)" {
  # 註（round F P3-6；round G F1 更正不實敘述）：本條的普查與 `bats --count tests/` **都非遞迴**
  # （bats 沒有 `-r` 時只掃 `tests/*.bats`）→ 若新增 `tests/<子目錄>/`，**兩邊一起少算＝靜默綠**，
  # 不是「大聲紅」。故下方先加反向鎖：tests/ 必須維持平坦，否則本條直接紅（TMO-047 追蹤擴充）。
  local nested
  # round H P3-7：`find` 本身失敗（缺 find／tests/ 不存在）時，管線末 `head` 的 rc 會蓋掉錯誤
  # → 反向鎖靜默失效。故先驗 find 自己的 rc（`head` 不影響 `if` 判斷）。
  if ! nested=$(find "$REPO_ROOT/tests" -mindepth 2 -name '*.bats' 2>/dev/null); then
    echo "FAIL: 反向鎖無法列舉 tests/ 子目錄（find 失敗）→ 鎖沒生效，請檢查環境" >&2
    return 1
  fi
  nested=$(printf '%s\n' "$nested" | head -5)
  [ -z "$nested" ] || {
    echo "FAIL: tests/ 出現子目錄探針 → 普查與 bats --count 皆非遞迴，會靜默漏算：" >&2
    echo "$nested" >&2
    echo "修法：把普查 glob 擴為 tests/**/*.bats 並讓 CI 跑 bats -r tests/，或把探針移回 tests/ 頂層" >&2
    return 1
  }
  # TMO-026 的病因：宣告 N 條、實跑 N-3 條，報表看起來全綠。這是那整類問題的一般性防線。
  # (0) 先自我測試普查函式：heredoc 內的 @test 不算、字串裡的 << 不誤判。
  #     fixture 一律用 printf 逐行寫（用 heredoc 寫會被 bats 前處理器改寫成
  #     bats_test_function 形式，就不是要測的形狀了）。
  local st="$BATS_TEST_TMPDIR/census-self-test.bats"
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' '@test "real one" { true; }'
    printf '%s\n' "cat > /dev/null <<'BODY'"
    printf '%s\n' '@test "inside heredoc" { true; }'
    printf '%s\n' 'BODY'
    printf '%s\n' "cat > /dev/null <<'BODY2' 2>/dev/null"
    printf '%s\n' '@test "inside heredoc with redirect" { true; }'
    printf '%s\n' 'BODY2'
    printf '%s\n' "cat > /dev/null <<'BODY3' 2>/dev/null"
    printf '%s\n' '@test "inside heredoc3" { true; }'
    printf '%s\n' 'BODY3'
    printf '%s\n' "echo \"<<'NOT-A-HEREDOC'\" end"
    printf '%s\n' '@test "real two" { true; }'
    printf '%s\n' "awk 'BEGIN { print \"<<'X'\" }'"
    printf '%s\n' '@test "real three" { true; }'
  } > "$st"
  local stn
  stn=$(count_declared_tests "$st")
  [ "$stn" -eq 3 ] || {
    echo "FAIL: 普查函式自我測試失敗（期望 3，得到 ${stn}）→ 抽取器壞了" >&2
    sed -n l "$st" >&2
    return 1
  }
  # (1) 普查：宣告數必須等於 bats 自報的計畫數
  # 2026-10-27 探針 skill-local 化 → 宣告數要包埋 skills/*/tests/（兩邊都要同 bats 自報數一致）
  local declared=0 f n planned_repo planned_skill
  for f in "$REPO_ROOT"/tests/*.bats "$REPO_ROOT"/skills/*/tests/*.bats; do
    [ -f "$f" ] || continue
    n=$(count_declared_tests "$f")
    declared=$((declared + n))
  done
  run bash -c "cd \"$REPO_ROOT\" && bats --count tests/"
  [ "$status" -eq 0 ] || {
    echo "FAIL: bats --count 失敗：$output" >&2
    return 1
  }
  planned_repo="$output"
  run bash -c "cd \"$REPO_ROOT\" && bats --count skills/*/tests/"
  [ "$status" -eq 0 ] || {
    echo "FAIL: bats --count skills/*/tests/ 失敗：$output" >&2
    return 1
  }
  planned_skill="$output"
  local planned=$((planned_repo + planned_skill))
  [ "$declared" -ge 400 ] || {
    echo "FAIL: 只數到 $declared 個 @test（<400）→ 抽取器可能壞了（防空過）" >&2
    return 1
  }
  [ "$planned" -eq "$declared" ] || {
    echo "FAIL: 宣告 $declared 條 @test，但 bats 只認得 $planned 條 → 有測試沒在跑" >&2
    return 1
  }
  # (2) canary：CJK 名稱在**目前 locale** 下會不會被 bats 丟棄（printf 寫檔，避免前處理器改寫）
  #
  # ⚠️ **TMO-074 更正**：舊版斷言寫「CJK 名必須跑 2 條」——那是 LC_ALL=C 下的觀察。
  #    在 **bash 3.2 + UTF-8 locale** 下 bats **會丟棄**它們（rc=1、實跑 0 條），所以舊斷言在 bash 5.x 那種
  #    locale 下必然紅，且紅的原因被誤讀成「canary 檔壞掉」。
  #    正確斷言：**先決定性驗證 LC_ALL=C 下必定會跑**（證明不是 bats 不支援 CJK），
  #    再依**目前 locale 的 charset** 決定期望值 → 跨平台可重現、不會靠 locale 名稱硬編。
  local mini="$BATS_TEST_TMPDIR/cjk-canary.bats"
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' '@test "中文開頭名稱" { true; }'
    printf '%s\n' '@test "ENV-CJK: 尾綴中文名稱" { true; }'
  } > "$mini"
  # (2b) 斷言 CJK 名 fixture 的行為是**明確的兩種狀態之一**，且 LC_ALL=C 錨點恆定。
  #
  #     為什麼不用「locale 的 [[:alnum:]] 含不含 CJK」當判別式：**那不是開關**。
  #     真實開關是「bash 版本 × locale」：bash 3.2 + UTF-8 locale 會丟棄，
  #     bash 5.x（CI）在任何 locale 都不丟棄 —— 但 libc 的 alnum 類別在兩者都是
  #     「含 CJK」。用 alnum 當預測會在 bash 5 上誤判（實測踩過）。
  #
  #     所以這裡只斷言**可觀察且穩定**的兩件事：
  #       ① LC_ALL=C 錨點：CJK 名**必定會跑**（所有 bash 版本都如此，實測 3.2 / 5.3）
  #       ② 當前環境：必須是「全跑(2)」或「全丟棄(0)」之一 —— **不得部分丟棄**
  #          （部分丟棄＝bats 行為異常，那才是真的 bug）
  #     並印出當前屬於哪一種，讓讀 log 的人知道自己的環境落在哪一側。
  local ran_c ran_amb
  ran_c=$(LC_ALL=C bats "$mini" 2>/dev/null | grep -c '^ok ' || true)
  [ "$ran_c" -eq 2 ] || {
    echo "FAIL: LC_ALL=C 下 CJK 名探針應跑 2 條，實跑 $ran_c 條（bats 行為與已知機制不符）" >&2
    return 1
  }
  run env -u BATS_TMPDIR -u BATS_RUN_TMPDIR -u BATS_SUITE_TMPDIR -u BATS_FILE_TMPDIR \
      -u BATS_TEST_TIMEOUT -u BATS_TEST_RETRIES \
      -u BATS_TEST_NAME -u BATS_TEST_NUMBER -u BATS_TEST_DESCRIPTION \
      -u BATS_TEST_FILENAME -u BATS_LINENO -u BATS_RUN_COMMAND \
      bats "$mini"
  ran_amb=$(printf '%s\n' "$output" | grep -c '^ok ' || true)
  case "$ran_amb" in
    2) echo "OK: 當前環境下 CJK 名探針會跑（此環境不受 bash 3.2 的丟棄影響）" >&2 ;;
    0) echo "OK: 當前環境下 CJK 名探針被 bats 丟棄（bash 3.2 + UTF-8 locale → 本機假綠；repo 已一律用純 ASCII 命名）" >&2 ;;
    *)
      echo "FAIL: CJK 名探針被**部分**丟棄（宣告 2 條、實跑 $ran_amb 條）→ bats 行為異常" >&2
      return 1
      ;;
  esac
  echo "OK: 宣告 $declared 條 == bats 計畫 $planned 條；CJK canary 依 locale 正確判定" >&2
}

@test "ENV-EQ-10: install docs teach the pinned bats version (CI pins it, local must not drift)" {
  # round E P2-9：CI 已釘 bats v1.14.0，但 install-reference / CONTRIBUTING 仍推薦
  # 發行版安裝（apt 1.10 / brew 版本浮動）→ 本機仍是漂移來源。
  local checked=0 f
  for f in "$REPO_ROOT/docs/install-reference.md" "$REPO_ROOT/CONTRIBUTING.md"; do
    [ -f "$f" ] || {
      echo "FAIL: 缺檔案 $f" >&2
      return 1
    }
    grep -q 'v1\.14\.0' "$f" || {
      echo "FAIL: $f 沒有提到釘版版本 v1.14.0（本機安裝說明必須與 CI 一致）" >&2
      return 1
    }
    grep -q 'bats-core/install\.sh' "$f" || {
      echo "FAIL: $f 沒有教 bats-core/install.sh（只寫版本不寫怎麼裝＝教不動）" >&2
      return 1
    }
    # 反向鎖：不得再推薦發行版 bats。工具名拆開寫 → 免得被 lint-probe-tools.py 誤判成
    # 本測試「直接執行 brew」（那條鎖掃 tests/ 全域，分不出字串與執行）。
    # round F P2-2：原 pattern 要求 `sudo`，抓不到本輪被移除的舊寫法 `apt install bats`（無 sudo）。
    # 先自我測試 pattern 本身（正例必中、反例不中）——否則「鎖比宣稱弱」沒人看得出來。
    local bad_pat
    bad_pat="($(printf 'b%s' rew)[[:space:]]+install[[:space:]]+bats|(sudo[[:space:]]+)?apt(-get)? install[^#]*[[:space:]]bats)"
    local _case
    for _case in "sudo apt install bats" "apt install bats" "apt-get install -y bats"; do
      printf '%s' "$_case" | grep -qE "$bad_pat" || {
        echo "FAIL: 反向鎖 pattern 漏抓「${_case}」→ 鎖比宣稱弱（self-test）" >&2
        return 1
      }
    done
    printf '%s' "apt install poppler-utils" | grep -qE "$bad_pat" && {
      echo "FAIL: 反向鎖 pattern 誤抓無關套件（apt install poppler-utils）" >&2
      return 1
    }
    if grep -nE "$bad_pat" "$f"; then
      echo "FAIL: $f 仍推薦發行版 bats（版本會漂移）→ 請改教 git clone --branch v1.14.0 + install.sh" >&2
      return 1
    fi
    checked=$((checked + 1))
  done
  [ "$checked" -eq 2 ] || {
    echo "FAIL: 只檢查了 $checked 個檔案（<2）→ 掃描清單可能壞了" >&2
    return 1
  }
  echo "OK: 2 份本機安裝文件都教釘版 bats" >&2
}

# ENV-EQ-11（2026-10-27 探針 skill-local 化後重寫）：探針跟 skill 搬入 `skills/<name>/tests/`
# → CI 必須真係跑嗰批（否則改壞咗冇人擋）；改動單一 skill 時可用 `bash scripts/test-skill.sh <name>` 淨跑。
@test "ENV-EQ-11: skill-local tests exist and CI really runs them" {
  local f files=() n=0
  while IFS= read -r f; do
    files+=("$f"); n=$((n + 1))
  done < <(cd "$REPO_ROOT" && find skills -path '*/tests/*.bats' | sort)
  [ "$n" -ge 1 ] || {
    echo "FAIL: 搵唔到任何 skill 自帶測試 → 探針被搬走／刪晒" >&2
    return 1
  }
  local ci="$REPO_ROOT/.github/workflows/ci.yml" hits
  hits=$(grep -cE 'run: bats skills/\*/tests/\*\.bats' "$ci" || true)
  [ "$hits" -eq 1 ] || {
    echo "FAIL: ci.yml 冇（或重複）skill-local 測試步驟（命中 $hits 次）→ 改壞咗冇人擋" >&2
    return 1
  }
  # 單 skill 跑法（用戶要求：改指定 skill 唔好等成 repo）→ 腳本必須存在且列得出 skill
  [ -f "$REPO_ROOT/scripts/test-skill.sh" ] || {
    echo "FAIL: 缺 scripts/test-skill.sh（單 skill 跑法）" >&2
    return 1
  }
  run bash "$REPO_ROOT/scripts/test-skill.sh" --list
  [[ "$status" -eq 0 ]] || { echo "FAIL: test-skill.sh --list 唔係 0 退出" >&2; return 1; }
  # 每個有 tests/ 嘅 skill 都必須喺 --list 出現（唔寫死 skill 名 → 合併／拆分後唔會失效）
  local s name
  for s in "$REPO_ROOT"/skills/*/; do
    [ -d "${s}tests" ] || continue
    name="$(basename "$s")"
    [[ "$output" == *"$name"* ]] || {
      echo "FAIL: test-skill.sh --list 唔見 '$name' → 佢有 tests/ 但列唔出" >&2
      return 1
    }
  done
  # 行為自證（唔係 grep 文字鎖）：喺 temp git repo 起一個「淨跑一個 skill」嘅場景
  #   ① 嗰個 skill 嘅探針紅 → 整體 rc=1；② 未知 skill → rc=2（用法錯誤）
  local tmprepo="$BATS_TEST_TMPDIR/skillrepo"
  mkdir -p "$tmprepo/scripts" "$tmprepo/skills/demo-skill/tests"
  cp "$REPO_ROOT/scripts/test-skill.sh" "$tmprepo/scripts/"
  # ⚠️ 測試名同 body 要合法（bats 會把 `@test "name" {` 轉成 shell function 名：
  #    名入面有空格／冒號 → 變成非法 function 名 → **parse error**，紅嘅原因就唔係「測試紅」）
  printf '#!/usr/bin/env bats\n@test "demo_fails" {\n  false\n}\n' \
    > "$tmprepo/skills/demo-skill/tests/demo.bats"
  ( cd "$tmprepo" && git init -q )
  run bash -c "cd '$tmprepo' && bash scripts/test-skill.sh demo-skill"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 單 skill 嘅探針紅 → test-skill.sh 應該 rc=1（實際 ${status}）" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"demo-skill"* ]] || {
    echo "FAIL: 輸出應該講明係邊個 skill 紅" >&2
    return 1
  }
  run bash -c "cd '$tmprepo' && bash scripts/test-skill.sh no-such-skill"
  [ "$status" -eq 2 ] || {
    echo "FAIL: 未知 skill 應該 rc=2（用法錯誤；實際 ${status}）" >&2
    return 1
  }
}

# ENV-EQ-12（L4 擴量）：把 TMO-047 的 bug 類別一般化——「探針存在但沒有任何 CI 步驟跑到它」。
# 目前 repo 有兩條執行路徑：`bats tests/`（僅頂層，非遞迴）同 `bats skills/*/tests/*.bats`（skill 自帶測試）。
# 任何落在其他位置的 `.bats` 都不會被 CI 執行 → 改壞了沒人擋（假綠）。
@test "ENV-EQ-12: no orphan .bats outside the two CI execution paths" {
  local all orphan=""
  # 用 find（而非 git ls-files）才能抓到**未追蹤**的 orphan（例：scripts/orphan.bats）；
  # 但 find 不讀 gitignore，跑過 ./install.sh 的開發者會在本機副本樹（例：`.agents/`、`tmp/`、
  # PoC 的 `.venv/`）看到偽紅（reviewer round J P2-1）。故用 `git check-ignore` 逐檔判斷
  #（依 gitignore 事實，非硬編排除清單）：git check-ignore **預設會看 index**，
  # 所以「被追蹤」的檔永遠不算 ignored → 未來若有被追蹤 .bats 落在那些目錄也不會被誤排除（M53 實證）。
  all=$(cd "$REPO_ROOT" && find . -name '*.bats' -not -path './.git/*' | sed 's|^\./||' | sort \
    | while IFS= read -r f; do git check-ignore -q -- "$f" || printf '%s\n' "$f"; done)
  [ -n "$all" ] || { echo "FAIL: 找不到任何 .bats（repo root 指錯？）" >&2; return 1; }
  local f n=0
  # 用 while-read（herestring，不開子 shell）而非 `for f in $all`：後者未加引號，
  # 檔名含空白會被拆成兩個 token → 偽紅（reviewer round K P3-4）。
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    n=$((n + 1))
    # 注意：case 的 `*` 會跨 `/`（`tests/*.bats` 也會匹配 `tests/sub/x.bats`），
    # 但 CI 的 `bats tests/` 是**非遞迴**的 → 必須用精確 regex 才不會漏放嵌套檔。
    if [[ "$f" =~ ^tests/[^/]+\.bats$ ]]; then
      continue                                     # CI: bats tests/
    elif [[ "$f" =~ ^skills/[^/]+/tests/[^/]+\.bats$ ]]; then
      continue                                     # CI: bats skills/*/tests/*.bats
    else
      orphan="$orphan $f"
    fi
  done <<< "$all"
  [ "$n" -ge 25 ] || { echo "FAIL: 只列舉到 $n 個 .bats（<25）→ 列舉器壞了或路徑漂移" >&2; return 1; }
  [ -z "$orphan" ] || {
    echo "FAIL: 下列 .bats 不在任何 CI 執行路徑（orphan → 改了不會擋）：$orphan" >&2
    echo "修法：移到 tests/（頂層），或替它加一條 CI 步驟＋對應鎖" >&2
    return 1
  }
  echo "OK: $n 個 .bats 全部落在 CI 執行路徑（tests/ 或 skills/*/tests/）" >&2
}

# ENV-EQ-13（L5 擴量）：Gate 2 的 shellcheck 掃描面必須是「自我列舉」且真的涵蓋全部 shell 檔。
# 起因：原指令只列 lib/log.sh + skills/dav-wiki/scripts/*.sh + scripts/ci/*.sh，
# 漏掉 install.sh、lib/install/*.sh（6 支，實測有 8 個 SC2148 error）、PoC 腳本等，
# 於是「本機 Gate 2 全綠」對這些檔毫無意義。本條鎖兩件事：
#   (1) 每個被追蹤的 *.sh / *.bash 都在前 5 行宣告自己的 shell（shebang 或 `# shellcheck shell=`）
#       ——這是 SC2148 那一類「無 shebang 被 source 的函式庫」的靜態等價鎖，不需要 shellcheck 執行檔。
#   (2) CONTRIBUTING.md 的 Gate 2 指令必須用 `git ls-files '*.sh' '*.bash'` 自我列舉
#       ——避免又回到硬編清單而漏檔。
@test "ENV-EQ-13: every tracked shell file declares its shell and Gate 2 enumerates them all" {
  local files f missing="" n=0
  files=$(cd "$REPO_ROOT" && git ls-files '*.sh' '*.bash' | sort)
  [ -n "$files" ] || { echo "FAIL: 找不到任何被追蹤的 shell 檔（repo root 指錯？）" >&2; return 1; }
  for f in $files; do
    n=$((n + 1))
    if head -5 "$REPO_ROOT/$f" | grep -qE '^#!|^# shellcheck shell='; then
      continue
    fi
    missing="$missing $f"
  done
  [ "$n" -ge 20 ] || { echo "FAIL: 只列舉到 $n 個 shell 檔（<20）→ 列舉器壞了" >&2; return 1; }
  [ -z "$missing" ] || {
    echo "FAIL: 下列 shell 檔沒宣告 shell（缺 shebang 或 '# shellcheck shell='）：$missing" >&2
    echo "修法：檔頭加 '# shellcheck shell=bash  # 被 source 的函式庫' 或補 shebang（否則 shellcheck SC2148）" >&2
    return 1
  }

  local doc="$REPO_ROOT/CONTRIBUTING.md" cmd
  cmd=$(grep -E "^shellcheck .*git ls-files" "$doc" || true)
  [ -n "$cmd" ] || {
    echo "FAIL: CONTRIBUTING.md 的 Gate 2 shellcheck 指令不是自我列舉（找不到 'shellcheck ... git ls-files'）→ 硬編清單會漏檔" >&2
    return 1
  }
  echo "$cmd" | grep -qF "*.sh" && echo "$cmd" | grep -qF "*.bash" || {
    echo "FAIL: Gate 2 指令未同時涵蓋 '*.sh' 與 '*.bash'：$cmd" >&2
    return 1
  }
  echo "OK: $n 個 shell 檔都宣告 shell，Gate 2 指令自我列舉" >&2
}

# ENV-EQ-14（L6 擴量）：被追蹤的 .py / .json 靜態語法鎖。
# 起因：`check-python-heredocs.sh` 只驗「嵌在 shell 裡的 Python heredoc」；repo 內被追蹤的
# .py（30 支）與 .json（7 支）若沒被任何測試 import／讀取，寫壞了不會有任何東西擋。
# 這條不需要額外套件（純 stdlib），也不寫出 __pycache__（用 ast.parse 而非 py_compile）。
@test "ENV-EQ-14: every tracked .py parses and every tracked .json loads" {
  local py js
  py=$(cd "$REPO_ROOT" && git ls-files '*.py' | sort)
  js=$(cd "$REPO_ROOT" && git ls-files '*.json' | sort)
  local npy njs
  npy=$(echo "$py" | grep -c . || true)
  njs=$(echo "$js" | grep -c . || true)
  [ "$npy" -ge 25 ] || { echo "FAIL: 只列舉到 $npy 支 .py（<25）→ 列舉器壞了" >&2; return 1; }
  [ "$njs" -ge 5 ] || { echo "FAIL: 只列舉到 $njs 支 .json（<5）→ 列舉器壞了" >&2; return 1; }

  run env PYTHONDONTWRITEBYTECODE=1 python3 -c '
import ast, json, sys
bad = []
mode = sys.argv[1]
for f in sys.argv[2:]:
    try:
        if mode == "py":
            ast.parse(open(f, encoding="utf-8").read(), filename=f)
        else:
            json.load(open(f, encoding="utf-8"))
    except Exception as e:
        bad.append("%s: %s: %s" % (mode, f, e))
print("\n".join(bad))
sys.exit(1 if bad else 0)
' py $py
  [ "$status" -eq 0 ] || { echo "FAIL: 有 .py 語法錯誤 → $output" >&2; return 1; }

  run env PYTHONDONTWRITEBYTECODE=1 python3 -c '
import ast, json, sys
bad = []
mode = sys.argv[1]
for f in sys.argv[2:]:
    try:
        if mode == "py":
            ast.parse(open(f, encoding="utf-8").read(), filename=f)
        else:
            json.load(open(f, encoding="utf-8"))
    except Exception as e:
        bad.append("%s: %s: %s" % (mode, f, e))
print("\n".join(bad))
sys.exit(1 if bad else 0)
' json $js
  [ "$status" -eq 0 ] || { echo "FAIL: 有 .json 解析失敗 → $output" >&2; return 1; }

  echo "OK: $npy 支 .py 全數 ast.parse 通過、$njs 支 .json 全數 json.load 通過" >&2
}

# ENV-EQ-15（L7 擴量）：禁止「永遠不可能失敗」的空過斷言。
# 起因：`skills/dav-wiki/tests/ci-linux.bats` 原有一條 `if Linux then skip else [ true ]` —— 在任何平台都不可能紅，
# 是純裝飾的綠燈（正是「探針禁空過」要擋的類別）。現況已改成真斷言（date 回溯 vs Python），
# 這條鎖則防止再寫回來。範圍：repo 內所有 .bats。
@test "ENV-EQ-15: no tautological assertions in any .bats" {
  local files n=0 hits="" f
  files=$(cd "$REPO_ROOT" && { git ls-files 'tests/*.bats'; git ls-files 'skills/*/tests/*.bats'; } | sort)
  [ -n "$files" ] || { echo "FAIL: 找不到任何 .bats（repo root 指錯？）" >&2; return 1; }
  for f in $files; do
    n=$((n + 1))
    local h
    # 先剝掉行尾註解再比對（原本的 `| grep -v '#'` 是死碼：anchored pattern 不可能命中含 `#` 的行），
    # 這樣連 `true  # 待補` 這種也抓得到。
    h=$(sed 's/#.*$//' "$REPO_ROOT/$f" | grep -nE '^[[:space:]]*(\[\[?[[:space:]]*true[[:space:]]*\]\]?|true|:)[[:space:]]*$' || true)
    [ -z "$h" ] || hits="$hits
$f:$h"
  done
  [ "$n" -ge 25 ] || { echo "FAIL: 只掃到 $n 支 .bats（<25）→ 列舉器壞了" >&2; return 1; }
  [ -z "$hits" ] || {
    echo "FAIL: 下列 .bats 有空過斷言（永遠不會失敗 → 假綠）：$hits" >&2
    echo "修法：刪掉該行，或改成真斷言（檢查實際輸出／狀態碼）" >&2
    return 1
  }
  echo "OK: $n 支 .bats 都沒有空過斷言" >&2
}

# ENV-EQ-16（L8 擴量）：被追蹤的文字檔必須以換行結尾（binary 除外）。
# 起因：量測發現 35 個被追蹤的文字檔（shell 腳本、.bats、.json…）**檔尾缺換行**，
# 這種檔案會讓 `cat`/`git diff`/append 行為出錯（本輪 mutation M39/M40 就因為它而靜默沒套上）。
# binary fixture（docx/png/pptx）以 NUL byte 嗅探排除，不強加換行。
#
# ⚠️ 第一版是**假綠**：用 bash `grep -q $'\x00'` 做 NUL 嗅探，但 bash 的 `$'\x00'` 會變成**空字串**
# → `grep -q ''` 對每個檔都命中 → 全部被當 binary 跳過（M43 沒咬才發現）。改用 Python 嗅探。
@test "ENV-EQ-16: every tracked text file ends with a newline" {
  local out n
  run env PYTHONDONTWRITEBYTECODE=1 python3 - "$REPO_ROOT" <<'PYEOF'
import pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
files = subprocess.run(["git", "-C", str(root), "ls-files"], capture_output=True, text=True).stdout.split()
bad, n, bins = [], 0, 0
for f in files:
    p = root / f
    if not p.is_file() or p.stat().st_size == 0:
        continue
    n += 1
    b = p.read_bytes()
    if b"\x00" in b[:8192]:      # binary 嗅探（docx/png/pptx…）
        bins += 1
        continue
    if not b.endswith(b"\n"):
        bad.append(f)
print("scanned=%d binary=%d" % (n, bins))
if bad:
    print("FAIL: 檔尾缺換行：" + " ".join(bad))
    sys.exit(1)
PYEOF
  [ "$status" -eq 0 ] || { echo "FAIL: $output" >&2; return 1; }
  n=$(echo "$output" | sed -n 's/^scanned=\([0-9]*\).*/\1/p')
  [ "${n:-0}" -ge 100 ] || { echo "FAIL: 只掃到 ${n:-0} 檔（<100）→ 列舉器壞了" >&2; return 1; }
  echo "OK: $n 個被追蹤檔通過換行檢查（binary 以 NUL 嗅探排除）" >&2
}

# ENV-EQ-17（2026-10-05 CI 首跑）：`$var` 緊接非 ASCII 字元 —— bash 3.2 + UTF-8 locale 陷阱。
# 起因：macOS CI leg（/bin/bash 3.2 + runner 的 UTF-8 locale）下，`scripts/ci/check-skill-size.sh:51`
# 的 `$worst_file）` 被 bash 3.2 解析成變數 `$worst_file\xef` → `set -u` 下 `unbound variable`
# → 只在 macOS leg 紅；本機 bash 5 完全看不到（本機全綠 ≠ CI 全綠）。
# 全 repo 同類寫法共 39 處已修（一律改 `${var}`，語意相同、變數名有邊界）。
# 靜態鎖實作在 `scripts/ci/lint-shell-var-nonascii.py`（獨立檔，避免探針掃到自己的說明文字）。
#
# 盲點修正（2026-10-05 晚）：鎖原本只掃 `git ls-files`（已追蹤）→ **新檔在 commit 前是 untracked**，
# 於是「本機全綠、push 後 CI 才紅」。TMO-064／065 的 `skills/pptx-slim/tests/pptx-slim-images.bats`（`$after（`、`$name（`）
# 與 `tests/mutant-must-die.bats`（`$status）`）就是這樣溜進 commit 的（同日稍早另有「新檔缺檔尾換行」
# 被 ENV-EQ-16 在 clean clone 咬到，同一個病）。改成 `git ls-files -co --exclude-standard`（含未追蹤、不含 gitignore）。
@test "ENV-EQ-17: no shell or CI file puts a non-ASCII byte right after a variable expansion" {
  local lock="$REPO_ROOT/scripts/ci/lint-shell-var-nonascii.py"
  [ -f "$lock" ] || {
    echo "FAIL: 缺 $lock" >&2
    return 1
  }
  run python3 "$lock" --self-test
  [ "$status" -eq 0 ] || {
    echo "FAIL: 鎖的自我測試沒過：$output" >&2
    return 1
  }
  run python3 "$lock" "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    echo "FAIL: $output" >&2
    return 1
  }
  echo "OK: $output" >&2
}

# ENV-EQ-18（2026-10-05 CI 首跑，NYH-6 決策 A）：CI 必須真的跑 shellcheck，且語法檢查要自我列舉。
# 起因：`ci.yml` 完全沒有 shellcheck（「本機 Gate 2 全綠」不等於 CI 會擋），而 `Verify bash syntax`
# 只 glob 硬編子集 `skills/dav-wiki/scripts/*.sh` → 漏掉 `install.sh`、`lib/**`、`scripts/ci/**`、
# `skills/*/PoC/**`、`tests/helpers/**`（同 TMO-038 ④ 的「硬編清單＝漏抓」病根）。
@test "ENV-EQ-18: CI runs shellcheck and the syntax step enumerates all tracked shell files" {
  local ci="$REPO_ROOT/.github/workflows/ci.yml"
  [ -f "$ci" ] || {
    echo "FAIL: 缺 $ci" >&2
    return 1
  }
  # 只取 `test` job 的區塊（下一個頂層 job key 之前），避免 lint-only job 的內容混淆判定
  local block
  block=$(awk '/^  test:$/ { on = 1; next } /^  [A-Za-z0-9_-]+:$/ { on = 0 } on' "$ci")
  [ -n "$block" ] || {
    echo "FAIL: 抓不到 ci.yml 的 test job 區塊（anchor 漂移？）" >&2
    return 1
  }
  printf '%s\n' "$block" | sed 's/#.*$//' | grep -qF "shellcheck -x -S style \$(git ls-files '*.sh' '*.bash')" || {
    echo "FAIL: test job 沒有跑「自我列舉的 shellcheck」（NYH-6 決策 A）" >&2
    return 1
  }
  # 版本漂移可診斷（reviewer 輕量確認輪 P3-2）：CI 要先印 shellcheck 版本——
  # 本機 0.11.0 已不報 SC2002、ubuntu apt 0.9.x 仍會報，曾發生「本機綠、CI 紅」。
  printf '%s\n' "$block" | sed 's/#.*$//' | grep -qF 'shellcheck --version' || {
    echo "FAIL: shellcheck 步驟沒有先印版本（版本漂移時無法從 log 診斷）" >&2
    return 1
  }
  if printf '%s\n' "$block" | sed 's/#.*$//' | grep -qF 'skills/dav-wiki/scripts/*.sh'; then
    echo "FAIL: Verify bash syntax 還是硬編子集 glob（漏 install.sh／lib／scripts/ci／PoC／helpers）" >&2
    return 1
  fi
  printf '%s\n' "$block" | sed 's/#.*$//' | grep -qF "git ls-files '*.sh' '*.bash'" || {
    echo "FAIL: 找不到自我列舉語法檢查（預期 git ls-files '*.sh' '*.bash'）" >&2
    return 1
  }
  # 下限（reviewer round L P2-1）：語法步驟必須有列舉下限，列舉空掉時不得印 OK 假綠
  printf '%s\n' "$block" | sed 's/#.*$//' | grep -qE '\[ "\$n" -ge [0-9]+ \]' || {
    echo "FAIL: Verify bash syntax 沒有列舉下限（git ls-files 空掉時會印 OK: 0 shell files 假綠）" >&2
    return 1
  }
  # 反假綠：這兩步不得用 || true / continue-on-error 裝飾（先剝註解，否則註解提及也會偽紅）
  if printf '%s\n' "$block" | sed 's/#.*$//' | grep -qE '\|\|[[:space:]]*true|continue-on-error'; then
    echo "FAIL: test job 內出現 || true 或 continue-on-error（假綠構造）" >&2
    return 1
  fi
  echo "OK: CI 有自我列舉的 shellcheck＋語法檢查，且無假綠裝飾" >&2
}

# ENV-EQ-19（2026-10-05 CI 首跑）：`scripts/ci/*.sh` 必須在「每一個本機 bash 版本」下都跑得過。
# 起因：SSG-3 只在 macOS leg 紅，因為本機 PATH 上的 bash 是 5.x；CI 的 macOS leg 用 3.2。
# 這是 ENV-EQ-2（wiki-cleanup 套件逐 bash 版本）的「護欄腳本版」——把 CI 才咬得到的
# 版本差異搬回本機咬（先量測，再斷言；locale 以實際可用者為準並印出來當證據）。
@test "ENV-EQ-21: every skill frontmatter is valid YAML (description must be one line or a block scalar)" {
  # 2026-10-27 事故：折行時把 `description:` 折成 2 行（plain scalar 唔准跨行）
  #   → YAML 解析成「隱式 map key」→ **成個 skill 讀唔到**（frontmatter 壞，system 報 skill conflict）
  # 規則：`description:` 之後嘅續行必須以 `>-` / `|` 開頭（block scalar），否則 description 必須單行。
  local f ok=0
  for f in "$REPO_ROOT"/skills/*/SKILL.md; do
    ok=1
    python3 - "$f" <<'PYEOF'
import re, sys
path = sys.argv[1]
lines = open(path, encoding="utf-8").read().splitlines()
if not lines or lines[0].strip() != "---":
    print(f"FAIL: {path} 冇 frontmatter"); sys.exit(1)
end = next((i for i in range(1, len(lines)) if lines[i].strip() == "---"), None)
if end is None:
    print(f"FAIL: {path} frontmatter 冇收尾 ---"); sys.exit(1)
fm = lines[1:end]
desc = [i for i, l in enumerate(fm) if l.startswith("description:")]
if len(desc) != 1:
    print(f"FAIL: {path} frontmatter 要恰好 1 個 description（現 {len(desc)}）"); sys.exit(1)
i = desc[0]
rest = fm[i][len("description:"):].strip()
if rest in (">-", "|", ">", "|-", "|+"):
    pass                                   # block scalar → 續行合法
elif rest:
    # 單行 scalar → 下一行唔可以係續行（要係新 key）
    if i + 1 < len(fm) and fm[i + 1].strip() and not re.match(r"^[A-Za-z_][\w-]*:", fm[i + 1]):
        print(f"FAIL: {path} 嘅 description 跨行（plain scalar 唔准跨行）→ 用 '>-' block scalar"); sys.exit(1)
print("OK")
PYEOF
    [ "$?" -eq 0 ] || return 1
  done
  [ "$ok" -eq 1 ] || { echo "FAIL: 搵唔到任何 skills/*/SKILL.md" >&2; return 1; }
  echo "OK: 所有 skill frontmatter 合法" >&2
}

@test "ENV-EQ-19: every scripts/ci guard script runs clean under every local bash version" {
  local vers="$BATS_TEST_TMPDIR/bash-versions.tsv"
  collect_bash_versions "$vers" || {
    echo "FAIL: 收不到任何可用的 bash（環境異常）" >&2
    return 1
  }
  # 挑一個 UTF-8 locale（bash 3.2 的變數名吞位元組行為只在多位元組 locale 下出現）
  local loc="" cand
  for cand in C.UTF-8 en_US.UTF-8 zh_TW.UTF-8; do
    if [ -z "$loc" ] && LC_ALL="$cand" bash -c 'echo ok' >/dev/null 2>&1; then loc="$cand"; fi
  done
  [ -n "$loc" ] || {
    echo "FAIL: 找不到任何 UTF-8 locale（C.UTF-8／en_US.UTF-8／zh_TW.UTF-8）→ 這條鎖會變假綠" >&2
    echo "      修復（macOS）：系統設定加入 en_US.UTF-8；CI：ubuntu 內建 C.UTF-8" >&2
    return 1
  }
  local scripts n=0 s v bin rc out
  scripts=$(cd "$REPO_ROOT" && git ls-files 'scripts/ci/*.sh')
  [ -n "$scripts" ] || {
    echo "FAIL: 找不到 scripts/ci/*.sh（列舉器壞了）" >&2
    return 1
  }
  n=$(printf '%s\n' "$scripts" | grep -c .)
  [ "$n" -ge 3 ] || {
    echo "FAIL: 只列舉到 $n 支護欄腳本（防空過；預期 >= 3）" >&2
    return 1
  }
  local ran=0 vcount=0
  vcount=$(grep -c . "$vers")
  # 防空過（reviewer 輕量確認輪 P3-2）：版本清單空掉時 `ran == n×0` 會平凡成立
  [ "$vcount" -ge 1 ] || { echo "FAIL: 版本清單是空的（collect_bash_versions 壞了）" >&2; return 1; }
  echo "  本機 bash 版本清單（$vcount 個）：$(cut -f1 "$vers" | tr '\n' ' ')" >&2
  while IFS=$'\t' read -r v bin; do
    for s in $scripts; do
      if out=$(cd "$REPO_ROOT" && env LC_ALL="$loc" "$bin" "$s" 2>&1); then rc=0; else rc=$?; fi
      if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
        echo "FAIL: bash $v 跑 $s → rc=${rc}（輸出 ${#out} 字元）" >&2
        printf '%s\n' "$out" | head -6 >&2
        return 1
      fi
      ran=$((ran + 1))
    done
  done < "$vers"
  # 每一個（腳本 × 版本）組合都必須跑到（reviewer round L P2-2）：不然「只跑了一個版本」也會綠
  [ "$ran" -eq $((n * vcount)) ] || {
    echo "FAIL: 只跑了 $ran 次，預期 $((n * vcount)) 次（$n 腳本 × $vcount 版本）→ 有組合沒跑到" >&2
    return 1
  }
  # 註：本鎖只保證「每個『本機可用』版本 × 每支腳本都跑到」——若本機沒有 bash 3.x（例如 ubuntu CI），
  #     就不會有 3.2 覆蓋；CI 的 macOS leg 改用 bash 5 後亦同（已揭露於 install-reference.md）。
  echo "OK: $n 支護欄腳本 × $vcount 個本機 bash 版本（locale=${loc}）共 $ran 次皆 rc=0 且有輸出" >&2
}

# ENV-EQ-20（TMO-069 Gate 4 二審 P2-10）：install.sh 必須在「每一個本機 bash 版本」下都跑得過。
# 起因：macOS 內建 /bin/bash 是 3.2，而 install.sh 的 `--agent` 解析會碰到「set -u 下的空陣列」——
#       bash 3.2 對「展開空陣列元素」會報 unbound variable（bash 4.4+ 才修好）。
#       CI 的 macOS leg 裝了 bash 5 且 PATH 優先，所以沒有任何一條 CI 腿會用 3.2 咬到它；
#       這條把「只有 3.2 才會炸」的風險搬回本機咬（與 ENV-EQ-2／ENV-EQ-19 同一套路）。
@test "ENV-EQ-20: install.sh runs clean under every local bash version" {
  local vers="$BATS_TEST_TMPDIR/bash-versions.tsv"
  collect_bash_versions "$vers" || {
    echo "FAIL: 收不到任何可用的 bash（環境異常）" >&2
    return 1
  }
  local vcount
  vcount=$(grep -c . "$vers")
  [ "$vcount" -ge 1 ] || { echo "FAIL: 版本清單是空的（collect_bash_versions 壞了）" >&2; return 1; }
  echo "  本機 bash 版本清單（$vcount 個）：$(cut -f1 "$vers" | tr '\n' ' ')" >&2

  local home v bin rc out ran=0
  while IFS=$'\t' read -r v bin; do
    home="$BATS_TEST_TMPDIR/home-$v"
    mkdir -p "$home"

    # (1) 不給 --agent：AGENT_REQ 是「空陣列」——這正是 bash 3.2 會炸的那條路
    #     （bash 4.4+ 才修好「set -u 下展開空陣列元素」）
    if out=$(env -i \
        HOME="$home" \
        PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
        TERM="xterm" \
        NO_COLOR="1" \
        "$bin" "$REPO_ROOT/install.sh" --global --no-agents-dir --yes 2>&1); then rc=0; else rc=$?; fi
    if [ "$rc" -ne 0 ]; then
      echo "FAIL: bash $v 跑 install.sh（不給 --agent）→ rc=$rc" >&2
      printf '%s\n' "$out" | head -8 >&2
      return 1
    fi
    if [ ! -L "$home/.qoder/AGENTS.md" ]; then
      echo "FAIL: bash ${v}（不給 --agent）沒有產生 ~/.qoder/AGENTS.md symlink" >&2
      return 1
    fi

    # (2) --agent 重複（去重）：兩個相同名稱只能算一次
    home="$BATS_TEST_TMPDIR/home-dedup-$v"
    mkdir -p "$home"
    if out=$(env -i \
        HOME="$home" \
        PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
        TERM="xterm" \
        NO_COLOR="1" \
        "$bin" "$REPO_ROOT/install.sh" --global --agent qoder --agent qoder \
        --no-agents-dir --yes 2>&1); then rc=0; else rc=$?; fi
    if [ "$rc" -ne 0 ]; then
      echo "FAIL: bash $v 跑 install.sh（--agent 重複）→ rc=$rc" >&2
      printf '%s\n' "$out" | head -8 >&2
      return 1
    fi
    if [ ! -L "$home/.qoder/AGENTS.md" ]; then
      echo "FAIL: bash ${v}（--agent 重複）沒有產生 ~/.qoder/AGENTS.md symlink" >&2
      return 1
    fi
    ran=$((ran + 1))
  done < "$vers"

  [ "$ran" -eq "$vcount" ] || {
    echo "FAIL: 只跑了 $ran 次，預期 $vcount 次 → 有版本沒跑到" >&2
    return 1
  }
  echo "OK: install.sh 在 $vcount 個本機 bash 版本下皆 rc=0 且安裝成功" >&2
}
