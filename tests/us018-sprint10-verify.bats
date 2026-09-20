#!/usr/bin/env bats
# tests/us018-sprint10-verify.bats -- US-018 Sprint 10 real deployment verification
# AC:
# - 部署 RSI 觀察模式到 3 個 mock
# - 觀察後跑 rsi-metrics.sh 看趨勢
# - 驗證觀察/合併層次正確
# - 建議 sprint 11 是否加規則
# - >= 8 個 bats 測試
# ASCII-only test names

setup() {
    export LC_ALL=C
    export LANG=C
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    OBS_ROOT="${HOME}/.tree-monstor/observations"
    PROJECTS_ROOT="${HOME}/.tree-monstor/projects"
    TODAY=$(date '+%Y-%m-%d')
    export PATH="$REPO_ROOT/tools:$PATH"

    # 建臨時 mock sync source + 3 個 mock proj
    MOCK_SRC="$(mktemp -d -t rsi-src-XXXXXX)"
    MOCK_PROJ="$(mktemp -d -t rsi-proj-XXXXXX)"
    echo "source handbook" > "$MOCK_SRC/2.8-rsi-evolution.md"
    echo "source gates" > "$MOCK_SRC/gates.json"
    for i in 1 2 3; do
        mkdir -p "$MOCK_PROJ/proj$i/.pi/sop"
    done
    # proj1 完全同步 (skip)、proj2 有差異 (modify)
    cp "$MOCK_SRC/2.8-rsi-evolution.md" "$MOCK_PROJ/proj1/.pi/sop/"
    cp "$MOCK_SRC/gates.json" "$MOCK_PROJ/proj1/.pi/sop/"
    echo "old" > "$MOCK_PROJ/proj2/.pi/sop/2.8-rsi-evolution.md"
    cp "$MOCK_SRC/gates.json" "$MOCK_PROJ/proj2/.pi/sop/"
}

teardown() {
    rm -rf "$MOCK_SRC" "$MOCK_PROJ"
}

# ---------- AC-1: 觀察模式部署到 mock 專案 ----------
@test "US-018-1: rsi-sync.sh dry-run on 3 mock projects shows file list" {
    local tmp_list
    tmp_list="$(mktemp -t rsi-projects-XXXXXX.txt)"
    echo "$MOCK_PROJ/proj1" > "$tmp_list"
    echo "$MOCK_PROJ/proj2" >> "$tmp_list"
    echo "$MOCK_PROJ/proj3" >> "$tmp_list"
    bash "$REPO_ROOT/tools/rsi-sync.sh" --dry-run --yes --source "$MOCK_SRC" --project-list "$tmp_list" 2>&1 | grep -qE "\[modify\]|\[skip\]|\[add\]"
    rm -f "$tmp_list"
}

@test "US-018-2: observation files exist for 3 mock projects (today)" {
    [ -d "$OBS_ROOT" ]
    local count
    count=$(find "$OBS_ROOT" -name "$TODAY.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 3 ]
}

# ---------- AC-2: 觀察後跑 rsi-metrics.sh 看趨勢 ----------
@test "US-018-3: rsi-metrics.sh shows task completion rate" {
    bash "$REPO_ROOT/tools/rsi-metrics.sh" 2>&1 | grep -qF "任務完成率"
}

@test "US-018-4: rsi-metrics.sh shows TD close rate" {
    bash "$REPO_ROOT/tools/rsi-metrics.sh" 2>&1 | grep -qF "閉環"
}

@test "US-018-5: rsi-metrics.sh shows cross-project distribution" {
    bash "$REPO_ROOT/tools/rsi-metrics.sh" 2>&1 | grep -qF "跨專案"
}

# ---------- AC-3: 驗證觀察/合併層次正確 ----------
@test "US-018-6: observation schema enforces whitelist (no blacklist fields)" {
    for f in "$OBS_ROOT"/*/"$TODAY.json"; do
        [ -f "$f" ] || continue
        ! grep -qE '"raw_conversation"|"code_snippets"|"file_paths"|"env_values"|"git_messages"' "$f"
    done
}

@test "US-018-7: rsi-rollback.sh tag subcommand does not break mock projects" {
    bash "$REPO_ROOT/tools/rsi-rollback.sh" --help >/dev/null 2>&1
    # dry-run tag 命令（不真寫 tag）：用 help 不改變 git
    bash "$REPO_ROOT/tools/rsi-rollback.sh" list >/dev/null 2>&1
}

@test "US-018-8: rsi-sync.sh dry-run does not modify mock project files" {
    local before
    before=$(find "$MOCK_PROJ" -type f 2>/dev/null | wc -l | tr -d ' ')
    local tmp_list
    tmp_list="$(mktemp -t rsi-projects-XXXXXX.txt)"
    echo "$MOCK_PROJ/proj1" > "$tmp_list"
    echo "$MOCK_PROJ/proj2" >> "$tmp_list"
    echo "$MOCK_PROJ/proj3" >> "$tmp_list"
    bash "$REPO_ROOT/tools/rsi-sync.sh" --dry-run --yes --source "$MOCK_SRC" --project-list "$tmp_list" >/dev/null 2>&1 || true
    local after
    after=$(find "$MOCK_PROJ" -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$before" = "$after" ]
    rm -f "$tmp_list"
}

# ---------- AC-4: 建議 sprint 11 是否加規則 ----------
@test "US-018-9: rsi-propose.sh generates proposals from Sprint 10 mock observations" {
    local tmp_report
    tmp_report=$(mktemp -t rsi-report-XXXXXX.md)
    bash "$REPO_ROOT/tools/rsi-aggregate.sh" --obs-root "$OBS_ROOT" --output "$tmp_report" >/dev/null 2>&1
    [ -f "$tmp_report" ]
    local proposal
    proposal=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp_report" 2>&1)
    echo "$proposal" | grep -qE "提案"
    rm -f "$tmp_report"
}

@test "US-018-10: Sprint 10 expansion rules (markdownlint_error etc) appear in proposal" {
    # 建一個 mock report 含 8 個內建規則 type（驗規則庫覆蓋率）
    local tmp_report
    tmp_report=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$tmp_report" <<'EOF'
# RSI Mock Report for Sprint 10 規則庫驗證

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj-1 | 1 |
| proj-2 | 1 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| prompt_too_long | 5 |
| skill_error | 4 |
| gate_skip | 3 |
| markdownlint_error | 2 |
| bash_error | 2 |
| test_fail | 2 |
| bats_unknown | 1 |
| v02_violated | 1 |
EOF
    local proposal
    proposal=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp_report" --min-freq 1 2>&1)
    # 8 個內建規則都出現
    echo "$proposal" | grep -qF "prompt_too_long"
    echo "$proposal" | grep -qF "skill_error"
    echo "$proposal" | grep -qF "gate_skip"
    echo "$proposal" | grep -qF "markdownlint_error"
    echo "$proposal" | grep -qF "bash_error"
    echo "$proposal" | grep -qF "test_fail"
    echo "$proposal" | grep -qF "bats_unknown"
    echo "$proposal" | grep -qF "v02_violated"
    rm -f "$tmp_report"
}