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
