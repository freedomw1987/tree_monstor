#!/usr/bin/env bats
#
# tests/probe-name-ascii.bats
#
# TMO-074：守「bats 探針不會被靜默丟棄」。
#
# 病因（2026-10-26 實測確認，bats 1.14.0）：
#   bats 前處理器把 @test 名稱編成 bash 函式名時，用的是 `[[:alnum:]]`。
#   在 **bash 3.2**（macOS 預設 /bin/bash）**且 UTF-8 locale** 下，這個類別會匹配到
#   Unicode 字母（中文／假名／韓文／西里爾…），那些字元被**原樣**留在函式名裡 →
#   函式對不上 → bats 報
#     `bats: unknown test name` + `bats warning: Executed N instead of expected M tests`
#   → **該支探針從未被執行**，但 `bats --count` **仍把它算進去** → 報表看起來全綠（**假綠**）。
#
#   ⚠️ **變因是「bash 版本 × locale」兩個，不是只有 locale**（2026-10-26 二次實測更正）：
#     bash 3.2 + UTF-8 locale → 中文名被丟棄（假綠）   ← 本機 macOS 預設
#     bash 3.2 + C locale   → 中文名會跑
#     bash 5.3 + UTF-8 locale → 中文名會跑              ← **CI 的 ubuntu/macOS 都是 bash 5.x**
#     bash 5.3 + C locale   → 中文名會跑
#   → **CI（bash 5.x）並沒有這個病**；受影響的是**本機 bash 3.2 的開發者**。
#     （這正是 2026-10-23 dav-trust v2.4「resume / stop」那輪交付摘要 §7 當年寫的
#      「在 bash 3.2 本機上，23 支探針檔的守護會被靜默丟棄」——本機當時的根因描述是對的；
#      該交付摘要已於 2026-10-26 減法刪除，內容保留在 git history。）
#
#   實測：тест / テスト / 테스트 / 中文 → bash 3.2 + UTF-8 下全被丟棄；
#        而希臘文、café、全形英數、emoji、→、中文標點 → **不會**被丟棄。
#   → 動工前（2026-10-26 量測）：**21 個探針檔共 134 支**探針名含非 ASCII 字元，
#     其中約 104 支在**本機 bash 3.2** 下從未執行（CI 的 bash 5.x 正常執行）。
#
# 本探針的策略：**預防**（靜態、與 locale／bash 版本都無關）為主 ——
#   讓「本機 bash 3.2」與「CI bash 5.x」**跑同一套探針、看到同一個結果**。
#
# 「bats 到底會不會丟棄 CJK 名」的**機制 canary**歸 `tests/env-equivalence.bats` ENV-EQ-9 所有
# （那裡同時有 repo 普查）；本檔只負責「repo 的命名政策 + 掃描器本身的正確性」。
#
# 另外 PNA-4 守的是**斷言會不會真的生效**（TMO-074 的第二層教訓）：
#   **bash 3.2** 下，獨立的 `[[ ... ]]` 失敗**不會中止 test body**（只有最後一個命令的
#   狀態決定結果）→ 夾在中間的 `[[ ]]` 斷言等於沒有 → 本機假綠。
#   （bash 5.x 會中止 → 同一支探針在 CI 是對的、在本機是錯的 → 又是環境相依的假綠。）
#   實測（bats 1.14.0 / bash）：
#     [[ abc == xyz ]]; echo reached   -> reached（rc 0，沒中止）
#     [ abc = xyz ];    echo reached   -> 中止（rc 1）
#   → 因此所有獨立斷言都必須寫成 fail-fast 慣例：
#     [[ ... ]] || {
#       echo 'FAIL: <file>:<line>: assertion failed' >&2; return 1; }
#
# 注意：bats 1.14 的測試名不得含 CJK（會整支跳過 → 假綠），故本檔測試名全用 ASCII。

load 'helpers/test-env'
load 'helpers/probe-scan'

# 守門對象：repo 根的 tests/ 與 skills/*/tests/（CI 兩處都跑）。
_probe_files() {
  printf '%s\n' "$REPO_ROOT"/tests/*.bats
  printf '%s\n' "$REPO_ROOT"/skills/*/tests/*.bats 2>/dev/null
}

@test "PNA-1: no @test name contains a non-ASCII character" {
  # 靜態守門（locale 與環境無關）：任何 @test 名稱含非 ASCII 字元 → 直接紅。
  # 這是**預防**閘：名稱一旦 ASCII，bats 就不可能因為名稱把它丟棄。
  local violations=0 file name scanned_files=0 scanned_names=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    scanned_files=$((scanned_files + 1))
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      scanned_names=$((scanned_names + 1))
      if printf '%s\n' "$name" | LC_ALL=C grep -q '[^[:print:]]'; then
        echo "VIOLATION: $(basename "$file") 探針名含非 ASCII 字元 → bash 3.2 + UTF-8 locale 下 bats 會靜默丟棄它（本機假綠）：" >&2
        echo "    $name" >&2
        violations=$((violations + 1))
      fi
    done < <(probe_declared_names "$file")
  done < <(_probe_files)
  [ "$violations" -eq 0 ] || {
    echo "FAIL: $violations 支探針的名稱含非 ASCII 字元（在 bash 3.2 + UTF-8 locale 下從未執行 → 假綠）" >&2
    echo "修法：把測試名改成純 ASCII（保留原有的 <ID>: <說明> 結構，說明翻成英文）" >&2
    return 1
  }
  # 防空過：若 glob 壞掉 → 一個檔都沒掃到 → 0 violations → 靜默綠。
  [ "$scanned_files" -ge 40 ] || {
    echo "FAIL: 只掃到 $scanned_files 個探針檔（<40）→ 掃描範圍可能壞了（防空過）" >&2
    return 1
  }
  [ "$scanned_names" -ge 500 ] || {
    echo "FAIL: 只掃到 $scanned_names 個探針名（<500）→ 掃描器可能壞了（防空過）" >&2
    return 1
  }
}

@test "PNA-2: scanner agrees with bats --count on every probe file" {
  # 防空過：掃描器本身壞掉時，PNA-1 會「什麼都抓不到」→ 假綠。
  # 故每個檔案的宣告數都必須與 bats 自己的 --count 一致。
  local file mine theirs n=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    n=$((n + 1))
    mine=$(probe_declared_count "$file")
    theirs=$(bats --count "$file" 2>/dev/null | tr -d ' ')
    [ "$mine" = "$theirs" ] || {
      echo "FAIL: 掃描器與 bats 對不上：$(basename "$file") 掃描=$mine bats=$theirs" >&2
      echo "（掃描器壞掉 → PNA-1 會靜默放行）" >&2
      return 1
    }
  done < <(_probe_files)
  [ "$n" -ge 40 ] || {
    echo "FAIL: 只掃到 $n 個探針檔（<40）→ 列舉器可能壞了（防空過）" >&2
    return 1
  }
}

@test "PNA-3: scanner extracts real test names and ignores heredoc bodies" {
  # 掃描器的自我測試（形狀一律用 printf 逐行寫——用 heredoc 寫會被 bats 前處理器改寫）。
  local st="$BATS_TEST_TMPDIR/scanner-self-test.bats"
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' '@test "real one" { true; }'
    printf '%s\n' "cat > /dev/null <<'BODY'"
    printf '%s\n' '@test "inside heredoc" { true; }'
    printf '%s\n' 'BODY'
    printf '%s\n' "echo \"<<'NOT-A-HEREDOC'\" end"
    printf '%s\n' '@test "real two" { true; }'
    printf '%s\n' "awk 'BEGIN { print \"<<'X'\" }'"
    printf '%s\n' '@test "real three" { true; }'
    printf '%s\n' '@test "name with: colon and-dash" { true; }'
  } > "$st"
  local names
  names=$(probe_declared_names "$st")
  [ "$(printf '%s\n' "$names" | wc -l | tr -d ' ')" -eq 4 ] || {
    echo "FAIL: 掃描器自我測試：期望 4 個名稱，得到 $(printf '%s\n' "$names" | wc -l | tr -d ' ')" >&2
    printf '%s\n' "$names" >&2
    return 1
  }
  printf '%s\n' "$names" | grep -qxF "real one" || {
    echo "FAIL: 掃描器沒有抽出 'real one'" >&2
    return 1
  }
  printf '%s\n' "$names" | grep -qxF "name with: colon and-dash" || {
    echo "FAIL: 掃描器沒有抽出含冒號的完整名稱" >&2
    printf '%s\n' "$names" >&2
    return 1
  }
  if printf '%s\n' "$names" | grep -q "inside heredoc"; then
    echo "FAIL: 掃描器把 heredoc 內的 @test 當成真宣告（會誤報）" >&2
    return 1
  fi
}


@test "PNA-4: every standalone [[ ]] assertion is fail-fast (or a conditional)" {
  # TMO-074 的第二層教訓：獨立的 `[[ ... ]]` 斷言在 bats 裡**失敗不會中止 test body**
  # （只有最後一個命令的狀態決定結果）→ 夾在中間的斷言等於沒有，探針會「假綠」。
  #
  # 實測（bats 1.14.0）：
  #   **同一個檔案、同一個環境、每個案例的最後一個命令都是 `true`**（這樣「中途是否
  #   中止」就唯一決定結果，不會被「量測環境混用」誤導）：
  #   T1: [ abc = xyz ];    echo reached; true   -> 紅（中止）
  #   T2: [[ abc == xyz ]]; echo reached; true   -> 綠（**沒**中止）
  #   T3: false;             echo reached; true   -> 紅（中止）
  #   T4/T5: 單獨一行時，兩種括號都會讓測試紅（最後一個命令就是斷言本身）
  #   T6: [[ abc == xyz ]] || [[ abc == xyz2 ]]  -> 綠（**|| 鏈也不會中止！**）
  #   T7: [[ abc == xyz ]] || { echo x; return 1; } -> 紅（fail-fast 有效）
  # → 不對稱是真的：**只有雙括號 `[[ ]]`（含 `||` 鏈）不會中止**；
  #   單括號 `[ ]` 與 `false` 都會中止 → 單括號中段斷言是安全的，不需改寫。
  #   （V03 Reviewer 質疑這個不對稱是量測環境混用 → 已用上述 T1~T7 同檔對照實驗排除。）
  #
  # 規定：獨立的 `[[ ... ]]`（含 `||` / `&&` 鏈）必須寫成 fail-fast 慣例
  #   [[ ... ]] || {
  #     echo 'FAIL: <file>:<line>: assertion failed' >&2; return 1; }
  # 允許的例外：
  #   ① if / elif / while / until 的條件式（那是安全的條件語境）
  #   ② guard clause（|| continue / || break / && continue …）——那是「跳過」不是「斷言」
  #   ③ 位於 test body 的**最後一句**（bats 取最後一個命令的狀態 → 會失敗）
  local file line n violations=0 shown=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    # 用 heredoc 感知的掃描器：heredoc 內的示範碼**不是真的探針語句** → 不能當斷言掃
    while IFS=$'\t' read -r n line; do
      local stripped
      stripped=$(printf '%s\n' "$line" | probe_strip_comment /dev/stdin | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      case "$stripped" in
        \[\[*)
          # guard clause → 安全
          case "$stripped" in
            *"|| continue"*|*"|| break"*|*"|| return"*|*"|| exit"*|*"&& continue"*|*"&& break"*) continue ;;
          esac
          # fail-fast 慣例：同行有 return 1，或本行的 `|| {` 區塊內有 return 1
          # ⚠️ 區塊必須**屬於這個斷言**：不能往前看太多行，否則會誤把「下一個斷言的
          #    fail-fast 區塊」當成自己的 → 漏報。所以以區塊結尾的 `}` 為界。
          case "$stripped" in
            *"return 1"*) continue ;;
          esac
          # fail-fast 的兩種排版都要認：
          #   (a) [[ ... ]] || {            ← 同一行
          #   (b) [[ ... ]] ||               ← || 在行尾、{ 換行
          #       { echo ...; return 1; }
          local opens_block=0
          case "$stripped" in
            *"|| {"*|*"&& {"*) opens_block=1 ;;
            *"||"|*"&&")
              local nxtline
              nxtline=$(sed -n "$((n + 1))p" "$file" 2>/dev/null | sed 's/^[[:space:]]*//')
              case "$nxtline" in
                "{"*) opens_block=1 ;;
              esac
              ;;
          esac
          if [ "$opens_block" -eq 1 ]; then
            if awk -v s="$n" '
                  NR>s { t=$0; sub(/^[ \t]+/, "", t)
                         if (t ~ /^}/) exit
                         if (t ~ /return 1/) { found=1; exit } }
                  END { exit(found ? 0 : 1) }' "$file"; then
              continue
            fi
          fi
          # 位於 test body 的最後一句 → 安全
          local after
          after=$(awk -v s="$n" 'NR>s && NF{print; exit}' "$file")
          case "$after" in
            \}*) continue ;;
          esac
          violations=$((violations + 1))
          if [ "$shown" -lt 10 ]; then
            echo "VIOLATION: $file:$n 獨立 [[ ]] 斷言沒有 fail-fast（失敗會被靜默忽略 → 假綠）：" >&2
            echo "    $stripped" >&2
            shown=$((shown + 1))
          fi
          ;;
      esac
    done < <(probe_code_lines "$file")
  done < <(_probe_files)
  [ "$violations" -eq 0 ] || {
    echo "FAIL: $violations 個獨立 [[ ]] 斷言沒有 fail-fast（bats 裡失敗不會中止 → 假綠）" >&2
    echo "修法：改成 [[ ... ]] || { echo 'FAIL: <file>:<line>: assertion failed' >&2; return 1; }" >&2
    return 1
  }
}
