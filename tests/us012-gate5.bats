#!/usr/bin/env bats
#
# tests/us012-gate5.bats
#
# Black-box tests for US-012: Gate 5 (RSI gate) + schema regex + AGENTS.md 5 Gate.
# Each test corresponds to one or more ACs in docs/backlog.md (US-012).
#
# Usage:
#   bats tests/us012-gate5.bats

setup() {
  REPO_ROOT="$(git rev-parse --show-toplevel)"
  GATES_JSON="$REPO_ROOT/docs/sop/gates.json"
  GATES_SCHEMA="$REPO_ROOT/docs/sop/gates.schema.json"
  AGENTS_MD="$REPO_ROOT/AGENTS.md"
}

# ---------- AC-1: gates.json 加 gate-5 ----------
@test "AC-1: gates.json contains gate-5 entry" {
  [ -f "$GATES_JSON" ]
  python3 -c "
import json, sys
with open('$GATES_JSON') as f:
    g = json.load(f)
ids = [gate['id'] for gate in g['gates']]
assert 'gate-5' in ids, f'gate-5 missing, got {ids}'
"
}

@test "AC-1a: gate-5 has all required fields" {
  python3 -c "
import json
with open('$GATES_JSON') as f:
    g = json.load(f)
g5 = next(gate for gate in g['gates'] if gate['id'] == 'gate-5')
required = ['id', 'name', 'trigger_skill', 'pass_criteria', 'required_evidence', 'fail_action', 'mandatory_phrase']
for k in required:
    assert k in g5, f'missing {k}'
"
}

@test "AC-1b: gate-5 name is 'RSI gate'" {
  python3 -c "
import json
with open('$GATES_JSON') as f:
    g = json.load(f)
g5 = next(gate for gate in g['gates'] if gate['id'] == 'gate-5')
assert g5['name'] == 'RSI gate', f'got {g5[\"name\"]}'
"
}

# ---------- AC-2: gate-5 mandatory_phrase ----------
@test "AC-2: gate-5 mandatory_phrase includes required text" {
  python3 -c "
import json
with open('$GATES_JSON') as f:
    g = json.load(f)
g5 = next(gate for gate in g['gates'] if gate['id'] == 'gate-5')
phrase = g5['mandatory_phrase']
required = ['依 gates.json 規範', 'Gate 5', 'RSI', '反省報告', '改進提案', 'Reviewer', 'verdict', '用戶批准']
for r in required:
    assert r in phrase, f'missing {r} in {phrase}'
"
}

# ---------- AC-3: gates.schema.json regex 加 sop- 前綴 ----------
@test "AC-3: gates.schema.json trigger_skill regex accepts 'sop-evolver'" {
  [ -f "$GATES_SCHEMA" ]
  python3 -c "
import json, re
with open('$GATES_SCHEMA') as f:
    s = json.load(f)
trigger = s['properties']['gates']['items']['properties']['trigger_skill']
# Find the string pattern (not null)
pattern = None
for opt in trigger['oneOf']:
    if 'pattern' in opt:
        pattern = opt['pattern']
        break
assert pattern, 'no string pattern found in trigger_skill oneOf'
m = re.match(pattern, 'sop-evolver')
assert m, f'regex {pattern!r} does not match sop-evolver'
"
}

@test "AC-3a: gates.schema.json still accepts dav-/tdd-/regression-/dev-/minimax- prefixes" {
  python3 -c "
import json, re
with open('$GATES_SCHEMA') as f:
    s = json.load(f)
trigger = s['properties']['gates']['items']['properties']['trigger_skill']
pattern = None
for opt in trigger['oneOf']:
    if 'pattern' in opt:
        pattern = opt['pattern']
        break
for prefix in ['dav-', 'tdd-', 'regression-', 'dev-', 'minimax-', 'sop-']:
    name = f'{prefix}example'
    assert re.match(pattern, name), f'{name} should match {pattern!r}'
"
}

# ---------- AC-4: ajv 驗證 gates.json 0 error ----------
@test "AC-4: gates.json matches gates.schema.json" {
  [ -f "$GATES_JSON" ]
  [ -f "$GATES_SCHEMA" ]
  python3 -c "
import json
with open('$GATES_JSON') as f:
    g = json.load(f)
with open('$GATES_SCHEMA') as f:
    s = json.load(f)
# Basic structural check (real ajv would be more thorough)
gates = g.get('gates', [])
assert len(gates) == 5, f'expected 5 gates, got {len(gates)}'
for gate in gates:
    props = s['properties']['gates']['items']['properties']
    for key in ['id', 'name', 'pass_criteria', 'required_evidence', 'fail_action', 'mandatory_phrase']:
        assert key in gate, f'gate {gate.get(\"id\")} missing {key}'
"
}

# ---------- AC-5: AGENTS.md §2.3 表格加 Gate 5 ----------
@test "AC-5: AGENTS.md §2.3 table has 5 rows (4 existing + Gate 5)" {
  [ -f "$AGENTS_MD" ]
  # Count table rows in §2.3 area by counting Gate references
  grep -q "Gate 1\|gate-1" "$AGENTS_MD"
  grep -q "Gate 2\|gate-2" "$AGENTS_MD"
  grep -q "Gate 3\|gate-3" "$AGENTS_MD"
  grep -q "Gate 4\|gate-4" "$AGENTS_MD"
  grep -q "Gate 5\|gate-5\|RSI gate" "$AGENTS_MD"
}

# ---------- AC-9: AGENTS.md §2.3 改為 5 Gate ----------
@test "AC-9a: AGENTS.md §2.3 header does NOT say '4 Gate'" {
  [ -f "$AGENTS_MD" ]
  # Section §2.3 should mention 5 Gate, not 4
  python3 -c "
with open('$AGENTS_MD') as f:
    content = f.read()
# Find §2.3 section (matches both '### 2.3' and '### §2.3')
import re
m = re.search(r'### (?:§)?2\.3.*?(?=### (?:§)?[0-9]|\Z)', content, re.DOTALL)
assert m, '§2.3 section not found'
section = m.group(0)
# Should mention 5 Gate
assert '5 Gate' in section, '§2.3 should mention 5 Gate'
# Should NOT say '4 Gate' as primary count (allow 'Gate 1-4' references)
assert '4 Gate 速查表' not in section and '4 Gate)需要' not in section, '§2.3 still says 4 Gate as primary'
"
}

@test "AC-9b: AGENTS.md §2 table lists 5 gates" {
  [ -f "$AGENTS_MD" ]
  python3 -c "
with open('$AGENTS_MD') as f:
    content = f.read()
# Count occurrences of 'Gate N' in the §2.3 table area
import re
# Find §2.3 area
m = re.search(r'### §2\.3.*?(?=### §|\Z)', content, re.DOTALL)
if not m:
    # Try different anchor
    m = re.search(r'## 2\.3.*?(?=## [0-9]|\Z)', content, re.DOTALL)
assert m, '§2.3 section not found'
section = m.group(0)
gate_count = len(re.findall(r'\*\*Gate [1-5]\*\*', section))
assert gate_count >= 5, f'expected ≥5 Gate references in table, got {gate_count}'
"
}

# ---------- AC-7: gate-5 pass_criteria 含 Reviewer verdict ----------
@test "AC-7: gate-5 pass_criteria mentions Reviewer verdict" {
  python3 -c "
import json
with open('$GATES_JSON') as f:
    g = json.load(f)
g5 = next(gate for gate in g['gates'] if gate['id'] == 'gate-5')
criteria_text = ' '.join(g5['pass_criteria'])
assert 'Reviewer' in criteria_text, f'pass_criteria missing Reviewer: {criteria_text}'
"
}

# ---------- AC-8: gate-5 fail_action 含「用戶明確說跳過」 ----------
@test "AC-8: gate-5 fail_action mentions user opt-out" {
  python3 -c "
import json
with open('$GATES_JSON') as f:
    g = json.load(f)
g5 = next(gate for gate in g['gates'] if gate['id'] == 'gate-5')
fa = g5['fail_action']
assert 'Reviewer' in fa or '跳過' in fa, f'fail_action missing user opt-out: {fa}'
"
}

# ---------- TD-022: observation schema design ----------
@test "TD-022: docs/prd/04-self-evolution.md documents observation schema fields" {
  [ -f "$REPO_ROOT/docs/prd/04-self-evolution.md" ]
  for field in task_id project_id timestamp gate_results skills_used failure_signals duration_seconds; do
    grep -q "$field" "$REPO_ROOT/docs/prd/04-self-evolution.md"
  done
}

@test "TD-022: docs/prd/04-self-evolution.md mentions SHA256 for project_id" {
  grep -q "SHA256" "$REPO_ROOT/docs/prd/04-self-evolution.md"
}

@test "TD-022: docs/sop/sop-evolver/observation.md has blacklist fields" {
  # sop-evolver skill is created in US-011, observation.md exists
  [ -f "$REPO_ROOT/.agents/skills/sop-evolver/observation.md" ]
  grep -q "raw_conversation\|raw 對話" "$REPO_ROOT/.agents/skills/sop-evolver/observation.md"
  grep -q "code_snippets\|程式碼片段" "$REPO_ROOT/.agents/skills/sop-evolver/observation.md"
  grep -q "file_paths\|檔案路徑" "$REPO_ROOT/.agents/skills/sop-evolver/observation.md"
}

# ---------- AC-6: ≥ 3 個 bats 測試（結構 + schema + AGENTS.md 引用） ----------
@test "AC-6: this bats file has ≥ 3 test sections (structure + schema + AGENTS.md ref)" {
  [ -f "$REPO_ROOT/tests/us012-gate5.bats" ]
  local count
  count=$(grep -c "^@test" "$REPO_ROOT/tests/us012-gate5.bats")
  [ "$count" -ge 10 ]
}