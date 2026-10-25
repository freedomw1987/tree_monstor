#!/usr/bin/env bats
#
# tests/doc-drift.bats
#
# 需求錨點（TMO-071）與文件漂移（TMO-073）的機械化探針。
#
# 設計依據：docs/prd/05-delivery-fidelity.md（FR-01 / FR-03）
# 對應 US：TMO-071（階段 1）、TMO-073（階段 3）
#
# 探針哲學：
#   - 抓「同一件事多份文件各說各話」的字面漂移，不做語意判斷
#   - 白名單必須帶理由（fail-closed），不得靜默跳過
#   - 每條探針都要能「被破壞時變紅」（見 tests/mutant-must-die.bats 慣例）

load 'helpers/test-env'

REQ_DIR="docs/req"

# 取得 docs/req/ 下所有錨點檔（檔名不含副檔名）
_anchor_files() {
  find "$REPO_ROOT/$REQ_DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort
}

# 取出某檔「用戶原話（唯讀）」段的 R-ID 清單
_anchor_rids() {
  local f="$1"
  awk '/^## 用戶原話/{flag=1;next} /^## /{flag=0} flag' "$f" \
    | grep -oE '^- R[0-9]+' | grep -oE '[0-9]+'
}

# ---------------------------------------------------------------------------
# Stage 1 — 需求錨點（TMO-071）
# ---------------------------------------------------------------------------

@test "DOC-DRIFT-001: anchor dir exists and is non-empty" {
  local dir="$REPO_ROOT/$REQ_DIR"
  [ -d "$dir" ] || {
    echo "FAIL: 需求錨點目錄不存在：$REQ_DIR" >&2
    return 1
  }
  [ -n "$(_anchor_files)" ] || {
    echo "FAIL: $REQ_DIR 下沒有任何錨點檔" >&2
    return 1
  }
}

@test "DOC-DRIFT-002: anchor file has the 4 required sections" {
  local f count=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    count=$((count + 1))
    local seg
    for seg in "## 用戶原話（唯讀）" "## 澄清後驗收句" "## 變更歷史"; do
      grep -qF "$seg" "$f" || {
        echo "FAIL: $(basename "$f") 缺少段落：$seg" >&2
        return 1
      }
    done
    grep -qE '^# .*需求錨點' "$f" || {
      echo "FAIL: $(basename "$f") 標題應為「<US-ID> 需求錨點」" >&2
      return 1
    }
  done < <(_anchor_files)
  [ "$count" -gt 0 ] || {
    echo "FAIL: 沒有任何錨點檔可檢查（空集合假綠）" >&2
    return 1
  }
}

@test "DOC-DRIFT-003: anchor R-IDs are sequential and unique" {
  local f count=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    count=$((count + 1))
    local ids expected
    ids=$(_anchor_rids "$f" | tr '\n' ' ')
    [ -n "${ids// /}" ] || {
      echo "FAIL: $(basename "$f") 的「用戶原話」段沒有任何 R-ID" >&2
      return 1
    }
    expected=$(seq 1 $(echo "$ids" | wc -w | tr -d ' '))
    if [ "$ids" != "$(echo $expected) " ]; then
      echo "FAIL: $(basename "$f") R-ID 不連續或重複：得到 [$ids] 期待 [$expected]" >&2
      return 1
    fi
  done < <(_anchor_files)
  [ "$count" -gt 0 ] || {
    echo "FAIL: 沒有任何錨點檔可檢查（空集合假綠）" >&2
    return 1
  }
}

@test "DOC-DRIFT-004: clarified R-IDs match original R-IDs" {
  local f count=0
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    count=$((count + 1))
    local orig clar
    orig=$(_anchor_rids "$f" | sort -n | tr '\n' ' ')
    clar=$(awk '/^## 澄清後驗收句/{flag=1;next} /^## /{flag=0} flag' "$f" \
      | grep -oE '^- R[0-9]+' | grep -oE '[0-9]+' | sort -n | tr '\n' ' ')
    if [ "$orig" != "$clar" ]; then
      echo "FAIL: $(basename "$f") 驗收句 R-ID [$clar] 與原話 R-ID [$orig] 不一致" >&2
      return 1
    fi
  done < <(_anchor_files)
  [ "$count" -gt 0 ] || {
    echo "FAIL: 沒有任何錨點檔可檢查（空集合假綠）" >&2
    return 1
  }
}

@test "DOC-DRIFT-005: dav-planner rules require anchor file output" {
  local skill="$REPO_ROOT/skills/dav-planner/SKILL.md"
  assert_file_contains "$skill" "## 規則"
  grep -qE "錨點" "$skill" || {
    echo "FAIL: dav-planner SKILL.md 未登錄「需求錨點檔」規則" >&2
    return 1
  }
}

@test "DOC-DRIFT-006: dav-planner spec defines anchor structure and R-ID rules" {
  local rules="$REPO_ROOT/skills/dav-planner/backlog-rules.md"
  assert_file_contains "$rules" "需求錨點"
  grep -qE 'R-ID|R<n>|R1' "$rules" || {
    echo "FAIL: backlog-rules.md 未定義 R-ID 規則" >&2
    return 1
  }
}

@test "DOC-DRIFT-007: every AC template has a matching anchor file or whitelist" {
  local ac whitelist
  ac="$REPO_ROOT/docs/ac"
  whitelist="$REPO_ROOT/docs/ci/drift-whitelist.txt"
  local key missing="" count=0
  for f in "$ac"/*.md; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in README.md) continue ;; esac
    count=$((count + 1))
    key=$(basename "$f" .md)
    if [ ! -f "$REPO_ROOT/$REQ_DIR/$key-requirement.md" ]; then
      # 允許白名單豁免（存量 US 未回補錨點）
      if [ -f "$whitelist" ] && grep -qE "^D6#$key#" "$whitelist"; then
        continue
      fi
      missing="$missing $key"
    fi
  done
  [ "$count" -gt 0 ] || {
    echo "FAIL: 沒有任何 AC 範本可檢查（空集合假綠）" >&2
    return 1
  }
  [ -z "$missing" ] || {
    echo "FAIL: 下列 AC 範本缺對應需求錨點檔：$missing" >&2
    return 1
  }
}

# ---------------------------------------------------------------------------
# Stage 3 — 漂移檢查腳本（TMO-073）
# ---------------------------------------------------------------------------

DRIFT_SCRIPT="$REPO_ROOT/scripts/ci/check-doc-drift.sh"

# 跨平台取代字串（不用 `sed -i`：BSD 與 GNU 的 -i 語法不同，會讓 Ubuntu CI 腿紅）
_replace_in_file() {
  local f="$1" from="$2" to="$3"
  python3 - "$f" "$from" "$to" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
if sys.argv[2] not in text:
    print(f"WARN: pattern not found in {path}: {sys.argv[2]!r}", file=sys.stderr)
path.write_text(text.replace(sys.argv[2], sys.argv[3]), encoding="utf-8")
PY
}

# 建立一個最小可用專案（供腳本檢查）
_make_fixture() {
  local root="$1"
  mkdir -p "$root/docs/ac" "$root/docs/prd" "$root/docs/deliverable" "$root/docs/req" "$root/docs/reconcile"
  cat > "$root/docs/backlog.md" <<'EOF'
# Backlog

| ID | 主題 | 優先級 | 點數 | 狀態 | 依賴 |
| --- | --- | --- | --- | --- | --- |
| DEMO-001 | demo feature | P1 | 1 | done (2026-10-26) | — |
EOF
  cat > "$root/docs/ac/DEMO-001.md" <<'EOF'
# DEMO-001 AC 範本

> 對應 Backlog: DEMO-001
> 狀態: done (2026-10-26)

## Given / When / Then

### AC01

- **Given** something
EOF
  cp "$root/docs/ac/DEMO-001.md" "$root/docs/ac/DEMO-001.html"
  cat > "$root/docs/req/DEMO-001-requirement.md" <<'EOF'
# DEMO-001 需求錨點

## 用戶原話（唯讀）

- R1: 「demo」

## 澄清後驗收句

- R1: demo 做出來了

## 變更歷史

| 日期 | 變更 | 原因 |
| --- | --- | --- |
| 2026-10-26 | 初版 | demo |
EOF
  cat > "$root/docs/prd/01-demo.md" <<'EOF'
# PRD-01 demo

## 追溯矩陣

| FR | User Story | 對應畫面 | 原型檔案 | 狀態 |
| --- | --- | --- | --- | --- |
| FR-01 demo | DEMO-001 | N/A | N/A | 已原型 |
EOF
  cat > "$root/docs/reconcile/DEMO-001-reconcile.md" <<'EOF'
# DEMO-001 需求對帳表

> 對帳者: demo-subagent | 對帳時間: 2026-10-26 | 錨點: docs/req/DEMO-001-requirement.md
> 覆蓋率: 1/1

## 對帳表

| 需求 ID | 需求句（摘要） | 狀態 | 實作位置 | 證據 | 備註 |
|---------|---------------|------|---------|------|------|
| R1 | demo | ✅ 已實作 | docs/ac/DEMO-001.md:1 | demo probe | |
EOF
  cat > "$root/docs/deliverable/2026-10-26-demo.md" <<'EOF'
# demo

> **交付狀態**: ✅ 完成

## 變更清單

- `docs/ac/DEMO-001.md` — 產出 AC 範本

## 3.1 需求對帳

| 需求 ID | 需求句（摘要） | 對帳狀態 | 實作位置 | 證據 |
|---------|---------------|---------|---------|------|
| R1 | demo | ✅ 已實作 | docs/ac/DEMO-001.md:1 | demo probe |
EOF
}

@test "DOC-DRIFT-008: drift check script exists and is executable" {
  [ -f "$DRIFT_SCRIPT" ] || {
    echo "FAIL: 缺少 scripts/ci/check-doc-drift.sh" >&2
    return 1
  }
  [ -x "$DRIFT_SCRIPT" ] || {
    echo "FAIL: check-doc-drift.sh 不可執行" >&2
    return 1
  }
}

@test "DOC-DRIFT-009: clean project returns rc 0" {
  local root="$BATS_TEST_TMPDIR/clean"
  _make_fixture "$root"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 乾淨專案應 rc=0，實際 $status" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-010: missing backlog file returns rc 2 (not applicable)" {
  local root="$BATS_TEST_TMPDIR/nobacklog"
  mkdir -p "$root/docs"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 2 ] || {
    echo "FAIL: 缺 docs/backlog.md 應 rc=2，實際 $status" >&2
    return 1
  }
}

@test "DOC-DRIFT-036: invalid --from-date fails closed (rc 2), not silent scope shrink" {
  local root="$BATS_TEST_TMPDIR/badfromdate"
  _make_fixture "$root"
  # --from-date 只接受 YYYY-MM-DD。格式不合法時必須 rc=2（用法錯誤），
  # 不得靜默把檢查範圍縮成空集（否則 D8 硬門檻會被一個 typo 關掉 → 假綠）。
  run bash "$DRIFT_SCRIPT" --root "$root" --from-date "bad-date"
  [ "$status" -eq 2 ] || {
    echo "FAIL: 非法 --from-date 應 rc=2，實際 $status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE 'from-date' || {
    echo "FAIL: 錯誤訊息應點名 from-date" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-037: invalid --from-date must not silently disable the D8 hard gate" {
  local root="$BATS_TEST_TMPDIR/badfromdate_d8"
  _make_fixture "$root"
  # 先做一份「對帳有 gap 但宣告 ✅ 完成」的交付摘要 → 有效 from-date 下必被 D8 抓到。
  # 若 --from-date 格式錯誤讓檢查範圍被清空，這筆假綠就會漏過 → 對帳機制失效。
  _replace_in_file "$root/docs/deliverable/2026-10-26-demo.md" "✅ 已實作" "⚠️ 部分實作"
  run bash "$DRIFT_SCRIPT" --root "$root" --from-date "2026-10-26"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 基準情境（有效 from-date）應抓到 D8 違規，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  # 同一份 repo，from-date 給錯 → 必須是 rc=2（ loud fail ），不得是 rc=0（靜默放行）
  run bash "$DRIFT_SCRIPT" --root "$root" --from-date "2026-13-45"
  [ "$status" -eq 2 ] || {
    echo "FAIL: 非法 from-date 必須 rc=2，不得靜默放行假綠，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-011: D1 catches AC status drift vs backlog" {
  local root="$BATS_TEST_TMPDIR/d1"
  _make_fixture "$root"
  _replace_in_file "$root/docs/ac/DEMO-001.md" "狀態: done (2026-10-26)" "狀態: PENDING"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D1 應抓到狀態不同步，實際 rc=$status" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D1 DEMO-001' || {
    echo "FAIL: 輸出應含 'DRIFT D1 DEMO-001'" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-012: D2 catches non-sequential AC numbering" {
  local root="$BATS_TEST_TMPDIR/d2"
  _make_fixture "$root"
  _replace_in_file "$root/docs/ac/DEMO-001.md" "### AC01" "### AC02"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D2 應抓到 AC 編號不連續，實際 rc=$status" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D2 DEMO-001' || {
    echo "FAIL: 輸出應含 'DRIFT D2 DEMO-001'" >&2
    return 1
  }
}

@test "DOC-DRIFT-013: D3 catches ghost ID in PRD traceability matrix" {
  local root="$BATS_TEST_TMPDIR/d3"
  _make_fixture "$root"
  _replace_in_file "$root/docs/prd/01-demo.md" "DEMO-001" "GHOST-999"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D3 應抓到幽靈 ID，實際 rc=$status" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D3 .*GHOST-999' || {
    echo "FAIL: 輸出應含 'DRIFT D3 ... GHOST-999'" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-014: D4 catches missing file referenced by a deliverable" {
  local root="$BATS_TEST_TMPDIR/d4"
  _make_fixture "$root"
  echo '- `docs/ac/GHOST.md` — 不存在的檔案' >> "$root/docs/deliverable/2026-10-26-demo.md"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D4 應抓到不存在的檔案，實際 rc=$status" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D4 .*GHOST\.md' || {
    echo "FAIL: 輸出應含 'DRIFT D4 ... GHOST.md'" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-015: D4 ignores deliverables older than the from-date" {
  local root="$BATS_TEST_TMPDIR/d4old"
  _make_fixture "$root"
  mv "$root/docs/deliverable/2026-10-26-demo.md" "$root/docs/deliverable/2026-01-01-old.md"
  echo '- `docs/ac/GHOST.md` — 不存在的檔案' >> "$root/docs/deliverable/2026-01-01-old.md"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 0 ] || {
    echo "FAIL: from-date 之前的交付不應回溯檢查，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-016: D5 catches md/html status mismatch" {
  local root="$BATS_TEST_TMPDIR/d5"
  _make_fixture "$root"
  _replace_in_file "$root/docs/ac/DEMO-001.html" "狀態: done (2026-10-26)" "狀態: PENDING"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D5 應抓到 md/html 狀態不一致，實際 rc=$status" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D5 DEMO-001' || {
    echo "FAIL: 輸出應含 'DRIFT D5 DEMO-001'" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-017: D6 catches missing requirement anchor" {
  local root="$BATS_TEST_TMPDIR/d6"
  _make_fixture "$root"
  rm "$root/docs/req/DEMO-001-requirement.md"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D6 應抓到缺需求錨點，實際 rc=$status" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D6 DEMO-001' || {
    echo "FAIL: 輸出應含 'DRIFT D6 DEMO-001'" >&2
    return 1
  }
}

@test "DOC-DRIFT-018: whitelist entry without reason fails closed (rc 2)" {
  local root="$BATS_TEST_TMPDIR/wl_noreason"
  _make_fixture "$root"
  mkdir -p "$root/docs/ci"
  echo "D6#DEMO-001#" > "$root/docs/ci/drift-whitelist.txt"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 2 ] || {
    echo "FAIL: 白名單缺理由應 rc=2，實際 $status" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-019: whitelist wildcard for a whole class is rejected (rc 2)" {
  local root="$BATS_TEST_TMPDIR/wl_wildcard"
  _make_fixture "$root"
  mkdir -p "$root/docs/ci"
  echo "D6#*#整類豁免" > "$root/docs/ci/drift-whitelist.txt"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 2 ] || {
    echo "FAIL: 白名單全類豁免應 rc=2，實際 $status" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-020: whitelist hit is reported, not silently skipped" {
  local root="$BATS_TEST_TMPDIR/wl_hit"
  _make_fixture "$root"
  rm "$root/docs/req/DEMO-001-requirement.md"
  mkdir -p "$root/docs/ci"
  echo "D6#DEMO-001#存量未回補" > "$root/docs/ci/drift-whitelist.txt"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 命中白名單應 rc=0，實際 $status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^WHITELIST D6 DEMO-001: 存量未回補$' || {
    echo "FAIL: 豁免必須輸出說明（WHITELIST D6 DEMO-001: ...）" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-021: real repo passes the drift check (no violations)" {
  run bash "$DRIFT_SCRIPT" --root "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 本 repo 應無漂移，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-022: CI workflow really calls the drift check and cannot be faked green" {
  local ci="$REPO_ROOT/.github/workflows/ci.yml"
  [ -f "$ci" ] || {
    echo "FAIL: 找不到 $ci" >&2
    return 1
  }
  grep -qF "check-doc-drift.sh" "$ci" || {
    echo "FAIL: CI 未呼叫 scripts/ci/check-doc-drift.sh" >&2
    return 1
  }
  # 擷取 step 區塊：從 `- name:` 起算（含 `continue-on-error` 惯例寫在 name 與 run 之間的情況），
  # 去註解、去空白、轉小寫後比對假綠樣式（同 repo 既有 `ci_runs_full_table()` 慣例）
  local step
  step=$(awk '/^      - name:/{ if (found) exit; buf=$0"\n"; inStep=1; next }
               inStep { buf = buf $0 "\n"; if ($0 ~ /check-doc-drift\.sh/) found=1 }
               END { if (found) printf "%s", buf }' "$ci" | grep -v '^[[:space:]]*#' | tr -d '[:space:]' | tr 'A-Z' 'a-z')
  if printf '%s' "$step" | grep -qE 'continue-on-error:true|\|\|true|if:'; then
    echo "FAIL: CI 的漂移檢查 step 含 continue-on-error / || true / if:（假綠）" >&2
    printf '%s\n' "$step" >&2
    return 1
  fi
}

@test "DOC-DRIFT-034: the CI fake-green guard actually bites (reverse self-test)" {
  # 守護本身的有效性：把假的 continue-on-error 塞進一份假 ci.yml → 守護邏輯必須報紅
  local root="$BATS_TEST_TMPDIR/cifake"
  mkdir -p "$root/.github/workflows"
  cat > "$root/.github/workflows/ci.yml" <<'EOF'
      - name: Verify no document drift
        continue-on-error: true
        run: bash scripts/ci/check-doc-drift.sh
EOF
  local step
  step=$(awk '/^      - name:/{ if (found) exit; buf=$0"\n"; inStep=1; next }
               inStep { buf = buf $0 "\n"; if ($0 ~ /check-doc-drift\.sh/) found=1 }
               END { if (found) printf "%s", buf }' "$root/.github/workflows/ci.yml" | grep -v '^[[:space:]]*#' | tr -d '[:space:]' | tr 'A-Z' 'a-z')
  if printf '%s' "$step" | grep -qE 'continue-on-error:true'; then
    return 0
  fi
  echo "FAIL: 假的 continue-on-error 應被守護抓到（守護本身無效 = 假綠）" >&2
  printf '%s\n' "$step" >&2
  return 1
}

@test "DOC-DRIFT-023: deliverables inside the from-date window are checked" {
  local root="$BATS_TEST_TMPDIR/d4in"
  _make_fixture "$root"
  echo '- `docs/ac/GHOST.md` — 不存在的檔案' >> "$root/docs/deliverable/2026-10-26-demo.md"
  # 把 from-date 拉早 → 範圍內的交付必須被檢查到（反向證明 DOC-DRIFT-015 不是空轉）
  run bash "$DRIFT_SCRIPT" --root "$root" --from-date 2026-01-01
  [ "$status" -eq 1 ] || {
    echo "FAIL: from-date 範圍內的交付摘要應被檢查，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D4 .*GHOST\.md' || {
    echo "FAIL: 輸出應含 'DRIFT D4 ... GHOST.md'" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-024: D7 catches a reconcile table that misses an R-ID" {
  local root="$BATS_TEST_TMPDIR/d7missing"
  _make_fixture "$root"
  # 錨點有 R1 + R2，但對帳表只列 R1
  python3 - "$root/docs/req/DEMO-001-requirement.md" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
s = s.replace("- R1: 「demo」", "- R1: 「demo」\n- R2: 「第二句」")
p.write_text(s, encoding="utf-8")
PY
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D7 應抓到對帳表未覆蓋 R2，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D7 DEMO-001' || {
    echo "FAIL: 輸出應含 'DRIFT D7 DEMO-001'" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-025: D7 catches an illegal status value in a reconcile table" {
  local root="$BATS_TEST_TMPDIR/d7status"
  _make_fixture "$root"
  python3 - "$root/docs/reconcile/DEMO-001-reconcile.md" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
p.write_text(s.replace("✅ 已實作", "大概完成"), encoding="utf-8")
PY
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D7 應抓到不合法狀態值，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D7 DEMO-001' || {
    echo "FAIL: 輸出應含 'DRIFT D7 DEMO-001'" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-026: D7 catches a delivered US with no reconcile table" {
  local root="$BATS_TEST_TMPDIR/d7none"
  _make_fixture "$root"
  rm "$root/docs/reconcile/DEMO-001-reconcile.md"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D7 應抓到「已交付但無對帳表」，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D7 DEMO-001' || {
    echo "FAIL: 輸出應含 'DRIFT D7 DEMO-001'" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-027: D8 catches a deliverable with no reconcile section" {
  local root="$BATS_TEST_TMPDIR/d8nosection"
  _make_fixture "$root"
  python3 - "$root/docs/deliverable/2026-10-26-demo.md" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
cut = s.find("## 3.1 需求對帳")
p.write_text(s[:cut] if cut > 0 else s, encoding="utf-8")
PY
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D8 應抓到缺「需求對帳」段，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D8 ' || {
    echo "FAIL: 輸出應含 'DRIFT D8 '" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-028: D8 catches a deliverable claiming success while the reconcile has gaps" {
  local root="$BATS_TEST_TMPDIR/d8mismatch"
  _make_fixture "$root"
  python3 - "$root/docs/reconcile/DEMO-001-reconcile.md" "$root/docs/deliverable/2026-10-26-demo.md" <<'PY'
import pathlib
import sys

rec = pathlib.Path(sys.argv[1])
rec.write_text(rec.read_text(encoding="utf-8").replace("✅ 已實作", "⚠️ 部分實作"), encoding="utf-8")
dl = pathlib.Path(sys.argv[2])
dl.write_text(dl.read_text(encoding="utf-8").replace("✅ 已實作", "⚠️ 部分實作"), encoding="utf-8")
PY
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D8 應抓到「對帳有缺口卻標 ✅ 完成」，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D8 ' || {
    echo "FAIL: 輸出應含 'DRIFT D8 '" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-029: D8 catches the legacy status field name too" {
  local root="$BATS_TEST_TMPDIR/d8legacy"
  _make_fixture "$root"
  # 舊版 handbook 模板用 **狀態**；檢查器必須兩種都認（否則門檻只在其中一種寫法生效）
  # 孤立性：權威表與內嵌表都改成 ⚠️ → 唯一紅因是「gaps + 宣告 ✅」，不會被「不一致」分支頂替
  python3 - "$root/docs/deliverable/2026-10-26-demo.md" "$root/docs/reconcile/DEMO-001-reconcile.md" <<'PY'
import pathlib
import sys

dl = pathlib.Path(sys.argv[1])
s = dl.read_text(encoding="utf-8")
s = s.replace("> **交付狀態**: ✅ 完成", "**狀態**：✅ 完成")
s = s.replace("✅ 已實作", "⚠️ 部分實作")
dl.write_text(s, encoding="utf-8")
rec = pathlib.Path(sys.argv[2])
rec.write_text(rec.read_text(encoding="utf-8").replace("✅ 已實作", "⚠️ 部分實作"), encoding="utf-8")
PY
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D8 應在 **狀態** 舊寫法下也抓到 gaps，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D8 ' || {
    echo "FAIL: 輸出應含 'DRIFT D8 '" >&2
    echo "$output" >&2
    return 1
  }
  # 孤立性：這條只能由「gaps + 宣告 ✅」觸發，不得被「內嵌 vs 權威表不一致」分支觸發
  if echo "$output" | grep -q '不一致'; then
    echo "FAIL: DOC-DRIFT-029 的紅因應只有 gaps 分支，不應是「內嵌 vs 權威表不一致」分支（探針未孤立化）" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "DOC-DRIFT-030: D8 catches an embedded table contradicting the authoritative reconcile table" {
  local root="$BATS_TEST_TMPDIR/d8conflict"
  _make_fixture "$root"
  # 權威對帳表是 ⚠️，但交付摘要內嵌表寫 ✅ → 必須報矛盾
  python3 - "$root/docs/reconcile/DEMO-001-reconcile.md" "$root/docs/deliverable/2026-10-26-demo.md" <<'PY'
import pathlib
import sys

# 權威表改 ⚠️、交付狀態改「⚠️ 部分完成」→ 唯一紅因是「內嵌 vs 權威表矛盾」
rec = pathlib.Path(sys.argv[1])
rec.write_text(rec.read_text(encoding="utf-8").replace("✅ 已實作", "⚠️ 部分實作"), encoding="utf-8")
dl = pathlib.Path(sys.argv[2])
dl.write_text(dl.read_text(encoding="utf-8").replace("> **交付狀態**: ✅ 完成", "> **交付狀態**: ⚠️ 部分完成"), encoding="utf-8")
PY
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D8 應抓到內嵌表與權威表矛盾，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -q '不一致' || {
    echo "FAIL: 輸出應指明是「內嵌 vs 權威表不一致」" >&2
    echo "$output" >&2
    return 1
  }
  # 唯一性：只能有一條 DRIFT D8（避免日後 gaps 分支變成第二紅因 → 探針失去孤立性）
  local n
  n=$(echo "$output" | grep -cE '^DRIFT D8 ')
  [ "$n" -eq 1 ] || {
    echo "FAIL: DOC-DRIFT-030 應只產生 1 條 DRIFT D8，實際 $n 條（探針未孤立化）" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-032: D4 expands path shorthands instead of false-alarming" {
  local root="$BATS_TEST_TMPDIR/d4shorthand"
  _make_fixture "$root"
  # 交付摘要裡的副檔名簡寫（`X.md/.html` → 指 X.md 與 X.html）→ 不得誤紅
  cat >> "$root/docs/deliverable/2026-10-26-demo.md" <<'EOF'

- `docs/ac/DEMO-001.md/.html` — 副檔名簡寫（指 DEMO-001.md 與 DEMO-001.html）
- `docs/req/DEMO-001-requirement.md` — 單檔
EOF
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 路徑簡寫不應誤紅，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-035: D4 expands numeric range shorthands (X-001~003.md)" {
  local root="$BATS_TEST_TMPDIR/d4range"
  _make_fixture "$root"
  # 數字區間簡寫：`docs/req/DEMO-001~002-requirement.md` → 展開為 DEMO-001 / DEMO-002
  mkdir -p "$root/docs/req"
  cp "$root/docs/req/DEMO-001-requirement.md" "$root/docs/req/DEMO-002-requirement.md"
  cat >> "$root/docs/deliverable/2026-10-26-demo.md" <<'EOF'

- `docs/req/DEMO-001~002-requirement.md` — 數字區間簡寫
EOF
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 數字區間簡寫不應誤紅，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -q 'DEMO-001~002' && {
    echo "FAIL: 區間簡寫不應被報成不存在（展開失效）" >&2
    echo "$output" >&2
    return 1
  }
  return 0
}

@test "DOC-DRIFT-033: D4 still alarms on a genuinely missing file" {
  local root="$BATS_TEST_TMPDIR/d4missing2"
  _make_fixture "$root"
  echo '- `docs/ac/NOPE.md` — 真的不存在' >> "$root/docs/deliverable/2026-10-26-demo.md"
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 真的缺檔仍應報紅，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D4 .*NOPE\.md' || {
    echo "FAIL: 輸出應含 'DRIFT D4 ... NOPE.md'" >&2
    echo "$output" >&2
    return 1
  }
}
@test "DOC-DRIFT-031: D8 catches a degraded reconcile that still claims success" {
  local root="$BATS_TEST_TMPDIR/d8degraded"
  _make_fixture "$root"
  python3 - "$root/docs/deliverable/2026-10-26-demo.md" <<'PY'
import pathlib
import sys

p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
s = s.replace("> **交付狀態**: ✅ 完成", "> **交付狀態**: ✅ 完成\n>\n> ⚠️ 對帳降級（無獨立 subagent）")
p.write_text(s, encoding="utf-8")
PY
  run bash "$DRIFT_SCRIPT" --root "$root"
  [ "$status" -eq 1 ] || {
    echo "FAIL: D8 應抓到「對帳降級卻標 ✅ 完成」，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -qE '^DRIFT D8 ' || {
    echo "FAIL: 輸出應含 'DRIFT D8 '" >&2
    echo "$output" >&2
    return 1
  }
}
