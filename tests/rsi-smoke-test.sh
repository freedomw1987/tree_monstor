#!/usr/bin/env bash
# tests/rsi-smoke-test.sh — 為 US-017 設置 3 個 mock 專案
# 跑完會建 mock 專案 + observation JSON
#
# Setup:
#   - 3 個 mock 專案在 ~/.tree-monstor/projects/{A,B,C}/
#   - 每個 mock 專案有 1 個 observation JSON 在 ~/.tree-monstor/observations/{a8_a8}/{TODAY}.json

set -uo pipefail

# === 預設值 ===
HOME_DIR="${HOME}"
TREE_MONSTOR_ROOT="$HOME_DIR/.tree-monstor"
PROJECTS_ROOT="$TREE_MONSTOR_ROOT/projects"
OBS_ROOT="$TREE_MONSTOR_ROOT/observations"
TODAY=$(date '+%Y-%m-%d')
CLEANUP=true
MOCK_PROJECTS=("test-proj-A" "test-proj-B" "test-proj-C")

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-smoke-test.sh [options]

為 US-017 建立 3 個 mock 專案 + 產出 observation JSON，模擬跨專案 RSI 觀察。

Options:
  --keep     不要清理（保留 mock 專案方便檢查）
  --help     顯示說明

產出：
  - ~/.tree-monstor/projects/test-proj-{A,B,C}/
  - ~/.tree-monstor/observations/{project-id}/$TODAY.json

Example:
  ./tests/rsi-smoke-test.sh --keep
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --keep)
            CLEANUP=false
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# === 主程式 ===
echo "=== RSI smoke test setup ==="
echo "TODAY: $TODAY"
echo "MOCK_PROJECTS: ${MOCK_PROJECTS[*]}"
echo ""

# 1. 建 mock 專案
mkdir -p "$PROJECTS_ROOT"
for proj in "${MOCK_PROJECTS[@]}"; do
    proj_dir="$PROJECTS_ROOT/$proj"
    mkdir -p "$proj_dir"
    cat > "$proj_dir/.mock" <<MOCK_EOF
# Mock project for RSI smoke test
project_name: $proj
created: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
MOCK_EOF
    echo "  ✅ 建 mock 專案：$proj_dir"
done

# 2. 為每個 mock 專案產 observation JSON
echo ""
echo "=== 產 observation ==="

# 雜湊 project 路徑 → project_id (SHA256[:8])
sha256_8() {
    local input="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 <<<"$input" | head -c 8
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum <<<"$input" | head -c 8
    else
        # fallback: 隨機 8 hex
        echo "$(printf '%08x' $((RANDOM * RANDOM)) )"
    fi
}

for proj in "${MOCK_PROJECTS[@]}"; do
    proj_dir="$PROJECTS_ROOT/$proj"
    project_id=$(sha256_8 "$proj_dir")
    obs_dir="$OBS_ROOT/$project_id"
    mkdir -p "$obs_dir"

    # 模擬 3 個專案不同的 gate 結果（test-proj-A 全 pass，B 有 lint fail，C 有 reviewer fail）
    case "$proj" in
        test-proj-A)
            gate_results='{"gate-1-tdd":"pass","gate-2-lint":"pass","gate-3-regression":"pass","gate-4-reviewer":"pass"}'
            failure_signals="[]"
            duration_seconds=145
            ;;
        test-proj-B)
            gate_results='{"gate-1-tdd":"pass","gate-2-lint":"fail","gate-3-regression":"pass","gate-4-reviewer":"pass"}'
            failure_signals='[{"gate":"gate-2-lint","type":"lint_warning","count":3}]'
            duration_seconds=178
            ;;
        test-proj-C)
            gate_results='{"gate-1-tdd":"pass","gate-2-lint":"pass","gate-3-regression":"pass","gate-4-reviewer":"fail"}'
            failure_signals='[{"gate":"gate-4-reviewer","type":"sop_violation","count":1}]'
            duration_seconds=223
            ;;
    esac

    # 隨機選 2-3 個 skill
    case "$proj" in
        test-proj-A) skills='["dav-planner","tdd-test-writer","regression-guard"]' ;;
        test-proj-B) skills='["tdd-test-writer","regression-guard"]' ;;
        test-proj-C) skills='["dav-planner","regression-guard","dev-checker-loop"]' ;;
    esac

    # 寫 observation JSON
    cat > "$obs_dir/$TODAY.json" <<OBS_EOF
{
  "task_id": "$(uuidgen 2>/dev/null || echo "task-$(date +%s)")",
  "project_id": "$project_id",
  "timestamp": "$(date -u '+%Y-%m-%dT%H:%M:%SZ')",
  "gate_results": $gate_results,
  "skills_used": $skills,
  "failure_signals": $failure_signals,
  "duration_seconds": $duration_seconds
}
OBS_EOF

    echo "  ✅ 寫 observation：$obs_dir/$TODAY.json"
done

echo ""
echo "=== 完成 ==="
echo "Mock 專案在：$PROJECTS_ROOT"
echo "Observations 在：$OBS_ROOT"
echo ""

if [[ "$CLEANUP" == "true" ]]; then
    echo "（會在 bats 跑完後清理，--keep 保留）"
fi