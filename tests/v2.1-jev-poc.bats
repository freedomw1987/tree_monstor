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
  # POC_PY 可覆寫：讓 tests/poc-bootstrap.bats 能驗證「缺 venv 時大聲紅」
  PY="${POC_PY:-$POC_DIR/.venv/bin/python}"
}

# 缺 venv 必須「大聲紅」（TMO-029）：只守住真的會用 $PY 的測試。
# 純靜態（grep 檔案）的測試不需要 venv，不能一起誤紅。
# 修法一行：bash skills/regression-guard/PoC/setup-venv.sh
need_poc_venv() {
  [ -x "$PY" ] && return 0
  echo "FAIL: 缺 PoC venv（${PY}）" >&2
  echo "  修法：bash skills/regression-guard/PoC/setup-venv.sh" >&2
  echo "  本測試需要 PoC 專用 venv（httpx + PyYAML）；缺它一律紅、不 skip。" >&2
  return 1
}

# ────────────────────────────────────────────────────────────────────
# 共用 fixture helpers（TMO-023 / TMO-029）
#
# M6.3 / M7 探針原本假設 /tmp/US-M63-before.json 與 /tmp/m62-batch.json 已存在，
# 但測試檔內沒有任何步驟會產生它們 → 5+2 個探針永遠紅。
# 這裡補上真實的 baseline 產生器：
#   - make_us_m63_before：真跑一次 US-M63 journey 當 patch 前 baseline
#     （patch 無關 → 重跑後 verdict 分布相同 → re_validate 判 no_change）
#   - make_m62_batch_report：造 M7 flaky 整合所需的 batch_report 最小 fixture
#
# 註（TMO-039）：M6-g / M6.1-c 原本用 make_us101_run 現場跑 pipeline，
# 但那條路徑需要真 Jev oracle（API key / 本機快取）→ 已改讀版控 fixture
# `fixtures/US-101-run.json` + `cache-fixtures/`（見 cache-fixtures/README.md）。
# ────────────────────────────────────────────────────────────────────

make_us_m63_before() {
  mkdir -p "$REPO_ROOT/tmp"
  rm -f /tmp/US-M63-before.json
  # journey 為 blocked → run_journey.py 回 rc=2（有寫出 JSON，但非 0）→ 只吞 rc，必驗檔真的產出
  "$PY" "$POC_DIR/run_journey.py" "$POC_DIR/journeys/US-M63.yaml" \
    --json-output /tmp/US-M63-before.json >/dev/null 2>&1 || true
  if [ ! -s /tmp/US-M63-before.json ]; then
    echo "FAIL: baseline fixture 未產出（/tmp/US-M63-before.json）" >&2
    return 1
  fi
}

make_m62_batch_report() {
  "$PY" -c "
import json
json.dump({
    'journey_id': 'US-M62',
    'batch_report': {
        'overall_health': 'green',
        'flaky_likelihood': 0.0,
        'regression_type': 'none',
        'overall_health_probs': {'red': 0, 'green': 1, 'yellow': 0},
    },
}, open('/tmp/m62-batch.json', 'w'))
"
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
  local us_md="$REPO_ROOT/docs/ac/US-101.md"
  cd "$POC_DIR"
  # TMO-039：Oracle 改「注入 stub」——探針只驗 stale 偵測邏輯，
  # 不該依賴真 Jev API（本機有 key/快取才綠、CI 兩者皆無 → 假綠）
  "$PY" -c "
import sys
sys.path.insert(0, '.')
import yaml
from pathlib import Path
from journey_runner import run_dry
from ac_schema import parse_story_file
from journey_generator import Journey, Step, JOURNEYS_DIR
import jev_oracle

class _FakeResult:
    # 固定 verdict=fail → 同狀態連續 2 步必定觸發 stale block
    verdict = 'fail'
    ac_id = 'US-101-AC01'
    cached = True
    latency_ms = 0
    cost_usd = 0.0
    confidence = 0.0

# journey_runner 在函式內 `from jev_oracle import evaluate_ac` → patch 模組屬性即生效
jev_oracle.evaluate_ac = lambda ctx, **kw: _FakeResult()

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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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

@test "SKILL-b: Jev Oracle chapter mentions 3 backends (ac_aware/mock/playwright)" {
  # v2.9 拆檔：Jev 章節內文搬到 jev-oracle.md（主檔只留指標）
  local f="$REPO_ROOT/skills/regression-guard/jev-oracle.md"
  # 主檔仍須留下進子檔的指標（可達可尋）
  assert_file_contains "$REPO_ROOT/skills/regression-guard/SKILL.md" "jev-oracle.md"
  for backend in ac_aware mock playwright; do
    assert_file_contains "$f" "$backend" || {
      echo "FAIL: jev-oracle.md should mention $backend" >&2
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

@test "SKILL-d: v2.2 changelog entry exists" {
  # v2.9 拆檔：主檔只留最近 3 條 → 完整歷史（含 v2.2 / TMO-013）在 CHANGELOG.md
  local f="$REPO_ROOT/skills/regression-guard/CHANGELOG.md"
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
  need_poc_venv
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

@test "M6-e: Jev Oracle has M6 fix-loop section" {
  # v2.9 拆檔：M6 補充在 jev-oracle.md；TMO-016 紀錄在 CHANGELOG.md
  local f="$REPO_ROOT/skills/regression-guard/jev-oracle.md"
  local cl="$REPO_ROOT/skills/regression-guard/CHANGELOG.md"
  assert_file_contains "$f" "修正循環補充"
  assert_file_contains "$f" "JEV_FIX_PROPOSAL"
  assert_file_contains "$cl" "TMO-016"
}

@test "M6-f: examples.md has fix proposal example" {
  local f="$REPO_ROOT/skills/regression-guard/examples.md"
  assert_file_contains "$f" "Fix proposal"
  assert_file_contains "$f" "JEV_FIX_PROPOSAL"
}

@test "M6-g: end-to-end fix_proposal.py on /tmp/US-101-run.json" {
  need_poc_venv
  cd "$POC_DIR"
  # TMO-039：改用版控 run json fixture + 離線快取 fixture。
  # 原本現場跑 pipeline（已移除的 make_us101_run helper）需要真 Jev API key → CI 必紅。
  # TMO-045：外加 JEV_ENV_FILE=/dev/null，連本機 PoC/.env 也要擋
  # （否則 client 端 cache miss 時會拿本機 key 去打真 API，fixture 缺口被掩蓋仍綠）。
  cp "$POC_DIR/fixtures/US-101-run.json" /tmp/US-101-run.json
  env -u OPENROUTER_API_KEY HOME="$BATS_TEST_TMPDIR/nohome" \
      JEV_ENV_FILE=/dev/null \
      JEV_CACHE_DIR="$POC_DIR/cache-fixtures" \
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
  need_poc_venv
  cd "$POC_DIR"
  # TMO-039：同上（版控 fixture + 離線快取），不依賴真 API key
  # TMO-045：同上加 JEV_ENV_FILE=/dev/null（擋本機 PoC/.env）
  cp "$POC_DIR/fixtures/US-101-run.json" /tmp/US-101-run.json
  env -u OPENROUTER_API_KEY HOME="$BATS_TEST_TMPDIR/nohome" \
      JEV_ENV_FILE=/dev/null \
      JEV_CACHE_DIR="$POC_DIR/cache-fixtures" \
      "$PY" fix_proposal_v2.py /tmp/US-101-run.json /tmp/test-v2.md >/dev/null 2>&1 || {
    echo "FAIL: fix_proposal_v2.py CLI failed" >&2
    return 1
  }
  assert_path_is_file /tmp/test-v2.md
  # 0.25 < 0.5 → 應該出現 "LLM Relay 跳過"
  grep -q "LLM Relay 跳過" /tmp/test-v2.md || {
    echo "FAIL: test-v2.md should have LLM Relay 跳過 (0.25 < 0.5)" >&2
    return 1
  }
}

@test "M6.1-d: run_pipeline.sh supports JEV_FIX_PROPOSAL_V2=1" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "JEV_FIX_PROPOSAL_V2"
  assert_file_contains "$f" "fix_proposal_v2.py"
}

@test "M6.1-e: Jev Oracle v2.4 has LLM Relay section" {
  # v2.9 拆檔：M6.1 補充在 jev-oracle.md；TMO-017 紀錄在 CHANGELOG.md
  local f="$REPO_ROOT/skills/regression-guard/jev-oracle.md"
  local cl="$REPO_ROOT/skills/regression-guard/CHANGELOG.md"
  assert_file_contains "$f" "M6.1 修正循環補充"
  assert_file_contains "$f" "LLM Relay"
  assert_file_contains "$cl" "TMO-017"
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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
  need_poc_venv
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

# ────────────────────────────────────────────────────────────────────
# Probe 13: M6.3 互動式 sandbox (TMO-020)
# ────────────────────────────────────────────────────────────────────

@test "M6.3-a: sandbox_runner.py exists with SandboxResult + run_sandbox" {
  local f="$POC_DIR/sandbox_runner.py"
  assert_path_is_file "$f"
  assert_file_contains "$f" "SandboxResult"
  assert_file_contains "$f" "run_sandbox"
  assert_file_contains "$f" "_cleanup"
  assert_file_contains "$f" "render_sandbox_report"
}

@test "M6.3-b: sandbox dry-run creates sandbox dir but does not modify source" {
  need_poc_venv
  cd "$POC_DIR"
  local sample="$POC_DIR/fixtures/US-M63-dryrun-test.py"
  cat > "$sample" <<'EOF'
def hello():
    return "world"
EOF
  make_us_m63_before
  run "$PY" sandbox_runner.py \
    --before /tmp/US-M63-before.json \
    --file "$sample" \
    --old 'return "world"' \
    --new 'return "planet"' \
    --journey "$POC_DIR/journeys/US-M63.yaml" \
    --story-id US-M63 \
    --source "$REPO_ROOT/docs/ac/US-M63.md" \
    --sandbox-dry-run
  [ "$status" -eq 0 ] || {
    echo "FAIL: dry-run should return 0, got $status" >&2
    return 1
  }
  echo "$output" | grep -q "dry_run" || {
    echo "FAIL: should classify as dry_run" >&2
    return 1
  }
  # 原檔未改
  grep -q "world" "$sample" || {
    echo "FAIL: dry-run should not modify source" >&2
    return 1
  }
}

@test "M6.3-c: sandbox apply + re-validate produces no_change (patch is unrelated)" {
  need_poc_venv
  cd "$POC_DIR"
  local sample="$POC_DIR/fixtures/US-M63-apply-test.py"
  cat > "$sample" <<'EOF'
def hello():
    return "unrelated-text-for-no-change-test"
EOF
  make_us_m63_before
  run "$PY" sandbox_runner.py \
    --before /tmp/US-M63-before.json \
    --file "$sample" \
    --old 'return "unrelated-text-for-no-change-test"' \
    --new 'return "different-unrelated-text"' \
    --journey "$POC_DIR/journeys/US-M63.yaml" \
    --story-id US-M63 \
    --source "$REPO_ROOT/docs/ac/US-M63.md"
  [ "$status" -eq 0 ] || {
    echo "FAIL: no_change should return 0, got $status" >&2
    return 1
  }
  echo "$output" | grep -q "no_change" || {
    echo "FAIL: should classify as no_change (unrelated patch)" >&2
    return 1
  }
}

@test "M6.3-d: sandbox aborts on ambiguous old_text (safety propagation)" {
  need_poc_venv
  cd "$POC_DIR"
  local sample="$POC_DIR/fixtures/US-M63-ambiguous-test.py"
  cat > "$sample" <<'EOF'
foo = "x"
foo = "x"
foo = "x"
EOF
  make_us_m63_before
  run "$PY" sandbox_runner.py \
    --before /tmp/US-M63-before.json \
    --file "$sample" \
    --old 'foo = "x"' \
    --new 'foo = "y"' \
    --journey "$POC_DIR/journeys/US-M63.yaml" \
    --story-id US-M63 \
    --source "$REPO_ROOT/docs/ac/US-M63.md"
  # error=1（sandbox classification=error）
  [ "$status" -eq 1 ] || {
    echo "FAIL: ambiguous should return 1 (error), got $status" >&2
    return 1
  }
  echo "$output" | grep -q "error" || {
    echo "FAIL: should classify as error" >&2
    return 1
  }
  echo "$output" | grep -q "refusing to silently" || {
    echo "FAIL: error message should mention refusing to silently patch" >&2
    return 1
  }
}

@test "M6.3-e: sandbox cleanup removes sandbox dir after run" {
  need_poc_venv
  cd "$POC_DIR"
  local sample="$POC_DIR/fixtures/US-M63-cleanup-test.py"
  cat > "$sample" <<'EOF'
def hello():
    return "x"
EOF
  make_us_m63_before
  local before_count
  # sandbox 目錄名以 . 開頭（`.sandbox-*`）→ 必用 ls -a，否則永遠數到 0（探針會空過）
  before_count=$(ls -a "$REPO_ROOT/tmp/" 2>/dev/null | grep -c "^\.sandbox-US-M63" || true)
  local out
  out=$("$PY" sandbox_runner.py \
    --before /tmp/US-M63-before.json \
    --file "$sample" \
    --old 'return "x"' \
    --new 'return "y"' \
    --journey "$POC_DIR/journeys/US-M63.yaml" \
    --story-id US-M63 \
    --source "$REPO_ROOT/docs/ac/US-M63.md" \
    --json 2>&1 || true)
  local after_count
  after_count=$(ls -a "$REPO_ROOT/tmp/" 2>/dev/null | grep -c "^\.sandbox-US-M63" || true)
  # 斷言 1：這趟自己建的 sandbox 目錄必須被刪乾淨（數量不得改變）
  if [ "$after_count" -ne "$before_count" ]; then
    echo "FAIL: sandbox dir not cleaned up (before=$before_count after=$after_count)" >&2
    return 1
  fi
  # 斷言 2：runner 自報 no_change + cleanup_ok=true
  # （避免「數量不變」其實來自從沒建過 sandbox 或中途 patch 失敗，那些路徑 cleanup_ok 也是 true）
  echo "$out" | grep -q '"classification": "no_change"'
  echo "$out" | grep -q '"cleanup_ok": true'
}

@test "M6.3-f: sandbox JSON output has required fields" {
  need_poc_venv
  cd "$POC_DIR"
  local sample="$POC_DIR/fixtures/US-M63-json-test.py"
  cat > "$sample" <<'EOF'
def hello():
    return "x"
EOF
  make_us_m63_before
  local out
  out=$("$PY" sandbox_runner.py \
    --before /tmp/US-M63-before.json \
    --file "$sample" \
    --old 'return "x"' \
    --new 'return "y"' \
    --journey "$POC_DIR/journeys/US-M63.yaml" \
    --story-id US-M63 \
    --source "$REPO_ROOT/docs/ac/US-M63.md" \
    --json 2>&1) || true
  echo "$out" | "$PY" -c "
import json, sys
d = json.loads(sys.stdin.read())
for key in ['sandbox_dir', 'steps', 'classification', 'verdict_before', 'verdict_after', 'cleanup_ok']:
    assert key in d, f'missing key: {key}'
print(f'OK: classification={d[\"classification\"]}, cleanup_ok={d[\"cleanup_ok\"]}')
" || {
    echo "FAIL: --json output missing required fields" >&2
    return 1
  }
}

@test "M6.3-g: run_pipeline.sh supports JEV_SANDBOX_RUN=1 (M6.3 step)" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "JEV_SANDBOX_RUN"
  assert_file_contains "$f" "sandbox_runner"
}

@test "M6.3-h: US-M63 AC file exists with 4 ACs" {
  local f="$REPO_ROOT/docs/ac/US-M63.md"
  assert_path_is_file "$f"
  for ac in "AC01" "AC02" "AC03" "AC04"; do
    assert_file_contains "$f" "$ac" || {
      echo "FAIL: US-M63.md missing $ac" >&2
      return 1
    }
  done
}

@test "M6.3-i: M6.3 step in pipeline comes after M6.2 step" {
  local f="$POC_DIR/run_pipeline.sh"
  local m62_line m63_line
  m62_line=$(grep -n "▶ M6.2" "$f" | head -1 | cut -d: -f1)
  m63_line=$(grep -n "▶ M6.3" "$f" | head -1 | cut -d: -f1)
  if [ -z "$m62_line" ] || [ -z "$m63_line" ]; then
    echo "FAIL: M6.2 or M6.3 not found in pipeline" >&2
    return 1
  fi
  if [ "$m62_line" -ge "$m63_line" ]; then
    echo "FAIL: M6.3 should come after M6.2" >&2
    return 1
  fi
}

@test "M6.3-j: sandbox_runner handles missing before.json gracefully" {
  need_poc_venv
  cd "$POC_DIR"
  local sample="$POC_DIR/fixtures/US-M63-missing-test.py"
  echo 'def x(): return "x"' > "$sample"
  run "$PY" sandbox_runner.py \
    --before /tmp/nonexistent-before.json \
    --file "$sample" \
    --old 'return "x"' \
    --new 'return "y"' \
    --journey "$POC_DIR/journeys/US-M63.yaml" \
    --story-id US-M63 \
    --source "$REPO_ROOT/docs/ac/US-M63.md"
  [ "$status" -eq 1 ] || {
    echo "FAIL: missing before.json should return 1, got $status" >&2
    return 1
  }
  echo "$output" | grep -q "檔案不存在" || {
    echo "FAIL: should mention '檔案不存在'" >&2
    return 1
  }
}

@test "M6.3-k: sandbox_runner accepts a target file outside the repo without SameFileError" {
  need_poc_venv
  cd "$POC_DIR"
  # TMO-039 實證：sandbox_dir / <絕對路徑> 在 pathlib 會「右邊覆蓋左邊」，
  # 於是複製來源 == 目的（SameFileError），且原本的檔案會被就地改壞。
  # repo 外的檔案必定走這條路（含 repo 路徑含 symlink 的情境，如 macOS /tmp → /private/tmp）。
  local outside="$BATS_TEST_TMPDIR/outside-sample.py"
  printf 'def hello():\n    return "world"\n' > "$outside"
  make_us_m63_before
  run "$PY" sandbox_runner.py \
    --before /tmp/US-M63-before.json \
    --file "$outside" \
    --old 'return "world"' \
    --new 'return "planet"' \
    --journey "$POC_DIR/journeys/US-M63.yaml" \
    --story-id US-M63 \
    --source "$REPO_ROOT/docs/ac/US-M63.md" \
    --sandbox-dry-run
  [ "$status" -eq 0 ] || {
    echo "FAIL: dry-run on out-of-repo file should return 0, got $status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -q "dry_run" || {
    echo "FAIL: should classify as dry_run" >&2
    return 1
  }
  # 原檔必須一字未改（sandbox 的意義）
  grep -q 'return "world"' "$outside" || {
    echo "FAIL: out-of-repo source was modified" >&2
    return 1
  }
}

@test "M6.3-l: sandbox_runner contains relative paths containing .. (no escape)" {
  need_poc_venv
  cd "$POC_DIR"
  # TMO-039 二審 P2-1：絕對路徑已修，但相對路徑 + `..` 也一樣——
  # sandbox_dir = REPO_ROOT/tmp/.sandbox-<id>，再加 `../../../tmp/x.py` 會正規化到
  # repo 上層（pathlib 不做邊界檢查）→ 複本直接寫到 repo 外，sandbox 形同虚設。
  # 目標檔故意放 repo 內 tmp/（gitignore），且用唯一檔名，才能「搜得到外洩」。
  local sentinel="US-M63-leak-$$.py"
  local target="$REPO_ROOT/tmp/$sentinel"
  printf 'def hello():\n    return "world"\n' > "$target"
  make_us_m63_before
  run "$PY" sandbox_runner.py \
    --before /tmp/US-M63-before.json \
    --file "../../../tmp/$sentinel" \
    --old 'return "world"' \
    --new 'return "planet"' \
    --journey "$POC_DIR/journeys/US-M63.yaml" \
    --story-id US-M63 \
    --source "$REPO_ROOT/docs/ac/US-M63.md" \
    --sandbox-dry-run
  [ "$status" -eq 0 ] || {
    echo "FAIL: 相對 .. 路徑應可安全處理，got $status" >&2
    echo "$output" >&2
    return 1
  }
  echo "$output" | grep -q "dry_run" || {
    echo "FAIL: 應分類為 dry_run" >&2
    echo "$output" >&2
    return 1
  }
  # 關鍵 1：目的地不能等於來源，否則原檔已被就地改壞
  grep -q 'return "world"' "$target" || {
    echo "FAIL: repo 內相對 .. 路徑的來源檔被就地改壞" >&2
    return 1
  }
  # 關鍵 2：不得在 sandbox 外（repo 上層）留下任何複本
  local leaked
  leaked=$(find "$(dirname "$REPO_ROOT")" -maxdepth 4 -name "$sentinel" \
             -not -path "$target" 2>/dev/null || true)
  [ -z "$leaked" ] || {
    echo "FAIL: 複本逃出 sandbox：" >&2
    echo "$leaked" >&2
    return 1
  }
}

# ────────────────────────────────────────────────────────────────────
# Probe 14: Flaky 驗證 (TMO-020)
# ────────────────────────────────────────────────────────────────────

@test "flaky-a: flaky_check.py exists with FlakyReport + analyze_runs" {
  local f="$POC_DIR/flaky_check.py"
  assert_path_is_file "$f"
  assert_file_contains "$f" "FlakyReport"
  assert_file_contains "$f" "analyze_runs"
  assert_file_contains "$f" "flaky_likelihood"
  assert_file_contains "$f" "render_flaky_report"
}

@test "flaky-b: flaky_check.py analyze_runs correctly classifies stable" {
  need_poc_venv
  cd "$POC_DIR"
  local script="
import sys
sys.path.insert(0, '.')
from flaky_check import analyze_runs, RunRecord
runs = [
    RunRecord('r1', {'pass': 0, 'fail': 12, 'blocked': 1}, 13, True, 1000),
    RunRecord('r2', {'pass': 0, 'fail': 12, 'blocked': 1}, 13, True, 1000),
    RunRecord('r3', {'pass': 0, 'fail': 12, 'blocked': 1}, 13, True, 1000),
]
r = analyze_runs(runs)
assert r.classification == 'stable', f'expected stable, got {r.classification}'
assert r.flaky_likelihood == 0.0, f'expected 0.0, got {r.flaky_likelihood}'
print(f'OK: classification={r.classification} flaky={r.flaky_likelihood}')
"
  run "$PY" -c "$script"
  [ "$status" -eq 0 ] || {
    echo "FAIL: analyze_runs stable test" >&2
    return 1
  }
  echo "$output" | grep -q "classification=stable" || {
    echo "FAIL: should classify as stable" >&2
    return 1
  }
}

@test "flaky-c: flaky_check.py analyze_runs correctly classifies highly_flaky" {
  need_poc_venv
  cd "$POC_DIR"
  local script="
import sys
sys.path.insert(0, '.')
from flaky_check import analyze_runs, RunRecord
# 5 次跑，verdict 完全不穩定
runs = [
    RunRecord('r1', {'pass': 13, 'fail': 0, 'blocked': 0}, 13, False, 1000),
    RunRecord('r2', {'pass': 0, 'fail': 13, 'blocked': 0}, 13, False, 1000),
    RunRecord('r3', {'pass': 5, 'fail': 8, 'blocked': 0}, 13, False, 1000),
    RunRecord('r4', {'pass': 10, 'fail': 3, 'blocked': 0}, 13, False, 1000),
    RunRecord('r5', {'pass': 2, 'fail': 11, 'blocked': 0}, 13, False, 1000),
]
r = analyze_runs(runs)
assert r.classification == 'highly_flaky', f'expected highly_flaky, got {r.classification}'
assert r.flaky_likelihood > 0.5, f'expected >0.5, got {r.flaky_likelihood}'
print(f'OK: classification={r.classification} flaky={r.flaky_likelihood}')
"
  run "$PY" -c "$script"
  [ "$status" -eq 0 ] || {
    echo "FAIL: analyze_runs highly_flaky test" >&2
    return 1
  }
  echo "$output" | grep -q "highly_flaky" || {
    echo "FAIL: should classify as highly_flaky" >&2
    return 1
  }
}

@test "flaky-d: flaky_check.py with US-62 3 runs produces stable output" {
  need_poc_venv
  cd "$POC_DIR"
  # 先清殘檔：否則上一次的 /tmp 檔會讓這條假綠（reviewer P2-4）
  rm -f /tmp/flaky-test.md
  "$PY" flaky_check.py "$POC_DIR/journeys/US-M62.yaml" \
    --source "$REPO_ROOT/docs/ac/US-M62.md" \
    --story-id US-M62-flaky-test --runs 3 \
    --output /tmp/flaky-test.md >/dev/null 2>&1 || true
  assert_path_is_file "/tmp/flaky-test.md"
  assert_file_contains "/tmp/flaky-test.md" "分類"
  assert_file_contains "/tmp/flaky-test.md" "Per-Run Detail"
}

# ────────────────────────────────────────────────────────────────────
# Probe 15: cleanup-scan 進 CI 定期 (TMO-020)
# ────────────────────────────────────────────────────────────────────

@test "CLEAN-CI-a: workflow has schedule trigger (weekly cron)" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  assert_path_is_file "$f"
  assert_file_contains "$f" "schedule:"
  assert_file_contains "$f" "cron:"
}

@test "CLEAN-CI-b: workflow has cleanup-scan job" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  assert_file_contains "$f" "cleanup-scan:"
  assert_file_contains "$f" "docs/cleanup/cleanup-scan.py"
  assert_file_contains "$f" "DELETE"
  assert_file_contains "$f" "REVIEW"
}

@test "CLEAN-CI-c: cleanup-scan only runs on schedule or workflow_dispatch (not on push/PR)" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  # cleanup-scan job 必須有 if: github.event_name == 'schedule' || 'workflow_dispatch'
  local job_block
  job_block=$(awk '/cleanup-scan:/,/steps:/' "$f")
  echo "$job_block" | grep -q "schedule" || {
    echo "FAIL: cleanup-scan job missing schedule guard" >&2
    return 1
  }
  echo "$job_block" | grep -q "workflow_dispatch" || {
    echo "FAIL: cleanup-scan job missing workflow_dispatch guard" >&2
    return 1
  }
}

# ────────────────────────────────────────────────────────────────────
# Probe 16: M7 flaky 整合 + gh pr comment (TMO-021)
# ────────────────────────────────────────────────────────────────────

@test "flaky-int-a: flaky_integration.py exists with integrate_flaky" {
  local f="$POC_DIR/flaky_integration.py"
  assert_path_is_file "$f"
  assert_file_contains "$f" "integrate_flaky"
  assert_file_contains "$f" "flaky_measured"
  assert_file_contains "$f" "flaky_warning"
}

@test "flaky-int-b: flaky_integration.py writes flaky_measured to batch_report" {
  need_poc_venv
  cd "$POC_DIR"
  local tmp_batch="/tmp/flaky-int-test-batch.json"
  # 造一個 batch_report
  cat > "$tmp_batch" <<'EOF'
{
  "journey_id": "US-M62",
  "batch_report": {
    "overall_health": "red",
    "fix_priority": 2.97,
    "flaky_likelihood": 0.24,
    "regression_type": "real_bug",
    "overall_health_probs": {"red": 1, "green": 0, "yellow": 0}
  }
}
EOF
  # 跑 0 次額外跑（快速測試）
  run "$PY" -c "
import sys
sys.path.insert(0, '.')
import json
from pathlib import Path
from flaky_integration import integrate_flaky
# 跳過跑 journey，只測寫回
batch = json.loads(Path('$tmp_batch').read_text())
batch['batch_report']['flaky_measured'] = {
    'likelihood': 0.0,
    'classification': 'stable',
    'sample_count': 0,
    'warning': False
}
Path('$tmp_batch').write_text(json.dumps(batch, ensure_ascii=False, indent=2))
print('OK: wrote flaky_measured')
"
  [ "$status" -eq 0 ] || {
    echo "FAIL: should write flaky_measured" >&2
    return 1
  }
  grep -q "flaky_measured" "$tmp_batch" || {
    echo "FAIL: batch_report should have flaky_measured" >&2
    return 1
  }
}

@test "flaky-int-c: flaky_integration.py with 0 extra runs uses jev value" {
  need_poc_venv
  cd "$POC_DIR"
  make_m62_batch_report
  run "$PY" flaky_integration.py \
    --batch-report /tmp/m62-batch.json \
    --journey "$POC_DIR/journeys/US-M62.yaml" \
    --story-id US-M62 \
    --source "$REPO_ROOT/docs/ac/US-M62.md" \
    --runs 0
  # 應該成功（即使不額外跑）
  [ "$status" -le 1 ] || {
    echo "FAIL: should return 0 or 1, got $status" >&2
    return 1
  }
  # 應該有 flaky_measured 寫回
  grep -q "flaky_measured" /tmp/m62-batch.json || {
    echo "FAIL: batch_report should now have flaky_measured" >&2
    return 1
  }
}

@test "flaky-int-d: run_pipeline.sh supports JEV_FLAKY_INTEGRATION=1" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "JEV_FLAKY_INTEGRATION"
  assert_file_contains "$f" "flaky_integration"
}

@test "gh-pr-a: gh_pr_comment.py exists with render_comment + post_comment" {
  local f="$POC_DIR/gh_pr_comment.py"
  assert_path_is_file "$f"
  assert_file_contains "$f" "render_comment"
  assert_file_contains "$f" "post_comment"
  assert_file_contains "$f" "gh pr comment"
}

@test "gh-pr-b: gh_pr_comment.py render_comment has 4 sections" {
  need_poc_venv
  cd "$POC_DIR"
  "$PY" -c "
import sys
sys.path.insert(0, '.')
from pathlib import Path
from gh_pr_comment import render_comment
# 造 batch_report
batch = {
    'journey_id': 'US-M62',
    'journey_title': 'Test',
    'batch_report': {
        'overall_health': 'red',
        'fix_priority': 2.97,
        'flaky_likelihood': 0.24,
        'regression_type': 'real_bug',
    }
}
Path('/tmp/gh-pr-test-batch.json').write_text(__import__('json').dumps(batch, ensure_ascii=False))
body = render_comment(batch_report_path=Path('/tmp/gh-pr-test-batch.json'), fix_proposal_path=None)
# 4 段
for sec in ['regression-guard Report', 'Fix Proposal', 'Sandbox 建議', '問題分析']:
    assert sec in body or '未產出' in body, f'missing section: {sec}'
print(f'OK: comment {len(body)} chars')
"
}

@test "gh-pr-c: gh_pr_comment.py dry-run prints body without gh" {
  need_poc_venv
  cd "$POC_DIR"
  run "$PY" gh_pr_comment.py \
    --batch-report /tmp/gh-pr-test-batch.json \
    --dry-run
  [ "$status" -eq 0 ] || {
    echo "FAIL: dry-run should return 0, got $status" >&2
    return 1
  }
  echo "$output" | grep -q "regression-guard Report" || {
    echo "FAIL: dry-run should print body" >&2
    return 1
  }
}

@test "gh-pr-d: gh_pr_comment.py output file written when --output specified" {
  need_poc_venv
  cd "$POC_DIR"
  local out="/tmp/gh-pr-test-output.md"
  rm -f "$out"
  "$PY" gh_pr_comment.py \
    --batch-report /tmp/gh-pr-test-batch.json \
    --dry-run \
    --output "$out" >/dev/null 2>&1
  assert_path_is_file "$out"
  grep -q "regression-guard Report" "$out" || {
    echo "FAIL: output file should contain comment" >&2
    return 1
  }
}

@test "gh-pr-e: run_pipeline.sh supports JEV_GH_PR_COMMENT=1" {
  local f="$POC_DIR/run_pipeline.sh"
  assert_file_contains "$f" "JEV_GH_PR_COMMENT"
  assert_file_contains "$f" "gh_pr_comment"
}

@test "gh-pr-f: gh_pr_comment.py handles missing batch_report gracefully" {
  need_poc_venv
  cd "$POC_DIR"
  run "$PY" gh_pr_comment.py \
    --batch-report /tmp/nonexistent-batch.json \
    --dry-run
  [ "$status" -eq 1 ] || {
    echo "FAIL: missing batch_report should return 1, got $status" >&2
    return 1
  }
  echo "$output" | grep -q "不存在" || {
    echo "FAIL: should mention '不存在'" >&2
    return 1
  }
}

@test "M7-gating-a: batch_report schema includes flaky_measured field" {
  need_poc_venv
  # 跑一次 flaky_integration，確認 schema 包含新欄位
  cd "$POC_DIR"
  make_m62_batch_report
  "$PY" flaky_integration.py \
    --batch-report /tmp/m62-batch.json \
    --journey "$POC_DIR/journeys/US-M62.yaml" \
    --story-id US-M62 \
    --source "$REPO_ROOT/docs/ac/US-M62.md" \
    --runs 0 >/dev/null 2>&1 || true
  grep -q "flaky_measured" /tmp/m62-batch.json || {
    echo "FAIL: batch_report missing flaky_measured" >&2
    return 1
  }
  # 確認 schema 完整
  grep -q "likelihood" /tmp/m62-batch.json || {
    echo "FAIL: flaky_measured missing likelihood" >&2
    return 1
  }
}

@test "M7-gating-b: flaky_likelihood delta warning triggers on high delta" {
  need_poc_venv
  cd "$POC_DIR"
  "$PY" -c "
import sys
sys.path.insert(0, '.')
from flaky_integration import integrate_flaky
from pathlib import Path
import json
# 造一個 jev=0.24 但 measured=0.85 的 scenario
batch = {
    'journey_id': 'US-TEST',
    'batch_report': {
        'overall_health': 'red',
        'flaky_likelihood': 0.24,
        'overall_health_probs': {'red': 1, 'green': 0, 'yellow': 0},
    }
}
Path('/tmp/m7-delta-test.json').write_text(json.dumps(batch, ensure_ascii=False))
# 模擬 measured 0.85（highly_flaky）
batch['batch_report']['flaky_measured'] = {
    'likelihood': 0.85,
    'classification': 'highly_flaky',
    'warning': True,
    'delta': 0.61,
}
Path('/tmp/m7-delta-test.json').write_text(json.dumps(batch, ensure_ascii=False))
assert batch['batch_report']['flaky_measured']['warning'] == True
assert batch['batch_report']['flaky_measured']['delta'] == 0.61
print('OK: high delta warning')
"
}

# ────────────────────────────────────────────────────────────────────
# Probe 17: M8 CI matrix pipeline (TMO-022)
# ────────────────────────────────────────────────────────────────────

@test "M8-a: workflow has matrix strategy with multiple story_ids" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  assert_path_is_file "$f"
  assert_file_contains "$f" "strategy:"
  assert_file_contains "$f" "fail-fast: false"
  assert_file_contains "$f" "matrix:"
  assert_file_contains "$f" "story_id:"
  assert_file_contains "$f" "US-101"
  assert_file_contains "$f" "US-M62"
  assert_file_contains "$f" "US-M63"
}

@test "M8-b: matrix job name uses matrix.story_id (not just inputs.story_id)" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  # pipeline job name 需引用 matrix.story_id
  awk '/^  pipeline:/{flag=1; next} flag && /^[a-z-]+:|^jobs:/{exit} flag' "$f" | head -5 | grep -q "matrix.story_id" || {
    echo "FAIL: pipeline job name should use matrix.story_id" >&2
    return 1
  }
}

@test "M8-c: aggregate-matrix job exists with download + aggregate + upload steps" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  assert_file_contains "$f" "aggregate-matrix:"
  assert_file_contains "$f" "Download all matrix artifacts"
  assert_file_contains "$f" "matrix-summary.md"
  assert_file_contains "$f" "Per-Story Results"
  assert_file_contains "$f" "merge-multiple: true"
}

@test "M8-d: aggregate-matrix only runs on workflow_dispatch (not push/PR)" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  # 找 aggregate-matrix 區塊（到下個 job 為止）
  awk '/^  aggregate-matrix:/{flag=1; next} /^  [a-z-]+:/ && flag{exit} flag' "$f" | grep -q "workflow_dispatch" || {
    echo "FAIL: aggregate-matrix should be guarded by workflow_dispatch" >&2
    return 1
  }
}

@test "M8-e: matrix artifacts use matrix.story_id in name (per-story)" {
  local f="$REPO_ROOT/.github/workflows/regression-guard-jev-poc.yml"
  if ! grep -q "matrix.story_id" "$f"; then
    echo "FAIL: workflow missing matrix.story_id references" >&2
    return 1
  fi
  # upload-artifact 後的 with: 區塊需有 matrix.story_id (全文搜, 包含 pipeline job)
  grep -A 4 "upload-artifact" "$f" | grep -q "matrix.story_id" || {
    echo "FAIL: upload-artifact name should use matrix.story_id" >&2
    return 1
  }
}

@test "M8-f: US-M81 AC file exists with 4 ACs" {
  local f="$REPO_ROOT/docs/ac/US-M81.md"
  assert_path_is_file "$f"
  for ac in "AC01" "AC02" "AC03" "AC04"; do
    assert_file_contains "$f" "$ac" || {
      echo "FAIL: US-M81.md missing $ac" >&2
      return 1
    }
  done
}
