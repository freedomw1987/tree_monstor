#!/usr/bin/env bash
# tests/helpers/probe-scan.bash
#
# 掃描 .bats 檔裡「bats 真的會當成 @test 的宣告」——**共 3 支**：
#   - probe_declared_names <file>：逐行印出每個 @test 宣告的**測試名稱**
#   - probe_declared_count <file>：印出宣告數
#   - probe_find_standalone_assertions <file>：印出「無 fail-fast 嘅獨立 [[ ]] 斷言」
#
# TMO-078：原本仲有 `probe_strip_comment`（剝註解）同 `probe_code_lines`（heredoc 感知
# 行號）兩支——PNA-4 改用單 awk 行程後佢哋**冇咗呼叫點**（邏輯已複製入
# `probe_find_standalone_assertions` 內）→ 已刪，避免「兩份實作、遲早漂移」。
#
# 為什麼需要這支（不只是 grep @test）：
#   bats 前處理器會把 heredoc 內的 `@test` 行改寫成 `bats_test_function ...`
#   （實測 1.14.0）→ 直接 grep 會把「示範碼」也算進去 → 假紅。
#   所以掃描器必須**引號感知 + heredoc 感知**：
#     - 位於引號內的 `<<` 不當 heredoc 起點（否則 `printf '%s\n' "cat <<'EOF'"`
#       這種 fixture 會讓掃描器一路吞到檔尾）。
#     - 引號狀態跨行保存；交叉污染只會造成「大聲紅」（多算/少算都比對得出來），
#       不會靜默。
#
# 為什麼「名稱」比「數量」重要（TMO-074）：
#   bats 1.14 在 **UTF-8 locale** 下會**靜默丟棄**名稱含 CJK 等 Unicode 字母的 @test
#   （`bats: unknown test name` → "Executed N instead of expected M" → rc=1）。
#   但 `bats --count` **仍把它算進去** → 光比數量抓不到，必須看**名稱本身**。


# 印出每個 @test 宣告的名稱（每行一個）。
probe_declared_names() {
  awk '
    BEGIN { skip = 0; q = "" }
    {
      if (skip) { if ($0 == tag) skip = 0; next }
      nch = length($0); i = 1; found = 0; pos = 0
      while (i <= nch) {
        c = substr($0, i, 1)
        if (q == "") {
          if (c == "'\''") { q = "'\''"; i++; continue }
          if (c == "\"") { q = "\""; i++; continue }
          if (c == "\\") { i += 2; continue }
          if (c == "<" && substr($0, i + 1, 1) == "<") { found = 1; pos = i; break }
        } else if (q == "'\''") {
          if (c == "'\''") q = ""
        } else {
          if (c == "\\") { i += 2; continue }
          if (c == "\"") q = ""
        }
        i++
      }
      if (found) {
        rest = substr($0, pos)
        # heredoc 起點：delimiter 後面只接行尾或重導向（`<<%s` 之類不當 heredoc）
        if (match(rest, /^<<-?[[:space:]]*["\047]?[A-Za-z_][A-Za-z0-9_-]*["\047]?([[:space:]]*$|[[:space:]]+[0-9]*[>&|])/)) {
          t = substr(rest, RSTART, RLENGTH)
          sub(/[[:space:]]*[0-9]*[>&|].*$/, "", t)
          gsub(/<<-?[[:space:]]*/, "", t); gsub(/["\047]/, "", t)
          tag = t; skip = 1
        }
      }
      if ($0 ~ /^@test[[:space:]]/) {
        line = $0
        sub(/^@test[[:space:]]+/, "", line)
        name = ""
        if (match(line, /^"[^"]*"/)) {
          name = substr(line, RSTART + 1, RLENGTH - 2)
        } else if (match(line, /^'\''[^'\'']*'\''/)) {
          name = substr(line, RSTART + 1, RLENGTH - 2)
        } else {
          name = line
          sub(/[[:space:]]*\{.*$/, "", name)
          sub(/[[:space:]]+$/, "", name)
        }
        print name
      }
    }
  ' "$1"
}

# 印出宣告數（與 probe_declared_names 的行數一致）。
probe_declared_count() {
  probe_declared_names "$1" | wc -l | tr -d ' '
}


# ─── PNA-4 掃描器：獨立的 [[ ]] 斷言有冇 fail-fast ─────────────────────
#
# 為什麼要獨立一支（2026-10-26 效能修正）：
#   PNA-4 原本在 bats test body 裡**逐行**做 `awk` / `sed` fork：
#     - strip 一行 → `probe_strip_comment`（fork 1 個 awk）+ `sed`（fork 1 個）
#     - 睇下一行 → `sed -n` ×2（fork 2 個）
#     - 睇 fail-fast 區塊 → `awk -v`（fork 1 個）
#     - 睇 test body 最後一句 → `awk -v`（fork 1 個）
#   → repo 13,660 行 × 約 2.5 fork ≈ **35,000 次 process spawn** → 單一支探針
#     要 **94.6 秒**（bats --timing 實測，2026-10-26）。
#
#   改成：**每個檔案一個 awk 行程**，檔案內容先讀進陣列，再在 awk 內做全部判斷。
#   → 量測口徑（唔好再寫第二個數字）：
#       `bats --timing tests/probe-name-ascii.bats` → PNA-4 **855ms**（改前 94,612ms，快 111 倍）
#       掃描器本身掃 46 個探針檔約 0.6–0.8s（2026-10-26 實測 3 次：0.66／0.66／0.65s）
#     整個 `bats tests/ skills/` 總時間**唔寫死**（受機器負載影響，本機量到 2m42s–3m23s 幾個值）。
#
# 判斷規則與原本逐行版的**逐條對照**（左 = 原本 shell `case` glob，右 = 現版 awk regex）：
#   ① 只看不在 heredoc 內的行        ← 邏輯源自舊 `probe_code_lines`（TMO-078 已刪；
#                                        而家**淨得呢一份實作**，唔存在漂移風險）
#   ② 剝掉行尾註解（引號感知）        ← 邏輯源自舊 `probe_strip_comment`（同上，已刪）
#   ③ `[[ ... ]]` 開頭才算獨立斷言    ← case "$s" in \[\[*   ≡   s !~ /^\[\[/
#   ④ guard clause → 安全             ← *"|| continue"* 等（包含）  ≡  /\|\| continue/ 等（包含）
#   ⑤ 同行有 `return 1` → 安全        ← *"return 1"*（包含）          ≡  /return 1/（包含）
#   ⑥ `|| {` / `&& {`（同行）→ 開區塊 ← *"|| {"* / *"&& {"*（包含）≡ /\|\| \{/ / && \{/
#      `||` / `&&` **行尾** + 下一行開頭 `{` → 開區塊
#                                   ← *"||"* / *"&&"*（**行尾錨定**）≡ /\|\|$/ / /&&$/
#      區塊內（以 `}` 為界）有 `return 1` → 安全
#   ⑦ 斷言係 **@test body** 嘅最後一個命令 → 安全（TMO-079 收緊）：
#      ⓪ **所屬頂層區塊必須確實係 `@test` body**（見下面「頂層區塊追蹤」）
#      ① **下一個非空行若以行首 `}` 開頭 → 豁免**（與原判準逐字一致）
#      ② 否則若佢係「純收尾行」（剝空白後 == `}` 或 `};`）→ 繼續向後行，
#         直到遇到**所屬 @test body 嘅真實收尾行** → 豁免
#      ③ 一旦遇到其他 code → 唔豁免（照報 violation）
#      ④ @test body **從來冇收尾**（搵唔到收尾行）→ 唔豁免（照報 violation）
#         （TMO-080：呢個方向之前冇 canary 鎖住 → 對應 mutant PNA-M3）
#                                   ← 原版：after=$(awk 'NR>s && NF{print; exit}')（**原行，未剝空白**）
#                                     + case "$after" in \}*  ≡  after ~ /^\}/
#                                     （**TMO-078 語意修正**：見下面「規則⑦ 嘅語意修正」段）
#   ⑧ 以上都不中 → 記一個 violation
#
# 等價範圍（TMO-078 規則⑦ 修正**之後**；TMO-079 收窄**之後**）：
#   - 45 個真實探針檔：舊規則 vs 新規則 → **新增 violation = 0**（repo 本身 0 = 0）
#     （⚠️ 45 係**當時**嘅 corpus 大小：TMO-077 喺 2026-10-26 加咗第 46 支探針檔
#      `tests/doc-facts.bats` → 現況係 46 檔。口徑：`git ls-files 'tests/*.bats'
#      'skills/*/tests/*.bats' | wc -l`）
#   - **TMO-079 收窄嘅影響面（實測）**：全 corpus 依賴規則⑦ 豁免嘅斷言共 **9 條**，
#     全部喺 `@test` body 內；setup()／teardown()／helper function body 內 **0 條**
#     → 收窄（豁免只限 `@test` body）對真實 corpus **零影響**，唔會製造假紅。
#     方向亦都係**收緊**（豁免更少 → 報得更多），唔係放寬 → 唔會製造假綠。
#   - fuzz 200 檔 + 1000 檔（多 seed + 未閉合引號 / 各種 heredoc 變體）：
#     舊 2222 / 新 2213 → **新增 = 0**，少報嘅 9 個全部屬「內層區塊收尾」family
#   - 9 個針對性 edge case（`}` + 行尾註解 / `} else {` / `};` / 雙 `}` / 縮排 body `}` 等）：一致
#   - 10 個 edge case ＋ PNA-4b 嘅 7 條規則案例 ＋ PNA-4c 嘅 5 個案例（A~E）：一致
# ⚠️ **已知刻意差異（三處，唔係「唯一一處」）**：
#   ① heredoc 內容 strip 一次過做（純效能，唔影響判定結果）
#   ② **規則⑦ 刻意放寬**：原本「下一個非空行係行首 `}`」→ 現在多豁免「內層 `{ ... }`
#      區塊收尾」呢一類（原本會被誤判成 violation = latent 假紅）。
#      → 方向係**少報**（豁免更多），**唔會**新增 violation → 守門唔會變寬鬆到放過真違規。
#   ③ **規則⑦ 刻意收窄（TMO-079，2026-10-26）**：豁免要求「所屬頂層區塊**確實係
#      `@test` body**」→ `setup()`／`teardown()`／helper body 嘅斷言唔再被意外豁免。
#      → 方向係**多報**（豁免更少），**唔會**少報 → 唔會製造假綠。
#      ⚠️ ② 同 ③ 方向**相反**：② 係 TMO-078 嘅放寬（少報），③ 係 TMO-079 嘅收窄（多報）。
#         兩者同時存在 → 淨效果要靠實測：46 個探針檔新舊規則**逐檔零差異**（見上面）。
# ⚠️ **規則⑦ 嘅語意修正（TMO-078，2026-10-26）**：
#    原版規則⑦：「**下一個**非空行係行首 `}`」→ 內層 `{ ... }` 區塊嘅最後一句會被
#    誤判成 violation（**latent 假紅** —— 該斷言其實係 test body 嘅最後一個命令，
#    bats 會攞到佢嘅狀態 → 其實安全）。
#    新判準三步：① **下一個非空行若以行首 `}` 開頭 → 豁免**（與原判準逐字一致）
#    ② 否則若佢係「純收尾行」（剝空白後 == `}` 或 `};`）→ 繼續向後行，直到遇到行首 `}` → 豁免
#    ③ 一旦遇到其他 code → 唔豁免（照報 violation）。
#    → 新判準係**舊判準嘅超集**（舊判準豁免嘅全部照樣豁免）→ **唔可能新增 violation**。
#    ⚠️ **唔可以用「剝前導空白就算數」嘅 naive 修法** —— 咁樣會令
#       「內層區塊收尾之後仲有其他 code」嘅**真違規**變成 pass = 條件放寬 = 假綠。
#       新判準要求「中間全部都係純收尾行」正正就係為咗擋住呢個方向。
#
# ⚠️ 2026-10-26 修正：初版用 awk regex 直譯 shell 的 `case` glob，語意**唔等價**，
#    fuzz（200 個隨機樣板）捉到 31 個檔案唔一致，而且**方向係漏報（假綠）**。
#    三處差異（已修正；修正後與基準版 200/200 一致）：
#      ① 「行尾比對」：shell `case "$s" in *"||")` 要求 `||` 喺**行尾**；
#         awk `s ~ /\|\|/` 只要求「包含」→ 改成 `/\|\|$/`。
#      ② 「test body 最後一句」：shell 取 `after=$(awk 'NR>s && NF{print; exit}')`
#         ——**未剝前導空白** → `case "$after" in \}*)` 要求 `}` 喺**行首**；
#         初版剝咗空白先比 → 令「縮排的 `}`」被誤判為安全 → 改成用**原行**比對。
#      ③ heredoc 偵測嘅引號狀態：原版 `q` 喺 BEGIN 宣告（**跨行保留**，註解明講
#         「引號狀態跨行保存」）；初版放喺 function 內 local（每行重置）→ 改成全域 `gq`。
#    → 教訓：shell `case` 嘅 glob（尾端錨定）≠ awk regex（任意位置）。
#
# ─── 頂層區塊追蹤（TMO-079）──────────────────────────────────────────
#
# 點解要呢一層：規則⑦ 原本靠「下一個行首 `}`」呢個**隱含假設**認「test body 收尾」。
# 但行首 `}` 唔必然係 test body —— 佢亦可能關 setup()／teardown()／helper function
# （.bats 入面呢啲 function 嘅收尾 `}` 同樣喺行首）→ 同一個「行首 `}`」有兩種意義，
# 原判準分唔到。TMO-078 嘅 V03 二審當時裁定「保留原語意（超集性質優先）」，
# 但同時記低咗呢個更實際嘅假綠面 → backlog TMO-079。
#
# 而家逐行追蹤「頂層區塊」，記低每行所屬區塊嘅 kind 同關閉佢嘅行號：
#   opener ：column-0 行，剝註解後以 `{` 結尾（`${` 唔算 —— 係參數展開）
#   closer ：column-0 行，以 `}` 開頭
#   kind   ：test（`@test` 開頭）／func（`name() {` 或 `function name`）／other
#
# ⚠️ 點解淨係行 column-0（唔做全檔 brace-depth 計數）：
#   .bats 入面內層區塊一律**縮排** → column-0 嘅 `{` / `}` 恰好就係頂層區塊嘅邊界。
#   用佢哋做堆疊就唔使解析字串內嘅 `{}`（`${VAR}`、`awk '{...}'`、JSON heredoc 嘅
#   `}` … 全部唔使理）→ 對真實 corpus 零風險。
#
# ⚠️ 收窄嘅方向（關鍵）：豁免而家要求 kind == "test"。
#   → 方向係**收緊**（豁免更少 → 報得更多）→ 唔會製造假綠。
#   → 對真實 corpus 零影響（實測 9 條，全喺 @test body 內）。
#   → 對應 canary：PNA-4d（函式 body 必須照報／`} || {` 收尾必須唔報／對照組／
#     裸 column-0 群組必須照報）。
#
# 輸出格式（與原本 echo 相同，方便 diff 對照）：
#   <行號>\t<剝掉註解後的該行>
# 用法：probe_find_standalone_assertions <file>
probe_find_standalone_assertions() {
  awk '
    function strip(line,   i, c, nch, in_d, in_s, out, sq) {
      sq = sprintf("%c", 39)
      nch = length(line); out = ""; in_d = 0; in_s = 0
      for (i = 1; i <= nch; i++) {
        c = substr(line, i, 1)
        if (c == "\\" && (in_d || in_s)) { out = out c substr(line, i + 1, 1); i++; continue }
        if (c == "\"" && !in_s) { in_d = !in_d; out = out c; continue }
        if (c == sq && !in_d) { in_s = !in_s; out = out c; continue }
        if (c == "#" && !in_d && !in_s) {
          if (i == 1 || substr(line, i - 1, 1) ~ /[ \t]/) return out
          out = out c; continue
        }
        out = out c
      }
      return out
    }
    #     ⚠️ gq 係**全域**變數（唔係 local）→ 引號狀態跨行保留，
    #        同原版 probe_code_lines 一樣（原版 q 喺 BEGIN 宣告）。
    function is_heredoc_start(line,   nch, i, c, found, pos, rest, t) {
      nch = length(line); i = 1; found = 0; pos = 0
      while (i <= nch) {
        c = substr(line, i, 1)
        if (gq == "") {
          if (c == "\047") { gq = "\047"; i++; continue }
          if (c == "\"") { gq = "\""; i++; continue }
          if (c == "\\") { i += 2; continue }
          if (c == "<" && substr(line, i + 1, 1) == "<") { found = 1; pos = i; break }
        } else if (gq == "\047") {
          if (c == "\047") gq = ""
        } else {
          if (c == "\\") { i += 2; continue }
          if (c == "\"") gq = ""
        }
        i++
      }
      if (!found) return ""
      rest = substr(line, pos)
      if (match(rest, /^<<-?[[:space:]]*["\047]?[A-Za-z_][A-Za-z0-9_-]*["\047]?([[:space:]]*$|[[:space:]]+[0-9]*[>&|])/)) {
        t = substr(rest, RSTART, RLENGTH)
        sub(/[[:space:]]*[0-9]*[>&|].*$/, "", t)
        gsub(/<<-?[[:space:]]*/, "", t); gsub(/["\047]/, "", t)
        return t
      }
      return ""
    }
    { L[NR] = $0 }
    END {
      n = NR
      # 標出 heredoc 內的行（skip[] = 1 表示該行是 heredoc 內容，不是探針語句）
      skip = 0; gq = ""
      for (i = 1; i <= n; i++) {
        if (skip) { inhd[i] = 1; if (L[i] == tag) skip = 0; continue }
        t = is_heredoc_start(L[i])
        if (t != "") { tag = t; skip = 1; inhd[i+1] = 1 }
      }
      # ─── 頂層區塊追蹤（TMO-079）────────────────────────────────────────
      #
      # 為什麼要呢一層：規則⑦ 原本靠「下一個行首 `}`」呢個**隱含假設**去認
      # 「test body 收尾」。但行首 `}` 唔必然係 test body —— 佢亦可能關
      # setup()／teardown()／helper function（.bats 入面呢啲 function 嘅收尾
      # `}` 同樣喺行首）。→ 同一個「行首 `}`」有兩種意義，原判準分唔到。
      #
      # 而家改成**明確判定**：逐行追蹤「頂層區塊」（column-0 嘅 `{` / `}`），
      # 記低每行所屬區塊嘅 kind 同關閉佢嘅行號：
      #   opener ：column-0 行，剝註解後以 `{` 結尾（`${` 唔算 —— 係參數展開）
      #   closer ：column-0 行，以 `}` 開頭
      #   kind   ：test（`@test` 開頭）／func（`name() {` 或 `function name`）／other
      # 然後規則⑦ 唔再靠「搵到行首 `}`」，而係靠**所屬區塊嘅真實收尾行**。
      #
      # ⚠️ 為什麼淨係行 column-0（唔做全檔 brace-depth 計數）：
      #   .bats 入面內層區塊一律**縮排**，所以 column-0 嘅 `{` / `}` 恰好就係
      #   頂層區塊嘅邊界 —— 用佢哋做堆疊，唔使解析字串內嘅 `{}`（`${VAR}`、
      #   `awk '{...}'`、JSON heredoc 嘅 `}` … 全部唔使理）。
      #   → 對真實 corpus 零影響（實測：46 個探針檔內，依賴規則⑦ 豁免嘅斷言
      #     共 9 條，全部喺 `@test` body 內；setup/teardown/helper 內係 0 條）。
      sp = 0
      for (i = 1; i <= n; i++) {
        # 先記錄「呢行屬於邊個頂層區塊」（喺處理 opener/closer **之前**）
        blk_kind[i] = (sp > 0) ? st_kind[sp] : ""
        blk_open[i] = (sp > 0) ? st_open[sp] : 0
        if (inhd[i]) continue
        if (L[i] ~ /^[ \t]/) continue            # 只理 column-0 嘅行
        t = strip(L[i]); sub(/^[[:space:]]*/, "", t); sub(/[[:space:]]*$/, "", t)
        if (t ~ /^\}/) {
          # closer：關閉最內層頂層區塊（記低收尾行號）
          if (sp > 0) { blk_close_of[st_open[sp]] = i; sp-- }
          # `} || {` → 同一行關一個又開一個（開嗰個當 other）
          if (t ~ /\{$/ && t !~ /\$\{$/) { sp++; st_open[sp] = i; st_kind[sp] = "other" }
          continue
        }
        if (t ~ /\{$/ && t !~ /\$\{$/) {
          sp++
          st_open[sp] = i
          if (t ~ /^@test/) st_kind[sp] = "test"
          else if (t ~ /^[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([[:space:]]*\)/ || t ~ /^function[[:space:]]/) st_kind[sp] = "func"
          else st_kind[sp] = "other"
        }
      }
      # 補返每行所屬區塊嘅收尾行號（0 = 該區塊從來冇關閉）
      for (i = 1; i <= n; i++) {
        if (blk_open[i] > 0) blk_close[i] = blk_close_of[blk_open[i]]
      }

      for (i = 1; i <= n; i++) {
        if (inhd[i]) continue
        s = strip(L[i])
        sub(/^[[:space:]]*/, "", s); sub(/[[:space:]]*$/, "", s)
        if (s !~ /^\[\[/) continue
        # ④ guard clause → 安全
        if (s ~ /\|\| continue/ || s ~ /\|\| break/ || s ~ /\|\| return/ || s ~ /\|\| exit/ \
            || s ~ /&& continue/ || s ~ /&& break/) continue
        # ⑤ 同行有 return 1 → 安全
        if (s ~ /return 1/) continue
        # ⑥ fail-fast 區塊
        opens = 0
        if (s ~ /\|\| \{/ || s ~ /&& \{/) opens = 1
        else if (s ~ /\|\|$/ || s ~ /&&$/) {
          nl = L[i + 1]; sub(/^[[:space:]]*/, "", nl); sub(/[[:space:]]*$/, "", nl)
          if (nl ~ /^\{/) opens = 1
        }
        if (opens) {
          found = 0
          for (j = i + 1; j <= n; j++) {
            t = L[j]; sub(/^[ \t]+/, "", t)
            if (t ~ /^\}/) break
            if (t ~ /return 1/) { found = 1; break }
          }
          if (found) continue
        }
        # ⑦ 斷言係 **@test body** 嘅最後一個命令 → 安全
        #    判準（2026-10-26 TMO-078，經 V03 二審修正；2026-10-26 TMO-079 收緊）：
        #      ① **下一個非空行若以行首 `}` 開頭 → 豁免**（與原判準**完全一致**）
        #      ② 否則若佢係「純收尾行」（剝空白後 == `}` 或 `};`）→ 繼續向後行，
        #         直到遇到行首 `}`（= test body 收尾）→ 豁免
        #      ③ 一旦遇到其他 code → 唔豁免（照報 violation）
        #
        #    ⚠️ **超集性質（關鍵不變量）**：①令「下一個非空行係行首 `}`」呢個判斷
        #       **同原判準逐字一致** → 原判準豁免嘅全部照樣豁免 → **唔可能新增 violation**。
        #       （第一版寫成「t 必須恰好等於 `}`」→ `} # end of test` 會被誤報 = 假紅迴歸；
        #        V03 二審 P1-1 捉到，已修正。）
        #
        #    ⚠️ **TMO-079 收窄（2026-10-26）**：豁免而家要求「所屬頂層區塊**確實係
        #       `@test` body**」，而唔再係「撞到行首 `}` 就當係」。
        #       原因：行首 `}` 有兩種意義 —— 關 @test body，**或者**關 setup()／
        #       teardown()／helper function。TMO-078 嘅 V03 二審當時裁定「保留原語意
        #       （超集性質優先）」，但同時記低咗呢個更實際嘅假綠面（backlog TMO-079）。
        #       而家用「頂層區塊 kind」明確判定 → 函式 body 嘅斷言**唔再**被意外豁免。
        #       → 方向係**收緊**（豁免更少 → 報得更多），唔係放寬 → 唔會製造假綠。
        #       → 對真實 corpus 零影響（實測：9 條依賴規則⑦ 嘅斷言全部喺 @test body 內）。
        #
        #    豁免嘅**理由**（為什麼淨係 @test body 適用）：bats 取 **test body 最後一個
        #    命令**嘅狀態做測試結果 → 斷言喺最後就已經 fail-fast，唔使再包一層。
        #    函式 body 冇呢個保證（bats 對 setup/teardown 另有處理，helper 更加冇），
        #    所以唔豁免 → 要求寫成顯式 fail-fast 慣例。
        found_body_close = 0
        if (blk_kind[i] == "test" && blk_close[i] > 0) {
          for (j = i + 1; j <= n; j++) {
            if (L[j] ~ /[^ \t]/) {
              # ① 抵達「所屬 @test body 嘅真實收尾行」→ 豁免
              #    （TMO-079：唔再靠「搵到行首 `}`」，而係靠明確追蹤出嚟嘅收尾行）
              if (j == blk_close[i]) { found_body_close = 1; break }
              # ② 縮排嘅收尾行 → 繼續向後行
              t = strip(L[j]); sub(/^[[:space:]]*/, "", t); sub(/[[:space:]]*$/, "", t)
              if (t != "}" && t != "};") break      # ③ 其他 code → 唔豁免
            }
          }
        }
        if (found_body_close) continue
        # ⑧ violation
        print i "\t" s
      }
    }
  ' "$1"
}
