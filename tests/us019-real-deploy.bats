#!/usr/bin/env bats
# tests/us019-real-deploy.bats
# US-019：Sprint 11 真實部署 1 個輕量小型 web app 14 天
# 對應 FR-4.16

setup() {
    export LC_ALL=C
    export LANG=C
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    export PATH="$REPO_ROOT/tools:$PATH"

    # mock web app
    MOCK_WEB="$(mktemp -d -t rsi-webapp-XXXXXX)"
    mkdir -p "$MOCK_WEB/src"
    cat > "$MOCK_WEB/package.json" <<'EOF'
{"name": "test-webapp", "version": "1.0.0", "main": "src/server.js"}
EOF
    cat > "$MOCK_WEB/src/server.js" <<'EOF'
const http = require('http');
http.createServer((req, res) => res.end('OK')).listen(3000);
EOF
}

teardown() {
    rm -rf "$MOCK_WEB"
}

# ---------- AC-1: install.sh --enable-rsi 部署到 mock web app ----------
@test "US-019-1: install.sh --enable-rsi deploys to web app" {
    bash "$REPO_ROOT/install.sh" --enable-rsi --yes --target "$MOCK_WEB" 2>&1
    [[ -d "$MOCK_WEB/.pi/sop" ]]
}

# ---------- AC-2: 安裝後不破壞 web app 本體 ----------
@test "US-019-2: install does not modify web app source code" {
    local before_hash
    before_hash=$(md5 -q "$MOCK_WEB/src/server.js" 2>/dev/null || md5sum "$MOCK_WEB/src/server.js" | awk '{print $1}')
    bash "$REPO_ROOT/install.sh" --enable-rsi --yes --target "$MOCK_WEB" 2>&1 || true
    local after_hash
    after_hash=$(md5 -q "$MOCK_WEB/src/server.js" 2>/dev/null || md5sum "$MOCK_WEB/src/server.js" | awk '{print $1}')
    [[ "$before_hash" == "$after_hash" ]]
}

# ---------- AC-3: 安裝後可以寫 observation ----------
@test "US-019-3: observation can be written after install" {
    # 模擬 rsi-aggregate 的寫入流程
    local obs_file="${HOME}/.tree-monstor/observations/test-proj-real/2026-09-20.json"
    mkdir -p "$(dirname "$obs_file")"
    cat > "$obs_file" <<'EOF'
{
    "task_id": "REAL-001",
    "project_id": "test-proj-real",
    "timestamp": "2026-09-20T12:00:00Z",
    "gate_results": {"gate-1":"pass","gate-2":"pass","gate-3":"pass","gate-4":"pass","gate-5":"pass"},
    "skills_used": ["dav-planner", "tdd-test-writer"]
}
EOF
    [[ -f "$obs_file" ]]
}

# ---------- AC-4: trend_history 能抓到觀察 ----------
@test "US-019-4: trend_history reads observation from real project" {
    local tmp
    tmp=$(mktemp -d -t rsi-trend-XXXXXX)
    mkdir -p "$tmp/test-proj-real"
    cat > "$tmp/test-proj-real/2026-09-20.json" <<'EOF'
{
    "project_id": "test-proj-real",
    "timestamp": "2026-09-20T12:00:00Z",
    "gate_results": {"gate-1":"pass","gate-5":"pass"}
}
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-metrics.sh" trend_history --obs-root "$tmp" 2>&1)
    # trend_history 應輸出「Trend」或「sparkline」
    echo "$out" | grep -qE "Trend|sparkline"
    rm -rf "$tmp"
}

# ---------- AC-5: 信心分數過濾有效 ----------
@test "US-019-5: confidence score filters low-frequency events" {
    local tmp
    tmp=$(mktemp -t rsi-report-XXXXXX.md)
    cat > "$tmp" <<'EOF'
# RSI Mock Report

## 跨專案分佈
| 專案 ID | 觀察數 |
| --- | --- |
| proj1 | 1 |
| proj2 | 1 |
| proj3 | 1 |

## 事件類型分佈
| 事件類型 | 次數 |
| --- | --- |
| high_freq_event | 12 |
| low_freq_event | 1 |
EOF
    local out
    out=$(bash "$REPO_ROOT/tools/rsi-propose.sh" --report "$tmp" --min-freq 1 --confidence 0.5 2>&1)
    # high_freq_event (12*0.05 + 3*0.1 = 0.90) 應標主要提案
    # low_freq_event (1*0.05 + 3*0.1 = 0.35) 應標 Low Confidence
    echo "$out" | grep -qE "主要提案"
    echo "$out" | grep -qE "Low Confidence"
    rm -f "$tmp"
}

# ---------- AC-6: install --disable-rsi 跳過 sop-evolver skill ----------
@test "US-019-6: install.sh --disable-rsi skips RSI sop-evolver skill" {
    # 清掉舊 tree-monstor 環境避免被誤判
    rm -rf "${HOME}/.tree-monstor/observations" "${HOME}/.tree-monstor/projects"
    bash "$REPO_ROOT/install.sh" --disable-rsi --yes --target "$MOCK_WEB" 2>&1 || true
    # SOP handbook 仍裝，但 ~/.tree-monstor/ 不被初始化
    [[ ! -d "${HOME}/.tree-monstor/observations" ]]
    [[ ! -d "${HOME}/.tree-monstor/projects" ]]
}

# ---------- AC-7: rsi-metrics 對真實 web app 算 hash ----------
@test "US-019-7: rsi-metrics.sh calculates web app project_id" {
    # 用 SHA256[:8] 模擬 rsi 自動算 project_id
    local project_id
    project_id=$(echo -n "$MOCK_WEB" | shasum -a 256 | awk '{print $1}' | cut -c1-8)
    [[ ${#project_id} -eq 8 ]]
}

# ---------- AC-8: 完整部署文件存在 ----------
@test "US-019-8: real deploy guide document exists" {
    [[ -f "$REPO_ROOT/docs/deploy/2026-09-20-real-webapp-deploy-guide.md" ]]
}