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
# 另外 PNA-4 守的是**斷言會唔會寫得夠顯眼**（TMO-074 的第二層教訓）：
#   獨立的 `[[ ... ]]` 失敗時唔會印任何嘢 → 睇唔到邊行出錯 → 難診斷。
#   ⚠️ **前提更正（2026-10-26，TMO-079 順帶查證）**：本段原本寫住「bash 3.2 下獨立的
#   `[[ ]]` 失敗**不會中止 test body**、bash 5.x 會中止」—— 重新量測之後**兩句都係錯**：
#     bats 1.14.0（CI pin）同 1.11.1 嘅 `libexec/bats-core/bats-exec-test` 開頭都係
#     `set -eET`，test body 喺 `{ setup "$@"; "$@"; }` 呢個**唔受 -e 忽略**嘅語境入面跑
#     → 獨立嘅 `[[ ]]` 失敗**會中止 test body**（bash 3.2 同 5.3 一樣，冇版本差）。
#     實測（`bats --print-output-on-failure`）：T1~T7 全部 `not ok`，`echo reached`
#     一次都冇印出 → 確認係「中止」。（量測工具自我檢查：印 reached 後明確 false →
#     reached 有印 → 工具正常。）
#   → 所以 PNA-4 而家嘅定位係**風格／可讀性守門**（要求顯式 fail-fast + 檔案行號
#     訊息），而唔係「唯一防止靜默失敗」嘅東西。規則**保留**（理由見 PNA-4 支內註）。
#   → 所有獨立斷言仍然寫成 fail-fast 慣例：
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
  # TMO-074 的第二層教訓：獨立的 `[[ ... ]]` 斷言寫得唔顯眼 → 失敗時睇唔到邊行出錯
  # → 探針會「假綠」（測試報綠，但其實個斷言從來冇生效過）。
  #
  # ⚠️ **前提更正（2026-10-26，TMO-079 順帶查證）**：
  #   本檔原本寫住「bats 裡獨立的 `[[ ]]` 斷言失敗**不會中止 test body**」，
  #   嗰句係**實測錯**（原始 T1~T7 記錄見 git history `9c04aaa`）。重新量測：
  #     bats 1.14.0（CI pin 嘅版本）同 1.11.1 嘅 `libexec/bats-core/bats-exec-test`
  #     開頭都係 `set -eET`，而 test body 係喺 `{ setup "$@"; "$@"; }` 呢個
  #     **唔受 -e 忽略**嘅語境入面跑 → **獨立嘅 `[[ ]]` 失敗係會中止 test body 嘅**。
  #     實測（`bats --print-output-on-failure`）：T1~T7 全部 `not ok`，
  #     而且 `echo reached` **一次都冇印出** → 確認係「中止」而唔係「跑完先失敗」。
  #     （器材自我檢查：印 `reached` 之後明確 `false` → `reached` 有印 → 量測工具正常。）
  #   → 所以 PNA-4 現時嘅定位係**風格／可讀性守門**（要求顯式 fail-fast + 檔案行號
  #     訊息），而**唔係**「唯一防止靜默失敗」嘅東西。
  #   → 規則**保留**：①顯式 fail-fast 會印 `FAIL: <file>:<line>` → 診斷到行；
  #     ②防「有人喺 test body 裡寫 `set +e`」嗰種會令一切靜默嘅情況；
  #     ③防將來 bats 改行為。181 個斷言已經改咗（9c04aaa）→ 規則鎖住成果。
  #
  #   **可重現嘅量測（2026-10-26 實測，bats 1.14.0 ＝ CI pin 嘅版本；v1.11.1 結果相同）**：
  #     同一個 .bats 檔、同一環境、每個案例嘅最後一個命令都係 `true`；
  #     用 `bats --print-output-on-failure` 睇 test body 有冇跑完（冇 `reached` ＝ 中止）：
  #       T1: [ abc = xyz ];    echo reached; true   -> not ok（中止）
  #       T2: [[ abc == xyz ]]; echo reached; true   -> not ok（中止）
  #       T3: false;             echo reached; true   -> not ok（中止）
  #       T4/T5: 單獨一行時，兩種括號都會讓測試紅（最後一個命令就是斷言本身）
  #       T6: [[ abc == xyz ]] || [[ abc == xyz2 ]]  -> not ok（中止）
  #       T7: [[ abc == xyz ]] || { echo x; return 1; } -> not ok（fail-fast 有效）
  #     ⚠️ 原本記錄寫 T2／T6 係「綠（冇中止）」—— 重新量測證實**兩者都係錯**（見上）。
  #     器材自我檢查（確認量測工具本身有效）：印 `reached` 之後明確 `false` → `reached` 有印。
  #     ⚠️ 教訓：量測「有冇中止」**必須**用 `--print-output-on-failure`**，
  #        否則 bats 會把 test body 嘅 stdout 收埋，睇唔到 `reached` 有冇印過。
  #
  # 規定：獨立的 `[[ ... ]]`（含 `||` / `&&` 鏈）必須寫成 fail-fast 慣例
  #   [[ ... ]] || {
  #     echo 'FAIL: <file>:<line>: assertion failed' >&2; return 1; }
  # 允許的例外：
  #   ① if / elif / while / until 的條件式（那是安全的條件語境）
  #   ② guard clause（|| continue / || break / && continue …）——那是「跳過」不是「斷言」
  #   ③ 位於 **@test body** 嘅**最後一句**（bats 取 test body 最後一個命令嘅狀態
  #      做測試結果 → 斷言失敗就係測試失敗，唔使再包一層）
  #      ——判準三步：①下一個非空行若以**行首** `}` 開頭 → 豁免（與原判準逐字一致）
  #        ②否則若係「純收尾行」（剝空白後 == `}` 或 `};`）→ 繼續向後行，直到遇到行首 `}` → 豁免
  #        ③一旦遇到其他 code → 唔豁免
  #      含「內層 `{ ... }` 區塊收尾」嗰種情況（TMO-078 語意修正，見 helper 註解）
  #      ⚠️ TMO-079：豁免而家要求「所屬頂層區塊**確實係 `@test` body**」
  #        （行首 `}` 亦可能關 setup()／teardown()／helper function → 唔再意外豁免）。
  #        對應 canary：PNA-4d。
  # 效能（2026-10-26）：原本呢支係「逐行 fork awk/sed」——repo 13,660 行 × 約 2.5 fork
  # ≈ 35,000 次 process spawn → 單呢支探針要 94.6 秒（bats --timing 實測）。
  # 改成 `probe_find_standalone_assertions`：**每個檔案一個 awk 行程**，檔案內容讀進
  # 陣列後喺 awk 內完成全部判斷（heredoc 感知 / 剝註解 / guard clause / fail-fast 區塊
  # / 最後一句 / 頂層區塊追蹤）→ 46 個探針檔全部掃完，判斷結果逐檔一致。
  # ⚠️ 效能數字嘅**口徑**（唔好再寫第二個無出處嘅數）：
  #   原始逐行 fork 版：94.6 秒（`bats --timing` 實測，當時 corpus 45 檔）
  #   現版單 awk 行程版：掃描器本體 0.66 秒（2026-10-26 實測 3 次：0.66／0.66／0.65，
  #     46 檔）→ 掃描器本體約 **143 倍**（94.6 ÷ 0.66；兩邊 corpus 大小唔同：45 → 46 檔）
  #   （PNA-4 呢支**成支探針**嘅耗時對比 94,612ms → 855ms／快 111 倍 → 口徑統一放喺
  #     helper 同一節，呢度唔重複寫，避免同一指標出現兩個值）
  #   ⚠️ 呢啲係**量測值**（受機器負載影響）→ 唔好寫成硬門檻。
  # 判斷規則逐條對應原本的規格（見 tests/helpers/probe-scan.bash 內該函式的說明）。
  local file n stripped violations=0 shown=0 scanned_files=0
  while IFS= read -r file; do
    [ -f "$file" ] || continue
    scanned_files=$((scanned_files + 1))
    while IFS=$'\t' read -r n stripped; do
      [ -n "$n" ] || continue
      violations=$((violations + 1))
      if [ "$shown" -lt 10 ]; then
        echo "VIOLATION: $file:$n 獨立 [[ ]] 斷言沒有 fail-fast（失敗時唔會印邊行出錯 → 難診斷）：" >&2
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
    echo "FAIL: $violations 個獨立 [[ ]] 斷言沒有 fail-fast（要求顯式 fail-fast + 檔案行號訊息）" >&2
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
  # 呢支用五個案例**同時**鎖住五個方向：
  #   案例 A（行 4）：內層區塊收尾之後**仲有其他 code** → 必須**照報**（真違規，
  #                   唔可以因為「下一行係 `}`」就放過 → 防止條件放寬）
  #   案例 B（行 10）：內層區塊**就係** test body 嘅最後一個命令 → 必須**唔報**（假紅修正）
  #   案例 C（行 14）：收尾 `}` **帶行尾註解**（`} # end of test`）→ 必須**唔報**
  #   案例 D（行 18）：收尾用 `};` → 必須**唔報**
  #   案例 E（行 20）：**之後搵唔到行首 `}`**（@test body 根本冇收尾，斷言喺檔尾）
  #                   → 必須**照報**（TMO-080：呢個方向之前冇 canary 鎖住 →
  #                   若日後有人改成「行到 EOF 就豁免」，PNA-4b／PNA-4c 都唔會紅
  #                   → 守門失效。對應 mutant：PNA-M3）
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
    printf '%s\n' '@test "case E: assertion at EOF with no closing brace" {'
    printf '%s\n' '  [[ "$a" == "b" ]]'
  } > "$st"

  local out expected
  out=$(probe_find_standalone_assertions "$st")
  # 期望：**恰好**兩個 violation，行號 = 4（案例 A）同 20（案例 E）。
  # 案例 B（行 10）／C（行 14）／D（行 18）**唔應該**被報 →
  # 若新判準錯判成「豁免案例 A」就會變成少一行 → 紅；
  # 若錯判成「把案例 B/C/D 當違規」就會變成多行 → 亦紅；
  # 若錯判成「豁免案例 E（行到 EOF 就當安全）」→ 都會少一行 → 紅（TMO-080 嘅鎖）。
  expected=$(printf '4\t%s\n20\t%s' '[[ "$a" == "b" ]]' '[[ "$a" == "b" ]]')
  [ "$out" = "$expected" ] || {
    echo "FAIL: 規則⑦ 嘅輸出唔等於期望值（案例 A 行 4 + 案例 E 行 20 應報；B/C/D 應唔報）" >&2
    echo "  期望: $(printf '%q' "$expected")" >&2
    echo "  實際: $(printf '%q' "$out")" >&2
    return 1
  }
  return 0
}


@test "PNA-4d: the last-statement rule only exempts @test bodies" {
  # TMO-079：規則⑦ 原本靠「下一個行首 `}`」呢個**隱含假設**認「test body 收尾」。
  # 但行首 `}` 有**兩種**意義 —— 關 @test body，**或者**關 setup()／teardown()／
  # helper function（.bats 入面呢啲 function 嘅收尾 `}` 同樣喺行首）。
  # TMO-078 嘅 V03 二審當時裁定「保留原語意（超集性質優先）」，但同時記低咗呢個
  # 更實際嘅假綠面 → backlog TMO-079。
  #
  # 而家改成**明確判定**：掃描器逐行追蹤頂層區塊（column-0 嘅 `{` / `}`），
  # 記低每行所屬區塊嘅 kind（test／func／other）同關閉佢嘅行號；
  # 規則⑦ 嘅豁免要求「所屬區塊**確實係 `@test` body**」＋「掃描到嗰個區塊嘅
  # **真實收尾行**」。→ 函式 body 嘅斷言**唔再**被意外豁免。
  #
  # 呢支鎖住四個方向（行號如右）：
  #   案例 1（行 3）：`setup()` 函式 body 嘅最後一句 → 必須**照報**
  #                   （TMO-079 收緊嘅核心：以前會被「行首 `}`」意外豁免）
  #   案例 2（行 6）：test body 嘅最後一句，由 `} || {` 收尾 → 必須**唔報**
  #                   （TMO-079 裁定要保留嘅語意：斷言仍然係 test body 最後一句）
  #   案例 3（行 11）：test body 入面但**唔係**最後一句 → 必須**照報**（對照組）
  #   案例 4（行 15）：**裸 column-0 群組** `{ ... }`（唔係 test body、唔係函式）
  #                   → 必須**照報**（fail-closed：豁免嘅理由只適用於 @test body）
  #
  # ⚠️ Fixture **唔會俾 bats 執行**（淨係俾掃描器讀），所以 `} || {` 呢種
  #    非標準寫法喺度冇問題。
  # ⚠️ 新增嘅安全案例一律放喺行 3 **之後**，否則 violation 嘅行號會飄 → 期望字串要跟住改。
  local st="$BATS_TEST_TMPDIR/pna4d-fixture.fixture"
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' 'setup() {'
    printf '%s\n' '  [[ "$a" == "b" ]]'
    printf '%s\n' '}'
    printf '%s\n' '@test "edge a: test body closed by } || {" {'
    printf '%s\n' '  [[ "$a" == "b" ]]'
    printf '%s\n' '} || {'
    printf '%s\n' '  echo cleanup'
    printf '%s\n' '}'
    printf '%s\n' '@test "edge c: assertion is not the last command" {'
    printf '%s\n' '  [[ "$a" == "b" ]]'
    printf '%s\n' '  echo after'
    printf '%s\n' '}'
    printf '%s\n' '{'
    printf '%s\n' '  [[ "$a" == "b" ]]'
    printf '%s\n' '}'
  } > "$st"

  local out expected
  out=$(probe_find_standalone_assertions "$st")
  # 期望：**恰好**三個 violation，行號 = 3（函式 body）、11（唔係最後一句）、
  # 15（裸 column-0 群組）。
  # 案例 2（行 6）**唔應該**被報 → 若被報就代表收窄得太狠（連 @test body 都唔豁免）。
  expected=$(printf '3\t%s\n11\t%s\n15\t%s' '[[ "$a" == "b" ]]' '[[ "$a" == "b" ]]' '[[ "$a" == "b" ]]')
  [ "$out" = "$expected" ] || {
    echo "FAIL: 規則⑦ 嘅區塊 kind 判定唔等於期望值（行 3／11／15 應報、行 6 應唔報）" >&2
    echo "  期望: $(printf '%q' "$expected")" >&2
    echo "  實際: $(printf '%q' "$out")" >&2
    return 1
  }
  return 0
}
