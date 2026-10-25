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
  local st="$BATS_TEST_TMPDIR/scanner-self-test.fixture"
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
  #      ——判準三步：①下一個非空行若以**行首** `}` 開頭 → 豁免（與原判準逐字一致）
  #        ②否則若係「純收尾行」（剝空白後 == `}` 或 `};`）→ 繼續向後行，直到遇到行首 `}` → 豁免
  #        ③一旦遇到其他 code → 唔豁免
  #      含「內層 `{ ... }` 區塊收尾」嗰種情況（TMO-078 語意修正，見 helper 註解）
  # 效能（2026-10-26）：原本呢支係「逐行 fork awk/sed」——repo 13,660 行 × 約 2.5 fork
  # ≈ 35,000 次 process spawn → 單呢支探針要 94.6 秒（bats --timing 實測）。
  # 改成 `probe_find_standalone_assertions`：**每個檔案一個 awk 行程**，檔案內容讀進
  # 陣列後喺 awk 內完成全部判斷（heredoc 感知 / 剝註解 / guard clause / fail-fast 區塊
  # / 最後一句）→ 45 個探針檔全部掃完 0.745 秒（快 127 倍），判斷結果逐檔一致。
  # 判斷規則逐條對應原本的規格（見 tests/helpers/probe-scan.bash 內該函式的說明）。
  local file n stripped violations=0 shown=0 scanned_files=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    scanned_files=$((scanned_files + 1))
    while IFS=$'\t' read -r n stripped; do
      [ -n "$n" ] || continue
      violations=$((violations + 1))
      if [ "$shown" -lt 10 ]; then
        echo "VIOLATION: $file:$n 獨立 [[ ]] 斷言沒有 fail-fast（失敗會被靜默忽略 → 假綠）：" >&2
        echo "    $stripped" >&2
        shown=$((shown + 1))
      fi
    done < <(probe_find_standalone_assertions "$file")
  done < <(_probe_files)
  # 防空過（P1-1，2026-10-26）：**檔案列舉漂移**（glob 壞掉 → 掃到 0 個檔 → violations=0 → 報綠）
  # → 用「掃到幾個」嘅下限擋（同 PNA-1/PNA-2 一致）。
  # ⚠️ 注意分工：**呢個下限擋唔到掃描器本身壞掉**（awk 出錯時迴圈照跑、scanned_files 照 45、
  #    violations=0 → 仍然綠）。擋 scanner 壞嘅係 **PNA-4b canary**（同一支函式對已知 fixture
  #    斷言）——兩者缺一不可，唔可以互相代替。
  [ "$scanned_files" -ge 40 ] || {
    echo "FAIL: 只掃到 $scanned_files 個探針檔（<40）→ 掃描範圍可能壞了（防空過）" >&2
    return 1
  }
  [ "$violations" -eq 0 ] || {
    echo "FAIL: $violations 個獨立 [[ ]] 斷言沒有 fail-fast（bats 裡失敗不會中止 → 假綠）" >&2
    echo "修法：改成 [[ ... ]] || { echo 'FAIL: <file>:<line>: assertion failed' >&2; return 1; }" >&2
    return 1
  }
}

@test "PNA-4b: the standalone-assertion scanner bites" {
  # 防空過（P1-1，2026-10-26）：PNA-4 本身**只會喺 repo 出現真違規時變紅**；
  # 若 `probe_find_standalone_assertions` 壞掉（awk syntax error / 邏輯改壞），
  # 它會冇輸出 → violations=0 → **報綠** → 守門靜默失效。
  # repo 自己踩過同一個坑（docs/sop/handbook/changelog.md：TMO-074 嗰輪改 `while read`
  # 漏改 `done < "$file"` → 整支守門空轉仍報綠，靠突變測試先捉到）→ **守門自己也必須
  # 先證明自己會咬**。
  #
  # 這支用 `printf` 逐行寫 fixture（**唔可以用 heredoc**：bats 前處理器會把 heredoc 內的
  # `@test` 行改寫成 `bats_test_function`，fixture 會壞）。
  # Fixture 副檔名用 `.fixture`（唔用 `.bats`）：萬一 TMPDIR 指去 repo 內（例如 repo/tests/），
  # PNA-4 自己嘅 glob（tests/*.bats）就會掃到呢個 fixture → 假紅。副檔名唔影響掃描器。
  # Fixture 內容（行號如右）：
  #   3  [[ ... ]] || { echo F >&2; return 1; }   → 安全（規則⑤ 同行 fail-fast）
  #   5  [[ ... ]]                                  → **必然 violation**（裸斷言，後面唔係 }）
  #   7  [[ ... ]]（heredoc 內容）                  → 安全（規則① heredoc 感知）
  #   9  [[ ... ]] || continue                      → 安全（規則④ guard clause）
  #  10  # [[ ... ]]（整行註解）                    → 安全（規則② 剝註解）
  #  11  [[ ... ]] || ＋ 12 { ...; return 1; }      → 安全（規則⑥b 跨行 fail-fast 區塊）
  #  14  [[ ... ]] ＋ 15 }（行首）                  → 安全（規則⑦ test body 最後一句）
  # → 期望掃描器**恰好**報 1 個 violation，且行號 = 5。
  # ⚠️ 新增嘅安全案例一律放喺行 5 **之後**，否則 violation 嘅行號會飄 → 期望字串要跟住改。
  local st="$BATS_TEST_TMPDIR/pna4b-fixture.fixture"
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' '@test "canary" {'
    printf '%s\n' '  [[ "$a" == "b" ]] || { echo F >&2; return 1; }'
    printf '%s\n' '  echo between'
    printf '%s\n' '  [[ "$a" == "b" ]]'
    printf '%s\n' '  cat > /dev/null <<'"'"'BODY'"'"''
    printf '%s\n' '  [[ "$heredoc" == "x" ]]'
    printf '%s\n' 'BODY'
    printf '%s\n' '  [[ "$a" == "b" ]] || continue'
    printf '%s\n' '  # [[ "$a" == "b" ]]'
    printf '%s\n' '  [[ "$a" == "b" ]] ||'
    printf '%s\n' '  { echo F >&2; return 1; }'
    printf '%s\n' '  echo tail'
    printf '%s\n' '  [[ "$a" == "b" ]]'
    printf '%s\n' '}'
  } > "$st"

  local out expected
  out=$(probe_find_standalone_assertions "$st")
  # 期望輸出**恰好**係「行號 5 + 該行內容」——
  # 一條斷言同時證明：① 恰好一個 violation ② 行號係 5（裸斷言）
  # ③ 其餘 6 個安全案例（行 3/7/9/10/11/14）都**冇**被報。
  # ⚠️ 用 printf 組期望值（printf 會把 \t 轉成真 tab）；唔可以直接寫 "5\t..." ——
  #    bash 雙引號入面 \t 唔係跳脫字元（會留成反斜線+t），咁就永遠 match 唔到（死斷言）。
  expected=$(printf '5\t%s' '[[ "$a" == "b" ]]')
  [ "$out" = "$expected" ] || {
    echo "FAIL: 掃描器對已知 fixture 的輸出唔等於期望值 → 掃描器壞咗（或規則被改壞）" >&2
    echo "  期望: $(printf '%q' "$expected")" >&2
    echo "  實際: $(printf '%q' "$out")" >&2
    return 1
  }
  return 0
}

@test "PNA-4c: the inner-block last-statement rule" {
  # TMO-078：規則⑦ 原本只睇「**下一個**非空行係行首 `}`」→ 內層 `{ ... }` 區塊嘅
  # 最後一句會被誤判成 violation（**latent 假紅** —— 該斷言其實係 test body 嘅
  # 最後一個命令，bats 會攞到佢嘅狀態 → 其實安全）。
  #
  # 新判準三步：① **下一個非空行若以行首 `}` 開頭 → 豁免**（與原判準逐字一致）
  # ② 否則若佢係「純收尾行」（剝空白後 == `}` 或 `};`）→ 繼續向後行，直到遇到行首 `}` → 豁免
  # ③ 一旦遇到其他 code → 唔豁免（照報 violation）。
  # → 係舊判準嘅**超集** → 舊判準豁免嘅全部照樣豁免，**唔可能新增 violation**。
  #
  # 呢支用兩個案例**同時**鎖住兩個方向：
  #   案例 A（行 4）：內層區塊收尾之後**仲有其他 code** → 必須**照報**（真違規，
  #                   唔可以因為「下一行係 `}`」就放過 → 防止條件放寬）
  #   案例 B（行 10）：內層區塊**就係** test body 嘅最後一個命令 → 必須**唔報**（假紅修正）
  local st="$BATS_TEST_TMPDIR/pna4c-fixture.fixture"
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' '@test "case A: inner block then more code" {'
    printf '%s\n' '  {'
    printf '%s\n' '    [[ "$a" == "b" ]]'
    printf '%s\n' '  }'
    printf '%s\n' '  echo after'
    printf '%s\n' '}'
    printf '%s\n' '@test "case B: inner block is the last command" {'
    printf '%s\n' '  {'
    printf '%s\n' '    [[ "$a" == "b" ]]'
    printf '%s\n' '  }'
    printf '%s\n' '}'
    printf '%s\n' '@test "case C: closing brace with trailing comment" {'
    printf '%s\n' '  [[ "$a" == "b" ]]'
    printf '%s\n' '} # end of test'
    printf '%s\n' '@test "case D: closing brace with semicolon" {'
    printf '%s\n' '  [[ "$a" == "b" ]]'
    printf '%s\n' '};'
  } > "$st"

  local out expected
  out=$(probe_find_standalone_assertions "$st")
  # 期望：**恰好**一個 violation，行號 = 4（案例 A）。
  # 案例 B（行 10）／C（行 14）／D（行 18）**唔應該**被報 →
  # 若新判準錯判成「豁免案例 A」就會變成空輸出 → 紅；
  # 若錯判成「把案例 B/C/D 當違規」就會變成多行 → 亦紅。
  expected=$(printf '4\t%s' '[[ "$a" == "b" ]]')
  [ "$out" = "$expected" ] || {
    echo "FAIL: 規則⑦ 嘅輸出唔等於期望值（案例 A 行 4 應報、案例 B 行 10 應唔報）" >&2
    echo "  期望: $(printf '%q' "$expected")" >&2
    echo "  實際: $(printf '%q' "$out")" >&2
    return 1
  }
  return 0
}
