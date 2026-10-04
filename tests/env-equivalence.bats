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
# 本檔守 8 件事（全部可證偽）：
#   1. 本機必須有 bash 5.x 可用（缺 → 紅＋安裝指令，不 skip）
#   2. `tests/wiki-cleanup.bats` 在**每一個**本機可用 bash 版本下都全綠
#      （PATH shim 真的把 bash 換掉；bash 5.x 這條＝CI 的 ubuntu bash 變體 Gate 3）
#   3. shim 機制本身有效（bats 真的跑在目標 bash 上）→ 否則第 2 條等於在跑預設 bash
#   4. 空陣列 × `set -u` 的行為對照表：逐版本實測並印出（環境等價的證據，不是猜測）
#   5. 探針不得寫入固定 `/tmp/<name>`（要寫就寫 `$BATS_TEST_TMPDIR`；純資料引用標 `TMP-OK`）
#   6. 探針不得直接執行 `gh` / `brew`（工具狀態依賴）
#   7. oracle 子集在「網路黑洞」下必須全綠，且黑洞本身要有 canary 證明真的在擋
#   8. `scripts/ci/` 的護欄腳本不得是「孤兒鎖」（沒有任何探針引用＝等於沒在跑），
#      且每個 `--self-test` 鎖的自我測試都必須自己綠（新增的鎖自動納入＝不會漏）
#
# 註: @test 名稱純英文（homebrew bats 1.14 對 CJK 測試名會靜默丟棄）

setup() {
  load 'helpers/test-env'
  POC_DIR="$REPO_ROOT/skills/regression-guard/PoC"
}

# 找出本機所有可用的 bash（去重：以版本字串為鍵），寫進 $1（TSV: version<TAB>binary）
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
      echo "FAIL: shim 沒生效（期望 $v，得到 $got）" >&2
      return 1
    }
    run env PATH="$shim:$PATH" bats "$REPO_ROOT/tests/wiki-cleanup.bats"
    rc=$status
    printf '%s\n' "$output" > "$BATS_TEST_TMPDIR/wc-$ran.txt"
    okn=$(printf '%s\n' "$output" | grep -c '^ok ' || true)
    notok=$(printf '%s\n' "$output" | grep -c '^not ok ' || true)
    printf '  bash %-28s → rc=%s ok=%s not ok=%s (%s)\n' "$v" "$rc" "$okn" "$notok" "$bin" >&2
    [ "$rc" -eq 0 ] && [ "$notok" -eq 0 ] || {
      echo "FAIL: wiki-cleanup 套件在 bash $v 下紅了（rc=$rc, not ok=$notok）；輸出見 $BATS_TEST_TMPDIR/wc-$ran.txt" >&2
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
    echo "FAIL: 在 bash 5.x shim 下小測試檔沒過（rc=$rc）→ shim 沒生效，ENV-EQ-2 會是假的" >&2
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
    echo "OK: 預設 bash 已是 $defv（>= 5）→ 無 3.x 對照組（本機單一版本）" >&2
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
  echo "OK: 已逐版本量測（上表為環境等價證據；版本清單 = $vers）" >&2
}

# 靜態鎖（TMO-041 ③d/③b）：實作抽在 scripts/ci/ 下，避免探針掃到自己
@test "ENV-EQ-5: no probe writes to a fixed /tmp path (cross-run residue lock)" {
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
    echo "FAIL: 缺 PoC venv（bash skills/regression-guard/PoC/setup-venv.sh）" >&2
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

  local fails="$REPO_ROOT/tests/v2.1-jev-poc.bats"
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
      echo "FAIL: 黑洞網路下 $f 紅了（rc=$rc, ok=$okn, not ok=$notokn）；輸出見 $BATS_TEST_TMPDIR/oracle-$ran.txt" >&2
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
          failed+=("$name：--self-test 沒印通過標記（自我測試可能被掏空）")
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
