#!/usr/bin/env bash
# tests/helpers/probe-scan.bash
#
# 掃描 .bats 檔裡「bats 真的會當成 @test 的宣告」——提供：
#   - probe_declared_names <file>：逐行印出每個 @test 宣告的**測試名稱**
#   - probe_declared_count <file>：印出宣告數
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
# 為什麼「名稱」比「數量」重要（TMO-072）：
#   bats 1.14 在 **UTF-8 locale** 下會**靜默丟棄**名稱含 CJK 等 Unicode 字母的 @test
#   （`bats: unknown test name` → "Executed N instead of expected M" → rc=1）。
#   但 `bats --count` **仍把它算進去** → 光比數量抓不到，必須看**名稱本身**。

# 去掉行尾註解（**引號感知**）。
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
