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

# ---------------------------------------------------------------------------
# 反假綠守護：D4/D8 的「檢查件數不得為 0」
#
# 2026-10-26 減法：docs/deliverable/ 的歷史交付摘要被清空到只剩少數幾支。
# 若「窗內（from-date 之後）一支都沒有」，D4（交付摘要提到的檔案真的存在）與
# D8（交付摘要的對帳段 vs 權威對帳表）的**檢查件數就是 0** → 腳本照跑、rc=0，
# 但「未對上不得宣告 ✅ 完成」那條硬門檻**已經不會被觸發**——典型的假綠。
#
# 因此新增 `--require-window-checks` 嚴格模式：窗內 0 件 → rc=1。
# 可攜預設（不帶 flag）維持「只印警告」語意，避免打斷一般專案的使用。
# ---------------------------------------------------------------------------

@test "DOC-DRIFT-039: strict mode fails closed when the from-date window has no deliverable" {
  local root="$BATS_TEST_TMPDIR/d4nowindow"
  _make_fixture "$root"
  mv "$root/docs/deliverable/2026-10-26-demo.md" "$root/docs/deliverable/2026-01-01-old.md"
  run bash "$DRIFT_SCRIPT" --root "$root" --require-window-checks
  [ "$status" -eq 1 ] || {
    echo "FAIL: 窗內 0 件時嚴格模式必須 rc=1（不可靜默放行），實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -q "no-in-window-deliverable" || {
    echo "FAIL: 應明確報出 no-in-window-deliverable（讓人看得出是哪個機制沒在跑）" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-040: strict mode stays green when the window has a deliverable" {
  local root="$BATS_TEST_TMPDIR/d4windowok"
  _make_fixture "$root"
  run bash "$DRIFT_SCRIPT" --root "$root" --require-window-checks
  [ "$status" -eq 0 ] || {
    echo "FAIL: 窗內有交付摘要時嚴格模式應 rc=0，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  if echo "$output" | grep -q "no-in-window-deliverable"; then
    echo "FAIL: 不該出現 no-in-window-deliverable" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "DOC-DRIFT-041: the real repo keeps at least one in-window deliverable (D4/D8 must have work to do)" {
  # 真實 repo 的守護：窗內（from-date 之後）至少要有一支交付摘要，
  # 否則 CI 的 D4/D8 等於「掃不到就 skip」——綠，但什麼都沒驗。
  run bash "$DRIFT_SCRIPT" --root "$REPO_ROOT" --require-window-checks
  [ "$status" -eq 0 ] || {
    echo "FAIL: 真實 repo 應 rc=0，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  if echo "$output" | grep -q "no-in-window-deliverable"; then
    echo "FAIL: 真實 repo 的 D4/D8 檢查件數為 0（硬門檻靜默失效）" >&2
    echo "$output" >&2
    return 1
  fi
  # 負向斷言不足以守護：目錄整包消失時 check_deliverable_window() 直接 return
  # （連 WARNING 都不印）→ 上面兩條都成立、仍為綠。故必須正向斷言「機制真的有東西可查」。
  [ -d "$REPO_ROOT/docs/deliverable" ] || {
    echo "FAIL: docs/deliverable/ 目錄不見了 → D4/D8 變 0 件卻不報（假綠）" >&2
    return 1
  }
  compgen -G "$REPO_ROOT/docs/deliverable/20*.md" >/dev/null || {
    echo "FAIL: docs/deliverable/ 內沒有任何 20*.md 交付摘要 → D4/D8 0 件（假綠）" >&2
    return 1
  }
}

@test "DOC-DRIFT-042: strict mode fails closed when docs/deliverable/ exists but holds no deliverable" {
  # 目錄存在 = 這個專案宣告要用交付摘要機制；裡面卻一支都沒有（含被刪光的情境）
  # → D4/D8 的檢查件數為 0，硬門檻靜默失效 → 嚴格模式必須 rc=1。
  local root="$BATS_TEST_TMPDIR/d4emptydir"
  _make_fixture "$root"
  rm -f "$root"/docs/deliverable/*.md
  run bash "$DRIFT_SCRIPT" --root "$root" --require-window-checks
  [ "$status" -eq 1 ] || {
    echo "FAIL: 交付摘要目錄存在但無任何交付摘要時，嚴格模式必須 rc=1（不可靜默放行），實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -q "no-in-window-deliverable" || {
    echo "FAIL: 應明確報出 no-in-window-deliverable" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-043: a project without docs/deliverable/ is not flagged (mechanism not in use)" {
  # 反向：專案根本沒用這套機制 → 不適用、不報（避免對外可攜模式誤擋一般專案）
  local root="$BATS_TEST_TMPDIR/d4nodelivdir"
  _make_fixture "$root"
  rm -rf "$root/docs/deliverable"
  run bash "$DRIFT_SCRIPT" --root "$root" --require-window-checks
  [ "$status" -eq 0 ] || {
    echo "FAIL: 沒有 docs/deliverable/ 的專案不該被判定違規，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  if echo "$output" | grep -q "no-in-window-deliverable"; then
    echo "FAIL: 不該出現 no-in-window-deliverable" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "DOC-DRIFT-044: wrapper auto-enables strict mode when no --root is given" {
  # 這個分支是本次最核心的新機制：沒有它，CI 回到「窗內 0 件 → 掃不到就 skip → rc=0」的假綠。
  # 其他探針都自帶 --root（或自帶 --require-window-checks），刪掉 wrapper 這個分支它們**不會轉紅**
  # → 所以必須有一支探針直接打「不帶 --root」這條路徑。
  cd "$REPO_ROOT"
  run bash "$DRIFT_SCRIPT" --from-date 2999-01-01
  [ "$status" -eq 1 ] || {
    echo "FAIL: wrapper 未自動開嚴格模式（本 repo 窗內 0 件卻 rc=$status → 假綠回歸）" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -q "no-in-window-deliverable" || {
    echo "FAIL: 應報出 no-in-window-deliverable" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-045: wrapper stays portable when --root is given (external project is not blocked)" {
  # 反向：對外使用（--root <別的專案>）不得誤開嚴格模式 → 否則會擋住不相干的專案。
  run bash "$DRIFT_SCRIPT" --root "$REPO_ROOT" --from-date 2999-01-01
  [ "$status" -eq 0 ] || {
    echo "FAIL: 有 --root 時不該強制嚴格模式（對外可攜語意），實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  if echo "$output" | grep -q "no-in-window-deliverable"; then
    echo "FAIL: 可攜模式不該報 no-in-window-deliverable（應只印 WARNING）" >&2
    echo "$output" >&2
    return 1
  fi
  echo "$output" | grep -q "WARNING D4/D8" || {
    echo "FAIL: 可攜模式應印 WARNING D4/D8 提醒（不能靜默）" >&2
    echo "$output" >&2
    return 1
  }
}

@test "DOC-DRIFT-046: wrapper also treats --root=<path> as an external project" {
  # `--root=<p>` 與 `--root <p>` 是兩種寫法；漏掉等號形會把外部專案誤判成「本 repo」而擋掉。
  run bash "$DRIFT_SCRIPT" "--root=$REPO_ROOT" --from-date 2999-01-01
  [ "$status" -eq 0 ] || {
    echo "FAIL: --root=<p> 形式不該誤開嚴格模式，實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  if echo "$output" | grep -q "no-in-window-deliverable"; then
    echo "FAIL: --root=<p> 形式不該報 no-in-window-deliverable" >&2
    echo "$output" >&2
    return 1
  fi
}

@test "DOC-DRIFT-047: CI's drift step must not pass --root (else the fail-closed branch never runs)" {
  # 為什麼要這條：wrapper 只在「完全沒有 --root／--root=」時才自動加上 --require-window-checks。
  # 也就是說，把 CI 那行改成 `--root .` 就會讓嚴格模式**悄悄關掉**，
  # 而 DOC-DRIFT-022（step 存在、無假綠樣式）／041（帶 --require-window-checks 的探針）／
  # 044／045／046（wrapper 分支存在）**全部仍然綠** → 沒有一支證明 CI 真的走到那個分支。
  # 這正是「新機制的開關本身也需要守護」的另一半（第三輪 P1 的同型洞）。
  local ci="$REPO_ROOT/.github/workflows/ci.yml"
  [ -f "$ci" ] || { echo "FAIL: 找不到 $ci" >&2; return 1; }
  local runs
  runs=$(grep -nE '^[[:space:]]*run:.*check-doc-drift\.sh' "$ci" || true)
  [ -n "$runs" ] || { echo "FAIL: CI 找不到呼叫 check-doc-drift.sh 的 run: 行" >&2; return 1; }
  # 兩種合法寫法：① 不帶 --root → wrapper 自動加嚴格模式（DOC-DRIFT-044 守住那個分支）
  #              ② 帶 --root 但**明寫** --require-window-checks
  # 不合法：帶 --root 又沒明寫 → wrapper 判定「外部專案」→ 嚴格模式靜默關閉。
  # 逐行判定（不是把多行串成一份再 grep 一次）：CI 有多行時，
  # 「A 行帶 --root 沒明寫」不會被「B 行明寫了」掩蓋過去。
  # token 邊界用 (^|[[:space:]]) 錨定，避免把 --whitelist /tmp/--root=x.txt 這種「值裡含 --root」誤判。
  local line bad=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$line" | grep -qE -- '(^|[[:space:]])--root(=|[[:space:]]|$)' || continue
    printf '%s' "$line" | grep -q -- '--require-window-checks' && continue
    bad="$bad
$line"
  done <<< "$runs"
  [ -z "$bad" ] || {
    echo "FAIL: CI 的漂移檢查帶了 --root 卻沒明寫 --require-window-checks → wrapper 不會自動開嚴格模式，D4/D8 守護靜默失效：" >&2
    printf '%s\n' "$bad" >&2
    return 1
  }
}

@test "DOC-DRIFT-048: in-window deliverable without any docs/req anchor still fails closed" {
  # 「窗內有件」只保證 D4 有件可查，**不保證 D8**。
  # 若窗內交付摘要沒有一支引用得到 docs/req/ 錨點，D8 的檢查件數仍是 0
  # → 「對帳有 gap 不得宣告 ✅ 完成」這條硬門檻等於失效，但整個腳本照樣 rc=0。
  local root="$BATS_TEST_TMPDIR/no_anchor"
  _make_fixture "$root"
  # 把交付摘要裡的 DEMO-001 換成一個沒有 docs/req 錨點的 ID → D8 檢查件數歸零
  sed -i.bak 's/DEMO-001/DEMO-999/g' "$root/docs/deliverable/2026-10-26-demo.md"
  rm -f "$root/docs/deliverable/2026-10-26-demo.md.bak"
  run bash "$DRIFT_SCRIPT" --root "$root" --from-date 2026-10-26 --require-window-checks
  [ "$status" -eq 1 ] || {
    echo "FAIL: 窗內有件但無任何 docs/req 錨點時，D8 應 fail-closed（rc=1），實際 rc=$status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -q 'DRIFT D8 no-reconcile-in-window' || {
    echo "FAIL: 應報 DRIFT D8 no-reconcile-in-window" >&2
    echo "$output" >&2
    return 1
  }
  # 反向：不帶 --require-window-checks 時只印 WARNING（可攜語意），不得靜默
  run bash "$DRIFT_SCRIPT" --root "$root" --from-date 2026-10-26
  echo "$output" | grep -q 'WARNING D8' || {
    echo "FAIL: 可攜模式應印 WARNING D8（不能靜默）" >&2
    echo "$output" >&2
    return 1
  }
  # 反向二：正常 fixture（交付摘要引用得到錨點）不得誤報 → 這條守住「偵測器不是一律紅」
  local ok_root="$BATS_TEST_TMPDIR/with_anchor"
  _make_fixture "$ok_root"
  run bash "$DRIFT_SCRIPT" --root "$ok_root" --from-date 2026-10-26 --require-window-checks
  [ "$status" -eq 0 ] || {
    echo "FAIL: 正常 fixture（有錨點）竟紅 → 偵測器誤報：$output" >&2
    return 1
  }
}
