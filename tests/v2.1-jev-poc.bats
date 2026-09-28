#!/usr/bin/env bats
#
# tests/v2.1-jev-poc.bats
#
# Regression guards for "regression-guard Jev PoC v2.1" (TMO-012, M5).
# 4 探針 + 1 runtime：
#   1. M5.1 fixture YAML loader (config-driven)
#   2. M5.2 stale detection 限「同一 AC」 (換 AC 不誤判)
#   3. M5.3 CLI 重構 (run_dry() 統一入口)
#   4. M5.4 batch report 4 維度輸出
#   5. M5 runtime: fixture load + stale-test block (真實跑)
#
# 不靠 API: cache + dry-run 即可驗證所有分支。
# 註: @test 名稱純英文 (homebrew bats UTF-8 bug, 見 wiki-merge-media.bats)
# Gate 1 (TDD): RED → implement → GREEN.

setup() {
  load 'helpers/test-env'
  POC_DIR="$REPO_ROOT/skills/regression-guard/PoC"
  PY="$POC_DIR/.venv/bin/python"
}

# ────────────────────────────────────────────────────────────────────
# Probe 1: M5.1 fixture YAML loader
# ────────────────────────────────────────────────────────────────────

@test "M5.1-a: fixtures/US-101.yaml exists and has 4 AC entries" {
  local f="$POC_DIR/fixtures/US-101.yaml"
  assert_path_is_file "$f"
  for ac in US-101-AC01 US-101-AC02 US-101-AC03 US-101-AC04; do
    if ! grep -q "^${ac}:" "$f"; then
      echo "FAIL: $f missing fixture for $ac" >&2
      return 1
    fi
  done
}

@test "M5.1-b: journey_runner has _load_fixture helper (no hardcoded dict)" {
  local f="$POC_DIR/journey_runner.py"
  assert_file_contains "$f" "_load_fixture"
  if grep -q "^AC_AWARE_FIXTURES[[:space:]]*=[[:space:]]*{" "$f"; then
    echo "FAIL: $f still has hardcoded AC_AWARE_FIXTURES (should be YAML)" >&2
    return 1
  fi
}

@test "M5.1-c: ac_aware_observe signature takes story_id kwarg" {
  local f="$POC_DIR/journey_runner.py"
  grep -qE "def ac_aware_observe\(step.*story_id[[:space:]]*:[[:space:]]*str" "$f" || {
    echo "FAIL: ac_aware_observe should accept story_id kwarg" >&2
    return 1
  }
}

@test "M5.1-d: run_journey forwards story_id to ac_aware_observe" {
  local f="$POC_DIR/journey_runner.py"
  grep -qE "ac_aware_observe\(step.*story_id" "$f" || {
    echo "FAIL: run_journey should pass story_id to ac_aware_observe" >&2
    return 1
  }
}

# ────────────────────────────────────────────────────────────────────
# Probe 2: M5.2 stale detection 限「同一 AC」
# ────────────────────────────────────────────────────────────────────

@test "M5.2-a: run_journey uses current_ac_id state machine" {
  local f="$POC_DIR/journey_runner.py"
  assert_file_contains "$f" "current_ac_id"
  assert_file_contains "$f" "same_ac"
}

@test "M5.2-b: mock_observe_static exists for stale-test" {
  local f="$POC_DIR/journey_runner.py"
  assert_file_contains "$f" "def mock_observe_static"
}

@test "M5.2-c: stale-test CLI still runs (backward compat, exit code 0 or 2 both ok)" {
  set +e
  (cd "$POC_DIR" && "$PY" run_journey.py journeys/US-101.yaml --stale-test >/dev/null 2>&1)
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
    echo "FAIL: stale-test CLI exit code $rc"
    return 1
  fi
}

# ────────────────────────────────────────────────────────────────────
# Probe 3: M5.3 CLI 重構 — run_dry() 統一入口
# ────────────────────────────────────────────────────────────────────

@test "M5.3-a: journey_runner has run_dry() entry point" {
  local f="$POC_DIR/journey_runner.py"
  assert_file_contains "$f" "def run_dry("
}

@test "M5.3-b: run_journey uses run_dry() (not inline stale-test logic)" {
  local f="$POC_DIR/run_journey.py"
  grep -qE "from journey_runner import run_dry" "$f" || {
    echo "FAIL: run_journey should import run_dry" >&2
    return 1
  }
  # inline stale-test 邏輯應已移除 (consecutive_stale 應只在 journey_runner.py 內)
  local in_run_journey
  in_run_journey=$(grep -c "consecutive_stale" "$f" || true)
  if [ "$in_run_journey" -gt 0 ]; then
    echo "FAIL: run_journey.py still has consecutive_stale (should be in journey_runner.py only)" >&2
    return 1
  fi
}

@test "M5.3-c: run_dry signature accepts stale_test kwarg" {
  local f="$POC_DIR/journey_runner.py"
  grep -qE "def run_dry\(.*stale_test" "$f" || {
    echo "FAIL: run_dry should accept stale_test kwarg" >&2
    return 1
  }
}

@test "M5.3-d: run_dry dispatches on stale_test flag" {
  local f="$POC_DIR/journey_runner.py"
  grep -qE "if stale_test:" "$f" || {
    echo "FAIL: run_dry should dispatch on stale_test" >&2
    return 1
  }
  assert_file_contains "$f" "_run_dry_stale_test"
}

# ────────────────────────────────────────────────────────────────────
# Probe 4: M5.4 batch report 4 維度
# ────────────────────────────────────────────────────────────────────

@test "M5.4-a: batch_report has 4 BATCH_QUESTIONS keys" {
  local f="$POC_DIR/batch_report.py"
  for q in overall_health fix_priority flaky_likelihood regression_type; do
    assert_file_contains "$f" "$q" || {
      echo "FAIL: $f should define question: $q" >&2
      return 1
    }
  done
}

@test "M5.4-b: BatchReport dataclass has 4 fields + JSON+MD writers" {
  local f="$POC_DIR/batch_report.py"
  assert_file_contains "$f" "@dataclass"
  assert_file_contains "$f" "class BatchReport"
  for field in overall_health fix_priority flaky_likelihood regression_type; do
    grep -qE "[[:space:]]${field}[[:space:]]*[:=]" "$f" || {
      echo "FAIL: BatchReport should have field: $field" >&2
      return 1
    }
  done
  assert_file_contains "$f" "write_json_report"
  assert_file_contains "$f" "write_markdown_report"
}

@test "M5.4-c: run_report.py CLI wrapper exists" {
  local f="$POC_DIR/run_report.py"
  assert_path_is_file "$f"
  # M4 run_report 是 batch_report.main 的 thin shell (REGRESSION_REPORT_PATH 由 batch_report.main 讀)
  grep -qE "from batch_report import|REGRESSION_REPORT_PATH" "$f" || {
    echo "FAIL: run_report should import batch_report.main" >&2
    return 1
  }
  # 同時驗證 batch_report.py 讀 env
  assert_file_contains "$POC_DIR/batch_report.py" "REGRESSION_REPORT_PATH"
}

# ────────────────────────────────────────────────────────────────────
# Probe 5 (bonus): runtime 驗證
# ────────────────────────────────────────────────────────────────────

@test "M5-runtime-a: _load_fixture returns 4 AC entries" {
  cd "$POC_DIR"
  "$PY" -c "
import sys
sys.path.insert(0, '.')
from journey_runner import _load_fixture
fix = _load_fixture('US-101')
assert len(fix) == 4, f'expected 4, got {len(fix)}'
assert 'US-101-AC01' in fix
assert fix['US-101-AC04']['status'] == 500, 'AC04 should be 500'
print('OK: 4 fixtures, AC04=500')
"
}

@test "M5-runtime-b: stale-test blocks journey (mock_observe_static works)" {
  local us_md="$REPO_ROOT/docs/ac/US-101.md"
  cd "$POC_DIR"
  "$PY" -c "
import sys
sys.path.insert(0, '.')
import yaml
from pathlib import Path
from journey_runner import run_dry
from ac_schema import parse_story_file
from journey_generator import Journey, Step, JOURNEYS_DIR

story = parse_story_file(Path('$us_md'))
raw = yaml.safe_load((JOURNEYS_DIR / 'US-101.yaml').read_text())
steps = [Step(**s) for s in raw['steps']]
journey = Journey(journey_id=raw['journey_id'], title=raw['title'],
                    source=raw['source'], steps=steps,
                    generated_by=raw.get('generated_by', 'test'),
                    generated_at=raw.get('generated_at', 'test'),
                    total_steps=len(steps))
records, summary = run_dry(journey, story.acs, stale_test=True)
assert summary['blocked'] is True, summary
assert 'stale' in summary.get('block_reason', '').lower()
print(f'OK blocked={summary[\"blocked\"]} reason={summary[\"block_reason\"]}')
"
}

# ────────────────────────────────────────────────────────────────────
# Probe 6: M3.1 Playwright observer + dispatcher (TMO-013)
# ────────────────────────────────────────────────────────────────────

@test "M3.1-a: playwright_observer.py exists & has 6 actions" {
  local f="$POC_DIR/playwright_observer.py"
  assert_path_is_file "$f"
  for action in navigate click type wait observe setup_state; do
    assert_file_contains "$f" "_do_${action}" || {
      echo "FAIL: playwright_observer should have _do_${action}" >&2
      return 1
    }
  done
}

@test "M3.1-b: journey_runner has _select_observer dispatcher (OBSERVER_BACKEND env)" {
  local f="$POC_DIR/journey_runner.py"
  assert_file_contains "$f" "_select_observer"
  assert_file_contains "$f" "OBSERVER_BACKEND"
}

@test "M3.1-c: playwright_observer module imports OK without playwright installed" {
  cd "$POC_DIR"
  "$PY" -c "
import sys
sys.path.insert(0, '.')
import playwright_observer as po
assert hasattr(po, 'playwright_observe')
assert hasattr(po, '_is_playwright_available')
assert hasattr(po, 'close_session')
assert po._is_playwright_available() is False, 'playwright not installed, should be False'
print('OK: module imports, _is_playwright_available=False')
" || {
    echo "FAIL: playwright_observer should import without playwright installed" >&2
    return 1
  }
}

@test "M3.1-d: backend=playwright raises RuntimeError when playwright missing" {
  cd "$POC_DIR"
  set +e
  OBSERVER_BACKEND=playwright "$PY" run_journey.py journeys/US-101.yaml >/dev/null 2>&1
  local rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    echo "FAIL: backend=playwright should fail (no playwright) but exit 0" >&2
    return 1
  fi
  # exit 1 (driver error) or 2 (block) 都算 graceful fail
  if [ "$rc" -ne 1 ] && [ "$rc" -ne 2 ]; then
    echo "FAIL: unexpected exit code $rc" >&2
    return 1
  fi
}

@test "M3.1-e: backend=mock signature compatible (story_id kwarg)" {
  cd "$POC_DIR"
  set +e
  OBSERVER_BACKEND=mock "$PY" run_journey.py journeys/US-101.yaml >/dev/null 2>&1
  local rc=$?
  set -e
  # exit 0 (沒 block) 或 2 (block) 都算 pass
  if [ "$rc" -ne 0 ] && [ "$rc" -ne 2 ]; then
    echo "FAIL: backend=mock exit code $rc (expected 0/2)" >&2
    return 1
  fi
}

# ────────────────────────────────────────────────────────────────────
# Probe 7: SKILL.md 整合 (TMO-014)
# ────────────────────────────────────────────────────────────────────

@test "SKILL-a: SKILL.md has Jev Oracle chapter" {
  local f="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$f" "## Jev Oracle 補充"
}

@test "SKILL-b: SKILL.md chapter mentions 3 backends (ac_aware/mock/playwright)" {
  local f="$REPO_ROOT/skills/regression-guard/SKILL.md"
  for backend in ac_aware mock playwright; do
    assert_file_contains "$f" "$backend" || {
      echo "FAIL: SKILL.md Jev chapter should mention $backend" >&2
      return 1
    }
  done
}

@test "SKILL-c: examples.md has Jev Oracle chapter with 4 example types" {
  local f="$REPO_ROOT/skills/regression-guard/examples.md"
  assert_file_contains "$f" "## 🧠 Jev Oracle 範例"
  for example in "journey YAML" "dry-run" "batch report" "JSON 報告"; do
    assert_file_contains "$f" "$example" || {
      echo "FAIL: examples.md should have example: $example" >&2
      return 1
    }
  done
}

@test "SKILL-d: SKILL.md v2.2 changelog entry exists" {
  local f="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$f" "v2.2"
  assert_file_contains "$f" "TMO-013"
}

# ────────────────────────────────────────────────────────────────────
# Probe 8: CI 整合 (TMO-015)
# ────────────────────────────────────────────────────────────────────

@test "CI-a: GitHub Actions workflow exists with 2 jobs" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  assert_path_is_file "$f"
  local content
  content=$(cat "$f")
  [[ "$content" == *"jobs:"* ]] || { echo "FAIL: no jobs:" >&2; return 1; }
  [[ "$content" == *"bats:"* ]] || { echo "FAIL: no bats: job" >&2; return 1; }
  [[ "$content" == *"pipeline:"* ]] || { echo "FAIL: no pipeline: job" >&2; return 1; }
  [[ "$content" == *"needs: bats"* ]] || { echo "FAIL: pipeline should need bats" >&2; return 1; }
}

@test "CI-b: workflow has 3 triggers (push/PR/dispatch)" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  for trigger in push pull_request workflow_dispatch; do
    assert_file_contains "$f" "$trigger" || {
      echo "FAIL: missing trigger: $trigger" >&2
      return 1
    }
  done
}

@test "CI-c: workflow uses OPENROUTER_API_KEY secret" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  assert_file_contains "$f" "secrets.OPENROUTER_API_KEY"
}

@test "CI-d: workflow handles return code 0/1/2 (red blocks merge)" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  for rc_text in "PIPELINE_RC" "exit 1" "exit 2" "blocks merge"; do
    assert_file_contains "$f" "$rc_text" || {
      echo "FAIL: missing $rc_text" >&2
      return 1
    }
  done
}

@test "CI-e: CI SOP exists at docs/ci/regression-guard-jev-poc.md" {
  local f="$REPO_ROOT/docs/ci/regression-guard-jev-poc.md"
  assert_path_is_file "$f"
  for content in "## " "branch protection" "gh secret set"; do
    assert_file_contains "$f" "$content" || {
      echo "FAIL: CI SOP missing $content" >&2
      return 1
    }
  done
}

# ────────────────────────────────────────────────────────────────────
# Probe 9: M6 fix proposal (TMO-016)
# ────────────────────────────────────────────────────────────────────

@test "M6-a: fix_proposal.py exists with 3 questions schema" {
  local f="$POC_DIR/fix_proposal.py"
  assert_path_is_file "$f"
  for q in problem_summary proposed_fix verification_steps; do
    assert_file_contains "$f" "$q" || {
      echo "FAIL: fix_proposal.py missing $q" >&2
      return 1
    }
  done
}

@test "M6-b: fix_proposal.py can import & has FixProposal dataclass" {
  cd "$POC_DIR"
  "$PY" -c "
import sys
sys.path.insert(0, '.')
import fix_proposal
assert hasattr(fix_proposal, 'FixProposal')
assert hasattr(fix_proposal, 'generate_fix_proposal')
assert hasattr(fix_proposal, 'PROPOSAL_QUESTIONS')
assert set(fix_proposal.PROPOSAL_QUESTIONS.keys()) == {'problem_summary', 'proposed_fix', 'verification_steps'}
# Check 3 conf fields
fields = {f.name for f in fix_proposal.FixProposal.__dataclass_fields__.values()}
assert 'problem_summary_conf' in fields
assert 'proposed_fix_conf' in fields
assert 'verification_steps_conf' in fields
print('OK: FixProposal has 3 conf fields')
" || {
    echo "FAIL: fix_proposal structure check" >&2
    return 1
  }
}

@test "M6-c: run_pipeline.sh supports JEV_FIX_PROPOSAL=1" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "JEV_FIX_PROPOSAL"
  assert_file_contains "$f" "fix_proposal.py"
}

@test "M6-d: run_pipeline.sh captures M4 return code (does not let set -e break M6)" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "M4_RC=0"
  assert_file_contains "$f" "|| M4_RC="
}

@test "M6-e: SKILL.md has M6 fix-loop section" {
  local f="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$f" "修正循環補充"
  assert_file_contains "$f" "JEV_FIX_PROPOSAL"
  assert_file_contains "$f" "TMO-016"
}

@test "M6-f: examples.md has fix proposal example" {
  local f="$REPO_ROOT/skills/regression-guard/examples.md"
  assert_file_contains "$f" "Fix proposal"
  assert_file_contains "$f" "JEV_FIX_PROPOSAL"
}

@test "M6-g: end-to-end fix_proposal.py on /tmp/US-101-run.json" {
  cd "$POC_DIR"
  # 用 JEV_FIX_PROPOSAL=1 跑 pipeline，產出 fix_proposal.md
  if [ ! -f /tmp/US-101-run.json ]; then
    skip "US-101-run.json not found, run pipeline first"
  fi
  "$PY" fix_proposal.py /tmp/US-101-run.json /tmp/test-fix.md >/dev/null 2>&1 || {
    echo "FAIL: fix_proposal.py CLI failed" >&2
    return 1
  }
  assert_path_is_file /tmp/test-fix.md
  # 確認內容是信心度報告格式
  grep -q "整體信心度" /tmp/test-fix.md || {
    echo "FAIL: fix_proposal.md missing 整體信心度" >&2
    return 1
  }
}

# ────────────────────────────────────────────────────────────────────
# Probe 10: M6.1 LLM Relay (TMO-017)
# ────────────────────────────────────────────────────────────────────

@test "M6.1-a: prompts/fix_relay.md exists with 4 sections" {
  local f="$POC_DIR/prompts/fix_relay.md"
  assert_path_is_file "$f"
  for section in "角色" "輸入" "產出" "約束"; do
    assert_file_contains "$f" "$section" || {
      echo "FAIL: prompts/fix_relay.md missing section: $section" >&2
      return 1
    }
  done
}

@test "M6.1-b: fix_proposal_v2.py exists with LLMRelayBundle + RELAY_GATING_THRESHOLD" {
  local f="$POC_DIR/fix_proposal_v2.py"
  assert_path_is_file "$f"
  assert_file_contains "$f" "LLMRelayBundle"
  assert_file_contains "$f" "RELAY_GATING_THRESHOLD"
  assert_file_contains "$f" "build_final_report"
}

@test "M6.1-c: fix_proposal_v2.py gating < 0.5 skips LLM relay (end-to-end)" {
  cd "$POC_DIR"
  if [ ! -f /tmp/US-101-run.json ]; then
    skip "US-101-run.json not found, run pipeline first"
  fi
  "$PY" fix_proposal_v2.py /tmp/US-101-run.json /tmp/test-v2.md >/dev/null 2>&1 || {
    echo "FAIL: fix_proposal_v2.py CLI failed" >&2
    return 1
  }
  assert_path_is_file /tmp/test-v2.md
  # 0.41 < 0.5 → 應該出現 "LLM Relay 跳過"
  grep -q "LLM Relay 跳過" /tmp/test-v2.md || {
    echo "FAIL: test-v2.md should have LLM Relay 跳過 (0.41 < 0.5)" >&2
    return 1
  }
}

@test "M6.1-d: run_pipeline.sh supports JEV_FIX_PROPOSAL_V2=1" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "JEV_FIX_PROPOSAL_V2"
  assert_file_contains "$f" "fix_proposal_v2.py"
}

@test "M6.1-e: SKILL.md v2.4 has LLM Relay section" {
  local f="$REPO_ROOT/skills/regression-guard/SKILL.md"
  assert_file_contains "$f" "M6.1 修正循環補充"
  assert_file_contains "$f" "LLM Relay"
  assert_file_contains "$f" "TMO-017"
}

@test "M6.1-f: examples.md has v2 LLM relay example" {
  local f="$REPO_ROOT/skills/regression-guard/examples.md"
  assert_file_contains "$f" "Fix proposal v2"
  assert_file_contains "$f" "JEV_FIX_PROPOSAL_V2"
  assert_file_contains "$f" "skill 本身 LLM"
}

# ────────────────────────────────────────────────────────────────────
# Probe 11: Cleanup 盤點 (TMO-018)
# ────────────────────────────────────────────────────────────────────

@test "CLEAN-a: docs/cleanup/cleanup-scan.py exists & runs OK" {
  local f="$REPO_ROOT/docs/cleanup/cleanup-scan.py"
  assert_path_is_file "$f"
  "$PY" "$f" >/dev/null 2>&1 || {
    echo "FAIL: cleanup-scan.py errored" >&2
    return 1
  }
}

@test "CLEAN-b: cleanup-scan.py classifies 4 categories" {
  local f="$REPO_ROOT/docs/cleanup/cleanup-scan.py"
  for cat in "KEEP" "REVIEW" "DELETE" "MERGE"; do
    assert_file_contains "$f" "$cat" || {
      echo "FAIL: cleanup-scan.py missing category: $cat" >&2
      return 1
    }
  done
}

@test "CLEAN-c: cleanup-scan.py excludes .venv/ files" {
  local f="$REPO_ROOT/docs/cleanup/cleanup-scan.py"
  assert_file_contains "$f" "is_excluded"
  assert_file_contains "$f" ".venv"
}

@test "CLEAN-d: cleanup-scan.py protects skill directories" {
  local f="$REPO_ROOT/docs/cleanup/cleanup-scan.py"
  for skill in dav-designer dav-planner dav-reflection regression-guard; do
    assert_file_contains "$f" "$skill" || {
      echo "FAIL: cleanup-scan.py should protect $skill/**" >&2
      return 1
    }
  done
}

@test "CLEAN-e: cleanup-scan.py --json output is valid JSON" {
  local f="$REPO_ROOT/docs/cleanup/cleanup-scan.py"
  local output
  output=$("$PY" "$f" --json 2>&1) || {
    echo "FAIL: cleanup-scan.py --json errored" >&2
    return 1
  }
  echo "$output" | "$PY" -c "import json, sys; data = json.loads(sys.stdin.read()); assert len(data) > 0; cats = {r['category'] for r in data}; assert 'KEEP' in cats; print(f'OK: {len(data)} files, categories: {cats}')" || {
    echo "FAIL: --json output not valid JSON" >&2
    return 1
  }
}

@test "CLEAN-f: scan output shows no .venv/ false positives" {
  local f="$REPO_ROOT/docs/cleanup/cleanup-scan.py"
  local output
  output=$("$PY" "$f" 2>&1) || {
    echo "FAIL: cleanup-scan.py errored" >&2
    return 1
  }
  if echo "$output" | grep -q "site-packages"; then
    echo "FAIL: cleanup-scan.py should exclude .venv/ but found site-packages" >&2
    return 1
  fi
}

@test "CLEAN-g: run_pipeline.sh forwards JEV_FIX_PROPOSAL_V2 to M6.1 step" {
  local f="$POC_DIR/run_pipeline.sh"
  # 確認 M6 區塊後接 M6.1 區塊
  local m6_line m61_line
  m6_line=$(grep -n "M6 " "$f" | head -1 | cut -d: -f1)
  m61_line=$(grep -n "M6.1" "$f" | head -1 | cut -d: -f1)
  if [ -z "$m6_line" ] || [ -z "$m61_line" ]; then
    echo "FAIL: M6 or M6.1 not found in run_pipeline.sh" >&2
    return 1
  fi
  if [ "$m6_line" -ge "$m61_line" ]; then
    echo "FAIL: M6.1 should come after M6" >&2
    return 1
  fi
}

# ────────────────────────────────────────────────────────────────────
# Probe 12: M6.2 patch + re-validate (TMO-019)
# ────────────────────────────────────────────────────────────────────

@test "M6.2-a: patch_parser.py exists with ParseResult + PatchOp" {
  local f="$POC_DIR/patch_parser.py"
  assert_path_is_file "$f"
  assert_file_contains "$f" "PatchOp"
  assert_file_contains "$f" "ParseResult"
  assert_file_contains "$f" "parse_fix_proposal"
  assert_file_contains "$f" "unified_diff"
}

@test "M6.2-b: patch_parser extracts (file, old, new) from unified diff" {
  cd "$POC_DIR"
  local sample=/tmp/m62-test-diff.md
  cat > "$sample" <<'EOF'
# Fix Proposal — US-M62

## 建議修正

```diff
--- a/foo.py
+++ b/foo.py
@@ -1,3 +1,3 @@
 def hello():
-    return "world"
+    return "planet"
```
EOF
  local out
  out=$("$PY" patch_parser.py "$sample" 2>&1) || {
    echo "FAIL: patch_parser.py CLI failed" >&2
    return 1
  }
  echo "$out" | grep -q "patches found:.*1" || {
    echo "FAIL: should find 1 patch" >&2
    echo "$out" | tail -10
    return 1
  }
  echo "$out" | grep -q "foo.py" || {
    echo "FAIL: should find foo.py" >&2
    return 1
  }
}

@test "M6.2-c: patch_parser handles describe_only mode (no diff code block)" {
  cd "$POC_DIR"
  local sample=/tmp/m62-test-describe.md
  cat > "$sample" <<'EOF'
# Fix Proposal — US-X

## 建議修正

檢查 `foo.py`（推測）。應加 try/except 包住 Stripe call 並回 200。

## 驗證步驟
EOF
  local out
  out=$("$PY" patch_parser.py "$sample" 2>&1) || {
    echo "FAIL: patch_parser.py CLI failed" >&2
    return 1
  }
  # describe_only 也應該抽到 patch（信心度低）
  echo "$out" | grep -q "patches found:.*[1-9]" || {
    echo "FAIL: describe_only should still find 1 patch (低信心)" >&2
    return 1
  }
  echo "$out" | grep -q "describe_only" || {
    echo "FAIL: should mark describe_only format" >&2
    return 1
  }
}

@test "M6.2-d: patch_parser returns 2 when no patches found" {
  cd "$POC_DIR"
  local sample=/tmp/m62-test-empty.md
  echo "# Empty Proposal" > "$sample"
  run "$PY" patch_parser.py "$sample"
  # exit 2 = 沒 patches
  [ "$status" -eq 2 ] || {
    echo "FAIL: empty file should return 2, got $status" >&2
    return 1
  }
}

@test "M6.2-e: playwright_patcher.py dry-run does NOT modify file" {
  cd "$POC_DIR"
  local sample=/tmp/m62-test-dryrun.py
  echo 'def hello(): return "world"' > "$sample"
  local before_content
  before_content=$(cat "$sample")
  run "$PY" playwright_patcher.py "$sample" \
    --old 'return "world"' --new 'return "planet"'
  [ "$status" -eq 0 ] || {
    echo "FAIL: dry-run should return 0" >&2
    return 1
  }
  # 檔案內容不變
  [ "$(cat "$sample")" = "$before_content" ] || {
    echo "FAIL: dry-run should not modify file" >&2
    return 1
  }
  # .bak 已建
  assert_path_is_file "${sample}.bak"
}

@test "M6.2-f: playwright_patcher.py --apply modifies file & creates backup" {
  cd "$POC_DIR"
  local sample=/tmp/m62-test-apply.py
  echo 'def hello(): return "world"' > "$sample"
  run "$PY" playwright_patcher.py "$sample" \
    --old 'return "world"' --new 'return "planet"' --apply
  [ "$status" -eq 0 ] || {
    echo "FAIL: --apply should return 0" >&2
    return 1
  }
  # 檔案已改
  grep -q "planet" "$sample" || {
    echo "FAIL: --apply should modify file" >&2
    return 1
  }
  # .bak 是舊版
  grep -q "world" "${sample}.bak" || {
    echo "FAIL: .bak should contain old content" >&2
    return 1
  }
  # rollback 還原
  "$PY" playwright_patcher.py "$sample" --rollback >/dev/null 2>&1
  grep -q "world" "$sample" || {
    echo "FAIL: --rollback should restore old content" >&2
    return 1
  }
}

@test "M6.2-g: playwright_patcher.py refuses ambiguous old_text (>1 match)" {
  cd "$POC_DIR"
  local sample=/tmp/m62-test-ambiguous.py
  cat > "$sample" <<'EOF'
foo = "x"
foo = "x"
EOF
  run "$PY" playwright_patcher.py "$sample" \
    --old 'foo = "x"' --new 'foo = "y"'
  [ "$status" -eq 1 ] || {
    echo "FAIL: ambiguous match should return 1, got $status" >&2
    return 1
  }
  grep -q "refusing to silently" <<< "$output" || grep -q "refusing to silently" /dev/null
}

@test "M6.2-h: playwright_patcher.py refuses old_text not found" {
  cd "$POC_DIR"
  local sample=/tmp/m62-test-notfound.py
  echo 'def hello(): return "world"' > "$sample"
  run "$PY" playwright_patcher.py "$sample" \
    --old 'NONEXISTENT_TEXT' --new 'X'
  [ "$status" -eq 1 ] || {
    echo "FAIL: not-found should return 1, got $status" >&2
    return 1
  }
}

@test "M6.2-i: re_validate.py classifies improvement (fail -N)" {
  cd "$POC_DIR"
  local before=/tmp/m62-before.json
  local after=/tmp/m62-after.json
  # 建模擬 before
  "$PY" -c "
import json
b = {'journey_id': 'US-M62', 'records': [
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'pass'}, 'blocked': False},
]}
json.dump(b, open('$before', 'w'))
a = {'journey_id': 'US-M62', 'records': [
  {'oracle': {'verdict': 'pass'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'pass'}, 'blocked': False},
]}
json.dump(a, open('$after', 'w'))
"
  run "$PY" re_validate.py "$before" "$after"
  [ "$status" -eq 0 ] || {
    echo "FAIL: improvement should return 0, got $status" >&2
    return 1
  }
  echo "$output" | grep -q "improvement" || {
    echo "FAIL: should classify as improvement" >&2
    return 1
  }
}

@test "M6.2-j: re_validate.py classifies regression (fail +N) & returns 1" {
  cd "$POC_DIR"
  local before=/tmp/m62-reg-before.json
  local after=/tmp/m62-reg-after.json
  "$PY" -c "
import json
b = {'journey_id': 'US-M62', 'records': [
  {'oracle': {'verdict': 'pass'}, 'blocked': False},
  {'oracle': {'verdict': 'pass'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
]}
json.dump(b, open('$before', 'w'))
a = {'journey_id': 'US-M62', 'records': [
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
  {'oracle': {'verdict': 'fail'}, 'blocked': False},
]}
json.dump(a, open('$after', 'w'))
"
  run "$PY" re_validate.py "$before" "$after"
  [ "$status" -eq 1 ] || {
    echo "FAIL: regression should return 1, got $status" >&2
    return 1
  }
  echo "$output" | grep -q "regression" || {
    echo "FAIL: should classify as regression" >&2
    return 1
  }
  echo "$output" | grep -q "rollback" || {
    echo "FAIL: regression should recommend rollback" >&2
    return 1
  }
}

@test "M6.2-k: run_pipeline.sh supports JEV_PATCH_AND_REVALIDATE=1" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "JEV_PATCH_AND_REVALIDATE"
  assert_file_contains "$f" "patch_parser"
  assert_file_contains "$f" "playwright_patcher"
  assert_file_contains "$f" "re_validate"
}

@test "M6.2-l: US-M62 AC file exists with 4 ACs" {
  local f="$REPO_ROOT/docs/ac/US-M62.md"
  assert_path_is_file "$f"
  for ac in "AC01" "AC02" "AC03" "AC04"; do
    assert_file_contains "$f" "$ac" || {
      echo "FAIL: US-M62.md missing $ac" >&2
      return 1
    }
  done
}

@test "M6.2-m: run_pipeline.sh captures M3 return code (does not let set -e break M4+)" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "M3_RC=0"
  assert_file_contains "$f" "M3 return code"
  # 確認 M3 區塊後有 M4
  local m3_line m4_line
  m3_line=$(grep -n "▶ M3" "$f" | head -1 | cut -d: -f1)
  m4_line=$(grep -n "▶ M4" "$f" | head -1 | cut -d: -f1)
  if [ -z "$m3_line" ] || [ -z "$m4_line" ]; then
    echo "FAIL: M3 or M4 not found" >&2
    return 1
  fi
  if [ "$m3_line" -ge "$m4_line" ]; then
    echo "FAIL: M4 should come after M3" >&2
    return 1
  fi
}
