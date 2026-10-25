#!/usr/bin/env bash
# tests/helpers/probe-scan.bash
#
# 掃描 .bats 檔裡「bats 真的會當成 @test 的宣告」——**共 5 支**：
#   - probe_declared_names <file>：逐行印出每個 @test 宣告的**測試名稱**      ← 有呼叫者
#   - probe_declared_count <file>：印出宣告數                              ← 有呼叫者
#   - probe_strip_comment <file>：印出剝掉行尾註解後的每一行                ← **目前冇呼叫點**
#   - probe_code_lines <file>：印出「不在 heredoc 內」嘅行號+內容            ← **目前冇呼叫點**
#   - probe_find_standalone_assertions <file>：印出「無 fail-fast 嘅獨立 [[ ]] 斷言」← 有呼叫者
#
# ⚠️ `probe_strip_comment` 同 `probe_code_lines` 自 PNA-4 改用單 awk 行程後**冇咗呼叫點**
#    （其邏輯已複製入 `probe_find_standalone_assertions` 內）。保留佢哋係為咗唔擴大 diff，
#    但**唔再係 PNA-4 嘅權威實作**；將來要改 heredoc 偵測或剝註解邏輯，**改新函式嗰份**。
#    清死碼屬另一輪（**目前未開票**；見 docs/backlog.md TMO-078），唔喺效能改動內做。
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

# 去掉行尾註解（**引號感知**）。
# ⚠️ **目前冇呼叫點**（PNA-4 改用單 awk 行程後，其剝註解邏輯已複製入
#    `probe_find_standalone_assertions` 內）。保留作參考；改邏輯要兩邊同步。
# 為什麼不能用 `sed 's/#.*$//'`：字串裡的 '#' 會被誤當成註解起點——
# 例如 `[[ "$output" != *"# skip"* ]] || {` 會被砍成 `[[ "$output" != *"`。
# shell 的規則是：'#' 只有在**詞首**（行首或前一個字元是空白）且**不在引號內**才是註解。
probe_strip_comment() {
  awk '
    function strip(line,   i, c, nch, in_d, in_s, out, sq) {
      sq = sprintf("%c", 39)   # 單引號（用字元碼避開外層 shell 的引號衝突）
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
    { print strip($0) }
  ' "$1"
}

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

# 印出「不在 heredoc 內」的行號（每行一個行號 + 該行內容，用 TAB 分隔）。
# ⚠️ **目前冇呼叫點**（PNA-4 改用單 awk 行程後，其 heredoc 感知邏輯已複製入
#    `probe_find_standalone_assertions` 內）。保留作參考；改邏輯要兩邊同步。
# 為什麼需要：掃描「某種斷言寫法」的守門（例如 PNA-4）時，heredoc 內的示範碼
# **不是真的探針語句**——把它當成真斷言會假紅。ENV-EQ-9 的 census 已經有同樣的考量。
probe_code_lines() {
  awk '
    BEGIN { skip = 0; q = "" }
    {
      if (skip) { if ($0 == tag) skip = 0; next }
      nch = length($0); i = 1; found = 0; pos = 0
      while (i <= nch) {
        c = substr($0, i, 1)
        if (q == "") {
          if (c == "'"'"'") { q = "'"'"'"; i++; continue }
          if (c == "\"") { q = "\""; i++; continue }
          if (c == "\\") { i += 2; continue }
          if (c == "<" && substr($0, i + 1, 1) == "<") { found = 1; pos = i; break }
        } else if (q == "'"'"'") {
          if (c == "'"'"'") q = ""
        } else {
          if (c == "\\") { i += 2; continue }
          if (c == "\"") q = ""
        }
        i++
      }
      if (found) {
        rest = substr($0, pos)
        if (match(rest, /^<<-?[[:space:]]*["\047]?[A-Za-z_][A-Za-z0-9_-]*["\047]?([[:space:]]*$|[[:space:]]+[0-9]*[>&|])/)) {
          t = substr(rest, RSTART, RLENGTH)
          sub(/[[:space:]]*[0-9]*[>&|].*$/, "", t)
          gsub(/<<-?[[:space:]]*/, "", t); gsub(/["\047]/, "", t)
          tag = t; skip = 1
        }
      }
      print NR "\t" $0
    }
  ' "$1"
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
#       掃描器本身掃 45 個探針檔約 0.6–0.8s（每次量測會有 ±0.2s 浮動）
#     整個 `bats tests/ skills/` 總時間**唔寫死**（受機器負載影響，本機量到 2m42s–3m23s 幾個值）。
#
# 判斷規則與原本逐行版的**逐條對照**（左 = 原本 shell `case` glob，右 = 現版 awk regex）：
#   ① 只看不在 heredoc 內的行        ← 複製自 probe_code_lines（⚠️ 唔係「沿用」：兩份實作，
#                                        改其中一份**必須**同步另一份）
#   ② 剝掉行尾註解（引號感知）        ← 複製自 probe_strip_comment 的 strip()（同上，兩份）
#   ③ `[[ ... ]]` 開頭才算獨立斷言    ← case "$s" in \[\[*   ≡   s !~ /^\[\[/
#   ④ guard clause → 安全             ← *"|| continue"* 等（包含）  ≡  /\|\| continue/ 等（包含）
#   ⑤ 同行有 `return 1` → 安全        ← *"return 1"*（包含）          ≡  /return 1/（包含）
#   ⑥ `|| {` / `&& {`（同行）→ 開區塊 ← *"|| {"* / *"&& {"*（包含）≡ /\|\| \{/ / && \{/
#      `||` / `&&` **行尾** + 下一行開頭 `{` → 開區塊
#                                   ← *"||"* / *"&&"*（**行尾錨定**）≡ /\|\|$/ / /&&$/
#      區塊內（以 `}` 為界）有 `return 1` → 安全
#   ⑦ 之後第一個非空行**以 `}` 開頭（行首，冇前導空白）** → 安全
#                                   ← after=$(awk 'NR>s && NF{print; exit}')（**原行，未剝空白**）
#                                     + case "$after" in \}*  ≡  after ~ /^\}/
#   ⑧ 以上都不中 → 記一個 violation
#
# 等價範圍：**在已驗證嘅輸入集合上**與原本逐行版逐條等價
#   - 45 個真實探針檔：逐行 diff 0 差異（violations 0 = 0）
#   - fuzz 200 檔（隨機樣板）：0 差異
#   - fuzz 1000 檔（多 seed + 未閉合引號 / 各種 heredoc 變體）：0 差異（1866 = 1866）
#   - 10 個針對性 edge case ＋ PNA-4b 嘅 7 條規則案例：一致
# ⚠️ 已知刻意差異（唯一一處）：heredoc 內容 strip 一次過做（純效能，唔影響判定結果）。
# ⚠️ 已知**未**等價嘅方面（唔喺本次範圍，見 PNA-4 規格例外③）：縮排嘅 `}` 唔算
#    「test body 最後一句」——呢個係**原版既有行為**，刻意保留（改成認縮排 = 條件放寬 = 假綠）。
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
        # ⑦ 之後第一個非空行以 } 開頭 → 位於 test body 最後一句 → 安全
        after = ""
        for (j = i + 1; j <= n; j++) {
          if (L[j] ~ /[^ \t]/) { after = L[j]; break }
        }
        if (after ~ /^\}/) continue
        # ⑧ violation
        print i "\t" s
      }
    }
  ' "$1"
}
