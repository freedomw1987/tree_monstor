#!/usr/bin/env bats
#
# tests/restruct-agents-md.bats
#
# Regression guards for TMO-009 stage 5: AGENTS.md
# restructured to "task-navigation" style.
# Note: AGENTS.md carries the soul principles (1. Who are you + V01/V02/V03);
# we preserve them verbatim and restructure ONLY around them.

load 'helpers/test-env'

@test "RESTRUCT-AGENTS-MD: TL;DR section exists at top" {
  local f="$REPO_ROOT/AGENTS.md"
  # First ## section after frontmatter should be TL;DR
  grep -q "^## TL;DR" "$f" || {
    echo "FAIL: AGENTS.md should have ## TL;DR as first major section" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: V01/V02/V03 preserved (discipline rules)" {
  local f="$REPO_ROOT/AGENTS.md"
  for v in "V01" "V02" "V03"; do
    grep -qF "$v" "$f" || {
      echo "FAIL: missing $v 紀律 reference" >&2
      return 1
    }
  done
}

@test "RESTRUCT-AGENTS-MD: core principles (soul) preserved" {
  local f="$REPO_ROOT/AGENTS.md"
  # Key phrases from the soul that must NOT be lost
  for phrase in "用戶好伙伴" "誠實" "負責任" "有承擔" "Think Big"; do
    grep -qF "$phrase" "$f" || {
      echo "FAIL: missing soul phrase '$phrase'" >&2
      return 1
    }
  done
}

@test "RESTRUCT-AGENTS-MD: SOP version references current version" {
  local f="$REPO_ROOT/AGENTS.md"
  assert_file_contains "$f" "## 變動歷史"
  # 現行 SOP 版本必在主檔可見（v2.2；v2.1 保留於歷史列）
  awk '/^## 變動歷史/,EOF' "$f" | grep -qE "v2\.2" || {
    echo "FAIL: 變動歷史 should reference current SOP version v2.2" >&2
    return 1
  }
  grep -qF "§2 SOP 流程（v2.2）" "$f" || {
    echo "FAIL: AGENTS.md section header should state current SOP version v2.2" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: 4 Gate table still present (Gate 1-4)" {
  local f="$REPO_ROOT/AGENTS.md"
  for gate in "Gate 1" "Gate 2" "Gate 3" "Gate 4"; do
    grep -qF "$gate" "$f" || {
      echo "FAIL: missing $gate reference" >&2
      return 1
    }
  done
}

@test "RESTRUCT-AGENTS-MD: trust mode registered as third path in 2.0" {
  local f="$REPO_ROOT/AGENTS.md"
  # 只在 §2.0 章節內找列（避免 §2.x 索引表或其他表格誤命中）
  local sec
  sec=$(awk '/^### §2\.0/{f=1;next} /^### /{f=0} f' "$f")
  local row
  row=$(echo "$sec" | awk -F'|' '/^\|.*信任模式/ {print; exit}')
  [ -n "$row" ] || {
    echo "FAIL: AGENTS.md 2.0 table should have a 信任模式 row" >&2
    return 1
  }
  echo "$row" | grep -qF "§2.3" || {
    echo "FAIL: trust row should route to execution section (2.3)" >&2
    return 1
  }
  echo "$row" | grep -qF "§2.5" || {
    echo "FAIL: trust row should route to submission section (2.5)" >&2
    return 1
  }
  # trust 路徑不得包含規劃 / 設計階段（它們是啟動前置條件）
  # 限欄檢查：只取「走哪條 SOP」欄，避免該列其他欄位出現 §2.1 / §2.2 造成 false-red
  local sop_col
  sop_col=$(echo "$row" | awk -F'|' '{print $3}')
  if echo "$sop_col" | grep -qF "§2.1"; then
    echo "FAIL: trust row must NOT include planning stage (2.1)" >&2
    return 1
  fi
  if echo "$sop_col" | grep -qF "§2.2"; then
    echo "FAIL: trust row must NOT include design stage (2.2)" >&2
    return 1
  fi
}

@test "RESTRUCT-AGENTS-MD: trust precondition stated in judgment section" {
  local f="$REPO_ROOT/AGENTS.md"
  # 區段限定：只檢「判斷責任歸屬」區塊（避免 §2.0 表列的「前置條件」字眼就假綠）
  local sec
  sec=$(awk '/^\*\*判斷責任歸屬\*\*/{f=1} f&&/^> ⚠️ v1\.5/{f=0} f' "$f")
  echo "$sec" | grep -qF "前置條件" || {
    echo "FAIL: judgment section should state planning/design are trust preconditions" >&2
    return 1
  }
  echo "$sec" | grep -qF "trust 內不跑" || {
    echo "FAIL: judgment section should state planning/design do NOT run inside trust" >&2
    return 1
  }
  return 0
}

@test "RESTRUCT-AGENTS-MD: 2.6 handbook excludes trust mode from upgrade triggers" {
  local h="$REPO_ROOT/docs/sop/handbook/2.6-general-task.md"
  grep -qF "trust mode 進行中" "$h" || {
    echo "FAIL: 2.6 handbook should state trust-mode exception" >&2
    return 1
  }
  # 完整片語：例外對象 = 升級觸發器表（避免兩句分開出現而語意不相干）
  grep -qF "上表升級觸發器不套用" "$h" || {
    echo "FAIL: 2.6 handbook should state upgrade triggers do not apply in trust mode" >&2
    return 1
  }
  return 0
}

@test "RESTRUCT-AGENTS-MD: dev-task row and priority order present in 2.0" {
  local f="$REPO_ROOT/AGENTS.md"
  local sec
  sec=$(awk '/^### §2\.0/{f=1;next} /^### /{f=0} f' "$f")
  local row
  row=$(echo "$sec" | awk -F'|' '/^\|.*開發編程任務/ {print; exit}')
  [ -n "$row" ] || {
    echo "FAIL: AGENTS.md 2.0 table should still have a 開發編程任務 row" >&2
    return 1
  }
  echo "$row" | grep -qF "§2.1" || {
    echo "FAIL: 開發編程任務 row should route to the full SOP (2.1)" >&2
    return 1
  }
  # 判斷優先序字串是第 1 輪 P1 的修法核心 → 必須有探針守
  grep -qF "trust mode > 開發編程任務 > 一般任務" "$f" || {
    echo "FAIL: AGENTS.md should state the trust-first judgment priority" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: general-task row still present in 2.0" {
  local f="$REPO_ROOT/AGENTS.md"
  # 重排 §2.0 表時若誤刪「一般任務」列會無聲退化 → 只在 §2.0 章節內找該列
  local sec
  sec=$(awk '/^### §2\.0/{f=1;next} /^### /{f=0} f' "$f")
  local row
  row=$(echo "$sec" | awk -F'|' '/^\|.*一般任務/ {print; exit}')
  [ -n "$row" ] || {
    echo "FAIL: AGENTS.md 2.0 table should still have a 一般任務 row" >&2
    return 1
  }
  echo "$row" | grep -qF "2.6-general-task.md" || {
    echo "FAIL: 一般任務 row should route to 2.6-general-task.md" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: 2.1/2.2 handbook mark trust as pre-start condition" {
  local h1="$REPO_ROOT/docs/sop/handbook/2.1-planning.md"
  local h2="$REPO_ROOT/docs/sop/handbook/2.2-design.md"
  grep -qF "trust mode 進行中不適用本節" "$h1" || {
    echo "FAIL: 2.1 handbook should mark trust-mode exception" >&2; return 1; }
  grep -qF "trust mode 進行中不適用本節" "$h2" || {
    echo "FAIL: 2.2 handbook should mark trust-mode exception" >&2; return 1; }
  grep -qF "啟動前置條件" "$h1" || {
    echo "FAIL: 2.1 handbook should state trust pre-start condition" >&2; return 1; }
  grep -qF "啟動前置條件" "$h2" || {
    echo "FAIL: 2.2 handbook should state trust pre-start condition" >&2; return 1; }
}

@test "RESTRUCT-AGENTS-MD: 2.3 handbook excludes ask_user strategy in trust mode" {
  local h="$REPO_ROOT/docs/sop/handbook/2.3-execution.md"
  # trust 真正會跑 §2.3 → gates.json 的 ask_user 策略 / fallback 在 trust 內不適用
  grep -qF "trust mode 進行中" "$h" || {
    echo "FAIL: 2.3 handbook should state trust-mode exception" >&2; return 1; }
  grep -qF "不適用" "$h" || {
    echo "FAIL: 2.3 handbook should state ask_user strategy does not apply in trust mode" >&2
    return 1; }
  grep -qF "trust-log" "$h" || {
    echo "FAIL: 2.3 handbook should route trust-mode failures to trust-log" >&2; return 1; }
}

@test "RESTRUCT-AGENTS-MD: 2.4 handbook excludes user confirmation in trust mode" {
  local h="$REPO_ROOT/docs/sop/handbook/2.4-reflection.md"
  # Sprint / Module 必須有用戶參與確認 → trust 內會死鎖，必須有例外
  grep -qF "trust mode 進行中" "$h" || {
    echo "FAIL: 2.4 handbook should state trust-mode exception" >&2; return 1; }
  # 斷言完整片語（避免只靠檔頭例外、operational 條款未就地例外）
  grep -qF "必須有用戶參與確認（**trust mode 進行中除外**）" "$h" || {
    echo "FAIL: 2.4 handbook rule line should carry the trust-mode carve-out" >&2
    return 1; }
  grep -qF "沒有用戶參與確認（trust mode 進行中除外）" "$h" || {
    echo "FAIL: 2.4 fake-pass list should carry the trust-mode carve-out" >&2
    return 1; }
  grep -qF "need-you-help" "$h" || {
    echo "FAIL: 2.4 handbook should route trust-mode decisions to need-you-help" >&2
    return 1; }
}

@test "RESTRUCT-AGENTS-MD: SOP changelog records v2.10 and review verdict" {
  local c="$REPO_ROOT/docs/sop/handbook/changelog.md"
  grep -qF "## v2.10 — 2026-10-23" "$c" || {
    echo "FAIL: changelog should record the v2.10 entry" >&2; return 1; }
  grep -qF "二審結論（V03 Reviewer）" "$c" || {
    echo "FAIL: changelog v2.10 should carry a review-verdict section" >&2; return 1; }
}

@test "RESTRUCT-AGENTS-MD: Gate 4.5 is registered in AGENTS.md and handbook 2.3" {
  local f="$REPO_ROOT/AGENTS.md"
  local h="$REPO_ROOT/docs/sop/handbook/2.3-execution.md"
  grep -qF "Gate 4.5" "$f" || {
    echo "FAIL: AGENTS.md should list Gate 4.5 in the gate quick-reference" >&2; return 1; }
  grep -qF "Gate 4.5" "$h" || {
    echo "FAIL: handbook 2.3 should register Gate 4.5" >&2; return 1; }
  # Gate 4.5 刻意不進 gates.json（schema 限制），但 mandatory_phrase 必須在 handbook 裡
  grep -qF "mandatory_phrase" "$h" || {
    echo "FAIL: handbook 2.3 should carry the Gate 4.5 mandatory_phrase" >&2; return 1; }
  [ -f "$REPO_ROOT/docs/sop/gates.json" ] || {
    echo "FAIL: gates.json 不存在（反向鎖會假綠）" >&2; return 1; }
  grep -qF "Gate 4.5" "$REPO_ROOT/docs/sop/gates.json" && {
    echo "FAIL: gates.json should NOT contain Gate 4.5 (ADR-D1: schema only allows integer gate ids)" >&2; return 1; }
  return 0
}

@test "RESTRUCT-AGENTS-MD: SOP changelog records v2.11 and review verdict" {
  local c="$REPO_ROOT/docs/sop/handbook/changelog.md"
  grep -qF "## v2.11 — 2026-10-26" "$c" || {
    echo "FAIL: changelog should record the v2.11 entry" >&2; return 1; }
  grep -qF "二審結論（V03 Reviewer）" "$c" || {
    echo "FAIL: changelog v2.11 should carry a review-verdict section" >&2; return 1; }
}

@test "RESTRUCT-AGENTS-MD: change history section exists" {
  local f="$REPO_ROOT/AGENTS.md"
  grep -q "^## 變動歷史" "$f" || {
    echo "FAIL: AGENTS.md should have ## 變動歷史 section" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: handbook chapter index still exists" {
  local f="$REPO_ROOT/AGENTS.md"
  # Should still link to the 7 handbook files
  for ch in "2.1-planning" "2.2-design" "2.3-execution" "2.4-reflection" "2.5-submission" "2.6-general-task" "2.7-violations" "changelog"; do
    grep -qF "$ch" "$f" || {
      echo "FAIL: missing handbook link '$ch'" >&2
      return 1
    }
  done
}

@test "RESTRUCT-AGENTS-MD: install symlink path explanation preserved" {
  local f="$AGENTS.md"
  local f="$REPO_ROOT/AGENTS.md"
  # The V03 + install rules should still mention symlink
  grep -qF "symlink" "$f" || {
    echo "FAIL: AGENTS.md should still mention symlink (install rule)" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: SOUL.md cross-reference preserved" {
  local f="$REPO_ROOT/AGENTS.md"
  grep -qF "SOUL.md" "$f" || {
    echo "FAIL: AGENTS.md should still reference SOUL.md" >&2
    return 1
  }
}

@test "RESTRUCT-AGENTS-MD: file size sanity (was 85; allow up to 130 after restructure)" {
  local f="$REPO_ROOT/AGENTS.md"
  local lines
  lines=$(wc -l < "$f")
  [ "$lines" -lt 130 ] || {
    echo "FAIL: AGENTS.md grew too large ($lines lines, target < 130)" >&2
    return 1
  }
}
