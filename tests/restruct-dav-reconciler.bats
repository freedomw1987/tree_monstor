#!/usr/bin/env bats
#
# tests/restruct-dav-reconciler.bats
#
# Regression guards for TMO-072: dav-reconciler skill（需求對帳機制）
# + Gate 4.5 登錄（handbook §2.3 / AGENTS.md §2.3 / dav-submitter / dav-reflection）
#
# 設計依據：docs/prd/05-delivery-fidelity.md FR-02
#
# 注意：bats 1.14 的測試名不得含 CJK（會整支跳過 → 假綠），故本檔測試名全用 ASCII。

load 'helpers/test-env'

SKILL_DIR="skills/dav-reconciler"
SKILL="$REPO_ROOT/$SKILL_DIR/SKILL.md"
FORMAT_SPEC="$REPO_ROOT/$SKILL_DIR/reconcile-format.md"
DRIFT_IMPL="$REPO_ROOT/$SKILL_DIR/scripts/check-doc-drift.py"

# RECON-007 / RECON-016 共用的解析器：取出 §4「狀態表」資料列的第一欄（狀態值）。
#
# 為什麼是「結構式」而不是「掃 emoji」：
#   同一份文件裡「以 emoji 開頭的儲存格」≠「狀態值」——
#   §3 欄位定義表就用單獨的 ✅ 當「必填」標記（5 處），§2 範例表也有。
#   若用「掃所有 emoji 開頭儲存格」，往 §4 加一列說明性 emoji（例如 | 📌 備註 | … |）
#   就會讓**合法檔案**變紅（假紅）。故改以**表頭第一欄 ==「狀態」**定位狀態表。
#   （V03 Reviewer 第 2 輪 P2-2 的建議）
#
# 邊界：終止式用 ^## \d（只認編號 h2）—— 規格檔 §2 的 fenced code 內有
#   「## 對帳表」/「## 結論」，用寬鬆的 ^## 會誤把 code block 當成標題。
# fail-closed：找不到 §4 狀態表 → 回傳非 0（不得靜默當作「0 種狀態值」而紅在別處）。
_recon_status_values() {
  python3 - "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
# §4 區段：從「## 4. 」到下一個編號 h2（或 EOF）
m = re.search(r"^## 4\. [^\n]*\n(.*?)(?=^## \d|\Z)", text, re.MULTILINE | re.DOTALL)
if not m:
    print("FAIL: 規格檔找不到 §4 狀態值段", file=sys.stderr)
    sys.exit(2)
sec = m.group(1)

def split_tables(text):
    tables, cur = [], None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("|") and s.endswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if cur is None:
                cur = []
            cur.append(cells)
        else:
            if cur is not None:
                tables.append(cur)
                cur = None
    if cur is not None:
        tables.append(cur)
    return tables

# 找「狀態表」：表頭第一欄 == 「狀態」
for t in split_tables(sec):
    if not t or not t[0] or t[0][0] != "狀態":
        continue
    body = [r for r in t[1:] if not all(re.fullmatch(r"[-: ]*", c or "") for c in r)]
    for r in body:
        if r and r[0]:
            print(r[0])
    sys.exit(0)

print("FAIL: 找不到 §4 的狀態表（表頭第一欄須為「狀態」）", file=sys.stderr)
sys.exit(2)
PY
}

# 讀 check-doc-drift.py 的 VALID_STATUS（enforcement 端的詞彙表副本）
_recon_impl_status_values() {
  python3 - "$1" <<'PY'
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"^VALID_STATUS\s*=\s*\(([^)]*)\)", src, re.MULTILINE)
if not m:
    print("FAIL: check-doc-drift.py 找不到 VALID_STATUS", file=sys.stderr)
    sys.exit(2)
for v in re.findall(r'"([^"]*)"', m.group(1)):
    print(v)
PY
}

@test "RECON-001: skill dir and SKILL.md exist" {
  [ -d "$REPO_ROOT/$SKILL_DIR" ] || {
    echo "FAIL: 缺少 $SKILL_DIR" >&2
    return 1
  }
  [ -f "$SKILL" ] || {
    echo "FAIL: 缺少 $SKILL_DIR/SKILL.md" >&2
    return 1
  }
}

@test "RECON-002: frontmatter has name and description" {
  head -5 "$SKILL" | grep -qE '^name: dav-reconciler' || {
    echo "FAIL: frontmatter 缺 name: dav-reconciler" >&2
    return 1
  }
  head -8 "$SKILL" | grep -qE '^description: .+' || {
    echo "FAIL: frontmatter 缺 description" >&2
    return 1
  }
}

@test "RECON-003: five task-navigation sections exist" {
  local sec
  for sec in "## TL;DR" "## 觸發時機" "## 流程" "## 規則" "## 變動歷史"; do
    grep -qF "$sec" "$SKILL" || {
      echo "FAIL: SKILL.md 缺少段落：$sec" >&2
      return 1
    }
  done
}

@test "RECON-004: SKILL.md is within the 150 line limit" {
  local lines
  lines=$(wc -l < "$SKILL" | tr -d ' ')
  [ "$lines" -le 150 ] || {
    echo "FAIL: SKILL.md $lines 行 > 150 上限" >&2
    return 1
  }
}

@test "RECON-005: skill uses plain-text references only (no cross-dir markdown links)" {
  [ -f "$SKILL" ] || {
    echo "FAIL: 缺少 $SKILL_DIR/SKILL.md（檔案不存在時本測試會假綠）" >&2
    return 1
  }
  if grep -nE '\]\(\.\./|\]\(\.\./\.\./|\[\[|\]\(docs/|\]\(/' "$SKILL"; then
    echo "FAIL: SKILL.md 含跨目錄 markdown 連結（純文字引用規範 v2.2）" >&2
    return 1
  fi
  return 0
}

@test "RECON-006: reconcile format sub-file exists with required columns" {
  local fmt="$REPO_ROOT/$SKILL_DIR/reconcile-format.md"
  [ -f "$fmt" ] || {
    echo "FAIL: 缺少 $SKILL_DIR/reconcile-format.md" >&2
    return 1
  }
  local col
  for col in "需求 ID" "狀態" "實作位置" "證據"; do
    grep -qF "$col" "$fmt" || {
      echo "FAIL: reconcile-format.md 缺欄位：$col" >&2
      return 1
    }
  done
}

@test "RECON-007: exactly four allowed status values are defined" {
  [ -f "$FORMAT_SPEC" ] || {
    echo "FAIL: 缺少 $SKILL_DIR/reconcile-format.md（檔案不存在時本測試會假綠）" >&2
    return 1
  }
  [ -f "$DRIFT_IMPL" ] || {
    echo "FAIL: 缺少 $SKILL_DIR/scripts/check-doc-drift.py（檔案不存在時本測試會假綠）" >&2
    return 1
  }
  if ! command -v python3 >/dev/null 2>&1; then
    echo "FAIL: 缺 python3（無法解析狀態值；此探針必須 fail-closed，不得靜默略過）" >&2
    return 1
  fi
  #
  # 本探針的演進（V03 Reviewer 第 1 / 2 輪二審）：
  #
  # v1.0（原始）：用 `grep -oE '(✅|⚠️|❌|🚫) [^ |（(]+'` 抓狀態值。
  #   真實根因（實測確認）：**BSD grep 2.6 的 ERE 交替分支上限為 2**。
  #   `(✅|⚠️|❌|🚫)` 有 4 個分支 → grep -oE 只吐出**前 2 個**分支的匹配
  #   （❌ / 🚫 全被吞掉）→ count 只數得出 2 種 → 探針紅。
  #   實測證據（macOS / BSD grep 2.6.0-FreeBSD）：
  #     grep -oE '(✅)'            → 1 種
  #     grep -oE '(✅|⚠️)'         → 2 種
  #     grep -oE '(✅|⚠️|❌)'      → 2 種（❌ 被吞）
  #     grep -oE '(✅|⚠️|❌|🚫)'   → 2 種（❌ / 🚫 被吞）
  #     grep -oE '(a|b|c|d)'（純 ASCII）→ 4 種（正常）
  #   → 與「字串長度」無關（❌ 才 3 bytes 卻也被吞），**只與交替分支數有關**：
  #     分支 ≤ 2 正常，≥ 3 起只保留前 2 個。非字元類問題、非 locale 問題
  #     （LC_ALL=C 與 LC_ALL=en_US.UTF-8 結果相同）、**非跨行問題**
  #     （grep 逐行比對，緩衝區不含換行 → `[^ |（(]+` 不會跨行）。
  #   註：「⚠️」是 2 個 codepoint（U+26A0 + U+FE0F），用 char class `[✅⚠️❌🚫]`
  #     會把 VS16 與 U+26A0 拆開 → 同樣抓不到完整 token → 不可用 char class 替代。
  #
  # v1.1：改用 python3 + `re.finditer().group(0)`（明確 UTF-8 讀檔、Unicode 語意、
  #   逐行處理 → 兩平台逐位元組一致）。predicate 未變：同一 regex、同一 4 種門檻。
  #
  # v1.2（V03 Reviewer 第 2 輪 P2-1 / P2-2 / P2-3）：改為**結構式 + 集合等值 + 跨檔一致性**。
  #   ① 結構式：以「表頭第一欄 == 狀態」定位 §4 的狀態表（不掃 emoji）
  #      —— 理由：同一份文件裡「emoji 開頭儲存格」≠「狀態值」（§3 用單獨 ✅ 當
  #      「必填」標記 5 處、§2 範例表也有）→ 掃 emoji 會對合法檔案假紅。
  #   ② 集合等值（不是子字串）：`grep -qF` 是**子字串**比對 → 整格變成
  #      「✅ 已實作 🟡 暫緩」時 count 仍 4 且子字串命中 → **假綠**。故必須比集合。
  #   ③ 跨檔一致性：規格檔 §4 與 enforcement 端 `check-doc-drift.py` 的
  #      `VALID_STATUS` 是**同一份詞彙表的兩個副本** → 兩者不一致時原本無人察覺。
  #      這才是 P2-3 的真實洞（不只是「多一個新 emoji」）。
  local values impl_values
  values=$(_recon_status_values "$FORMAT_SPEC") || {
    echo "FAIL: 無法解析 $SKILL_DIR/reconcile-format.md §4 的狀態表（fail-closed）" >&2
    return 1
  }
  impl_values=$(_recon_impl_status_values "$DRIFT_IMPL") || {
    echo "FAIL: 無法解析 check-doc-drift.py 的 VALID_STATUS（fail-closed）" >&2
    return 1
  }
  # ① 規格檔 §4 的狀態值必須**恰為**這 4 個標準值（集合等值）
  local expected
  expected=$(printf '✅ 已實作\n⚠️ 部分實作\n❌ 未實作\n🚫 已作廢\n')
  [ "$(printf '%s\n' "$values" | LC_ALL=C sort)" = "$(printf '%s\n' "$expected" | LC_ALL=C sort)" ] || {
    echo "FAIL: §4 狀態值集合應恰為 4 個標準值，實際為：" >&2
    printf '%s\n' "$values" >&2
    return 1
  }
  # ② enforcement 端的詞彙表副本必須與規格檔**一致**（跨檔守護）
  [ "$impl_values" = "$values" ] || {
    echo "FAIL: check-doc-drift.py 的 VALID_STATUS 與規格檔 §4 不一致：" >&2
    echo "  規格檔 §4：" >&2
    printf '%s\n' "$values" >&2
    echo "  VALID_STATUS：" >&2
    printf '%s\n' "$impl_values" >&2
    return 1
  }
}

@test "RECON-016: status-vocabulary parser actually rejects a fifth status value" {
  # 反向自測：確認 RECON-007 的解析器**真的會咬**，而不是空轉。
  #
  # ⚠️ 陷阱（v1.2 修正前踩過）：mutate 時**不能**用全檔 `str.replace(old, new, 1)` ——
  #   「| ✅ 已實作 |」在 §2 的 fenced 範例（line 27）**先於** §4 的狀態表（line 56）出現，
  #   replace(...,1) 會改到 §2 → §4 根本不變 → 檢查變成空轉（假綠）。
  #   故所有 mutate 一律**只在 §4 區段內**操作（用與解析器同一套 section 抽取邏輯），
  #   且一律與「基準值」比較（不是與另一個突變值比較）。
  [ -f "$FORMAT_SPEC" ] || {
    echo "FAIL: 缺少 $SKILL_DIR/reconcile-format.md" >&2
    return 1
  }
  local baseline
  baseline=$(_recon_status_values "$FORMAT_SPEC") || {
    echo "FAIL: 無法解析 $SKILL_DIR/reconcile-format.md §4 的狀態表（fail-closed）" >&2
    return 1
  }
  local expected
  expected=$(printf '✅ 已實作\n⚠️ 部分實作\n❌ 未實作\n🚫 已作廢\n')
  [ "$(printf '%s\n' "$baseline" | LC_ALL=C sort)" = "$(printf '%s\n' "$expected" | LC_ALL=C sort)" ] || {
    echo "FAIL: 基準檔的 §4 狀態值就不等於 4 個標準值（先修基準）" >&2
    printf '%s\n' "$baseline" >&2
    return 1
  }

  # 情境 1：在 §4 狀態表加一列第 5 種狀態值（全新 emoji）→ 必須改變解析結果
  local copy1="$BATS_TEST_TMPDIR/format-mutant1.md"
  cp "$FORMAT_SPEC" "$copy1"
  python3 - "$copy1" <<'PYMUT'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
m = re.search(r"^## 4\. [^\n]*\n(.*?)(?=^## \d|\Z)", t, re.MULTILINE | re.DOTALL)
if not m:
    sys.exit("找不到 §4")
sec = m.group(1)
out = []
for line in sec.splitlines(keepends=True):
    out.append(line)
    if line.startswith("| 🚫 已作廢 |"):
        out.append("| 🟡 暫緩 | 第 5 種狀態值（不應被允許）|\n")
new_sec = "".join(out)
t = t[:m.start(1)] + new_sec + t[m.end(1):]
p.write_text(t, encoding="utf-8")
PYMUT
  local values1
  values1=$(_recon_status_values "$copy1") || {
    echo "FAIL: 反向自測無法解析複製檔（fail-closed）" >&2
    return 1
  }
  [ "$values1" != "$baseline" ] || {
    echo "FAIL: 反向自測失敗：§4 加入第 5 種狀態值後解析結果應改變，但沒有（探針可能空轉）" >&2
    return 1
  }

  # 情境 2：§4 某一整格變成子字串（舊的 grep -qF 子字串比對會漏掉）
  #   → 集合等值必須把它判為違規。
  local copy2="$BATS_TEST_TMPDIR/format-mutant2.md"
  cp "$FORMAT_SPEC" "$copy2"
  python3 - "$copy2" <<'PYMUT'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
t = p.read_text(encoding="utf-8")
m = re.search(r"^## 4\. [^\n]*\n(.*?)(?=^## \d|\Z)", t, re.MULTILINE | re.DOTALL)
if not m:
    sys.exit("找不到 §4")
sec = m.group(1)
new_sec = sec.replace("| ✅ 已實作 |", "| ✅ 已實作 🟡 暫緩 |", 1)
if new_sec == sec:
    sys.exit("§4 內找不到目標列")
t = t[:m.start(1)] + new_sec + t[m.end(1):]
p.write_text(t, encoding="utf-8")
PYMUT
  local values2
  values2=$(_recon_status_values "$copy2") || {
    echo "FAIL: 反向自測無法解析複製檔（fail-closed）" >&2
    return 1
  }
  [ "$values2" != "$baseline" ] || {
    echo "FAIL: 反向自測失敗：§4 整格變成「✅ 已實作 🟡 暫緩」應改變集合（子字串比對會漏掉）" >&2
    return 1
  }
}

@test "RECON-008: rules require full R-ID coverage in the reconcile table" {
  grep -qE 'R-ID' "$SKILL" || {
    echo "FAIL: SKILL.md 未要求對帳表覆蓋全部 R-ID" >&2
    return 1
  }
}

@test "RECON-009: skill defines the independent-subagent execution rule" {
  grep -qE '獨立 subagent' "$SKILL" || {
    echo "FAIL: SKILL.md 未登錄「未參與實作的獨立 subagent」規則" >&2
    return 1
  }
  grep -qE '降級' "$SKILL" || {
    echo "FAIL: SKILL.md 未登錄「無 subagent 時的降級路徑」" >&2
    return 1
  }
}

@test "RECON-010: dav-submitter enforces the reconcile hard gate" {
  local sub="$REPO_ROOT/skills/dav-submitter/SKILL.md"
  grep -qF "需求對帳" "$sub" || {
    echo "FAIL: dav-submitter SKILL.md 未登錄「需求對帳」段" >&2
    return 1
  }
  grep -qE '部分完成' "$sub" || {
    echo "FAIL: dav-submitter SKILL.md 未登錄對帳未過的降級狀態（部分完成）" >&2
    return 1
  }
}

@test "RECON-011: handbook 2.3 registers the Gate 4.5 reconcile sub-gate" {
  local hb="$REPO_ROOT/docs/sop/handbook/2.3-execution.md"
  grep -qF "Gate 4.5" "$hb" || {
    echo "FAIL: handbook 2.3 未登錄 Gate 4.5" >&2
    return 1
  }
  grep -qF "需求對帳" "$hb" || {
    echo "FAIL: handbook 2.3 未登錄「需求對帳」" >&2
    return 1
  }
}

@test "RECON-012: AGENTS.md gate quick-reference lists Gate 4.5" {
  local agents="$REPO_ROOT/AGENTS.md"
  grep -qF "Gate 4.5" "$agents" || {
    echo "FAIL: AGENTS.md §2.3 速查表未列 Gate 4.5" >&2
    return 1
  }
}

@test "RECON-013: dav-reflection states that reconcile runs before reflection" {
  local ref="$REPO_ROOT/skills/dav-reflection/SKILL.md"
  grep -qF "需求對帳" "$ref" || {
    echo "FAIL: dav-reflection SKILL.md 未說明與需求對帳的先後順序" >&2
    return 1
  }
}

@test "RECON-014: skill has CHANGELOG and main-file version matches" {
  local cl="$REPO_ROOT/$SKILL_DIR/CHANGELOG.md"
  [ -f "$cl" ] || {
    echo "FAIL: 缺少 $SKILL_DIR/CHANGELOG.md" >&2
    return 1
  }
  local v_skill v_cl
  v_skill=$(awk '/^## 變動歷史/{flag=1} flag' "$SKILL" | grep -oE '^\| v[0-9]+\.[0-9]+' | head -1 | tr -d '| ')
  v_cl=$(grep -oE '^\| v[0-9]+\.[0-9]+' "$cl" | head -1 | tr -d '| ')
  [ -n "$v_skill" ] && [ "$v_skill" = "$v_cl" ] || {
    echo "FAIL: 主檔最新版本($v_skill) 與 CHANGELOG($v_cl) 不一致" >&2
    return 1
  }
}

@test "RECON-015: skill does not read cross-directory project files" {
  [ -f "$SKILL" ] || {
    echo "FAIL: 缺少 $SKILL_DIR/SKILL.md（檔案不存在時本測試會假綠）" >&2
    return 1
  }
  if grep -nE '(見|詳見|參考|讀|讀取|grep|查|搜|掃) `?docs/' "$SKILL"; then
    echo "FAIL: SKILL.md 有跨目錄 docs/ 讀取引用（純文字引用 + 專案端路徑零容忍）" >&2
    return 1
  fi
  return 0
}
