#!/usr/bin/env bats
#
# skills/dav-self-compact/tests/ctx-usage.bats
#
# Locks the cross-host measurement helper (ctx-usage.py): Claude Code /
# Qoder transcripts -> used tokens / percent / zone / action.
# The script is the ONLY way to measure context in hosts that expose no
# agent-callable tool (Claude Code, Qoder) — so its numbers must not drift.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../ctx-usage.py"
  [ -f "$SCRIPT" ] || { echo "missing $SCRIPT" >&2; return 1; }
  command -v python3 >/dev/null || skip "python3 not installed"
  FIXTURE_DIR="$BATS_TEST_TMPDIR"
}

# write_fixture <file> <used_tokens> [extra_json_line]
# Emits a minimal Anthropic-style transcript: one assistant message with
# usage = used_tokens (all in input_tokens).
write_fixture() {
  local file="$1" tokens="$2" extra="${3:-}"
  : > "$file"
  if [ -n "$extra" ]; then
    printf '%s\n' "$extra" >> "$file"
  fi
  printf '{"type":"assistant","timestamp":"2026-11-03T00:00:00Z","message":{"model":"test-model","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":0}}}\n' "$tokens" >> "$file"
}

run_ctx() {
  python3 "$SCRIPT" --host "$1" --session "$2" --window "$3" --json
}

# ---------- exact usage path (Claude Code) ----------
@test "CU1: usage path reports used tokens and smart zone" {
  write_fixture "$FIXTURE_DIR/a.jsonl" 40000
  run run_ctx claude "$FIXTURE_DIR/a.jsonl" 200000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"source": "usage"'
  echo "$output" | grep -q '"used_tokens": 40000'
  echo "$output" | grep -q '"percent": 20.0'
  echo "$output" | grep -q '"zone": "smart"'
  echo "$output" | grep -q '"action": "keep_working"'
}

@test "CU2: 50% -> soft / prepare_then_compact" {
  write_fixture "$FIXTURE_DIR/b.jsonl" 100000
  run run_ctx claude "$FIXTURE_DIR/b.jsonl" 200000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"zone": "soft"'
  echo "$output" | grep -q '"action": "prepare_then_compact"'
}

@test "CU3: 55% -> opportunity / compact_at_boundary" {
  write_fixture "$FIXTURE_DIR/c.jsonl" 110000
  run run_ctx claude "$FIXTURE_DIR/c.jsonl" 200000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"zone": "opportunity"'
  echo "$output" | grep -q '"action": "compact_at_boundary"'
}

@test "CU4: 60% -> hard / compact_now" {
  write_fixture "$FIXTURE_DIR/d.jsonl" 120000
  run run_ctx claude "$FIXTURE_DIR/d.jsonl" 200000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"zone": "hard"'
  echo "$output" | grep -q '"action": "compact_now"'
}

@test "CU5: absoluteCapTokens shrinks the effective window" {
  write_fixture "$FIXTURE_DIR/e.jsonl" 40000
  printf '{"contextWindow": 1000000, "absoluteCapTokens": 100000}\n' > "$FIXTURE_DIR/cfg.json"
  run python3 "$SCRIPT" --host claude --session "$FIXTURE_DIR/e.jsonl" --config "$FIXTURE_DIR/cfg.json" --json
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"effective_window_tokens": 100000'
  echo "$output" | grep -q '"percent": 40.0'
}

# ---------- compaction markers + estimate path (Qoder) ----------
@test "CU6: compact_boundary is reported with pre/post tokens" {
  local boundary='{"type":"system","subtype":"compact_boundary","timestamp":"2026-11-03T00:00:00Z","compactMetadata":{"trigger":"auto","preTokens":168340,"postTokens":4765,"messagesSummarized":244,"durationMs":62059}}'
  write_fixture "$FIXTURE_DIR/f.jsonl" 0 "$boundary"
  run run_ctx qoder "$FIXTURE_DIR/f.jsonl" 200000
  [ "$status" -eq 0 ]
  echo "$output" | grep -q '"source": "estimate"'
  echo "$output" | grep -q '"pre_tokens": 168340'
  echo "$output" | grep -q '"post_tokens": 4765'
}

@test "CU7: no usage and no transcript -> exit 2 with source=none" {
  run python3 "$SCRIPT" --host qoder --session "$FIXTURE_DIR/missing.jsonl" --json
  [ "$status" -eq 2 ]
  echo "$output" | grep -q '"source": "none"'
}
