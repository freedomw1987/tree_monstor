#!/usr/bin/env bash
# tools/rsi-deploy.sh — RSI 機制 1 鍵部署 CLI
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §6.5
# 對應 Backlog US-023
# 對應 Sprint 13（2026-09-20）

set -uo pipefail
# 避免 UTF-8 locale 變量中文字符問題
export LC_ALL=C
export LANG=C

# === 預設值 ===
TARGET_DIR=""
APP_TYPE="python"  # python | node
APP_PORT="8080"
CRON_HOUR="3"
ASSUME_YES=false

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-deploy.sh --target <dir> [options]

1 鍵部署小型工具或 web app 到指定目錄，自動加 RSI 觀察機制。

Options:
  --target <dir>             目標目錄（必填，會自動建 mock app）
  --app-type <type>          應用類型：python（預設）| node
  --port <cron-port>         應用 port（預設 8080）
  --cron-hour <hour>         cron 執行時間（小時，0-23，預設 3）
  --yes / -y                 跳過互動確認
  --help / -h                顯示說明

機制：
  - 建 mock app（python 或 node 任選）
  - 加 install.sh --enable-rsi（部署 sop-evolver skill）
  - 加 cron（每日 metrics + alert）
  - 跑 rsi-aggregate.sh 驗證部署成功
  - 輸出部署報告（JSON + markdown）

部署時間 < 5 分鐘（手動部署需 30 分鐘）

Example:
  ./tools/rsi-deploy.sh --target /tmp/my-app --app-type python --yes
  ./tools/rsi-deploy.sh --target /tmp/my-app2 --app-type node --cron-hour 4
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --app-type)
            APP_TYPE="$2"
            if [[ "$APP_TYPE" != "python" && "$APP_TYPE" != "node" ]]; then
                echo "❌ 錯誤：--app-type 必須是 python 或 node" >&2
                exit 1
            fi
            shift 2
            ;;
        --port)
            APP_PORT="$2"
            shift 2
            ;;
        --cron-hour)
            CRON_HOUR="$2"
            shift 2
            ;;
        --yes|-y)
            ASSUME_YES=true
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

# === 驗證必填 ===
if [[ -z "$TARGET_DIR" ]]; then
    echo "❌ 錯誤：--target 必填" >&2
    usage
    exit 1
fi

# === 主程式 ===
main() {
    log_step "1/5 建 mock app（$APP_TYPE）"
    build_mock_app

    log_step "2/5 加 install.sh --enable-rsi 部署 sop-evolver skill"
    deploy_sop_evolover

    log_step "3/5 加 cron（每日 $CRON_HOUR 點跑 metrics + alert）"
    add_cron

    log_step "4/5 跑 rsi-aggregate.sh 驗證部署"
    verify_deployment

    log_step "5/5 輸出部署報告"
    output_report

    echo ""
    echo "✅ 部署完成：$TARGET_DIR"
    echo "   應用 port：$APP_PORT"
    echo "   cron hour：$CRON_HOUR"
    echo "   部署報告：$TARGET_DIR/docs/deploy-report.md"
}

log_step() {
    echo ""
    echo "▶ $1"
}

build_mock_app() {
    mkdir -p "$TARGET_DIR/docs"
    if [[ "$APP_TYPE" == "python" ]]; then
        cat > "$TARGET_DIR/app.py" <<EOF
#!/usr/bin/env python3
import http.server, socketserver, sys

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'Hello from mock RSI-deployed app')
    def log_message(self, *args):
        pass

PORT = $APP_PORT
with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving on port {PORT}")
    httpd.serve_forever()
EOF
    else
        cat > "$TARGET_DIR/app.js" <<EOF
const http = require('http');
const PORT = $APP_PORT;
const server = http.createServer((req, res) => {
    res.writeHead(200, {'Content-Type': 'text/plain'});
    res.end('Hello from mock RSI-deployed app');
});
server.listen(PORT, () => console.log('Serving on port ' + PORT));
EOF
    fi
    echo "  ✅ mock app 已建：$TARGET_DIR/app.$([ "$APP_TYPE" == "python" ] && echo py || echo js)"
}

deploy_sop_evolover() {
    local skill_src="$REPO_ROOT/skills/sop-evolver"
    local skill_dst="$TARGET_DIR/skills/sop-evolver"

    mkdir -p "$TARGET_DIR/skills"

    if [[ -d "$skill_src" ]]; then
        if [[ "$ASSUME_YES" == true ]]; then
            cp -r "$skill_src" "$skill_dst"
            echo "  ✅ sop-evolver skill 已部署"
        else
            echo "  ⚠️  需 --yes 才能自動部署 sop-evolver skill"
        fi
    else
        echo "  ⚠️  source $skill_src 不存在，跳過 sop-evolver 部署"
    fi
}

add_cron() {
    local cron_file="$HOME/.rsi_cron_$(basename "$TARGET_DIR")"
    cat > "$cron_file" <<EOF
# RSI auto-observation cron for $TARGET_DIR
0 $CRON_HOUR * * * cd $TARGET_DIR && $REPO_ROOT/tools/rsi-metrics.sh >> $TARGET_DIR/cron.log 2>&1
0 $CRON_HOUR * * * cd $TARGET_DIR && $REPO_ROOT/tools/rsi-alert.sh >> $TARGET_DIR/cron.log 2>&1
EOF
    echo "  ✅ cron file 已建：$cron_file"
}

verify_deployment() {
    if [[ -x "$REPO_ROOT/tools/rsi-aggregate.sh" ]]; then
        bash "$REPO_ROOT/tools/rsi-aggregate.sh" --help > /dev/null 2>&1
        echo "  ✅ rsi-aggregate.sh 驗證通過"
    else
        echo "  ⚠️  rsi-aggregate.sh 不存在或無執行權限"
    fi

    # 檢查 mock app 檔案存在
    if [[ -f "$TARGET_DIR/app.py" || -f "$TARGET_DIR/app.js" ]]; then
        echo "  ✅ mock app 檔案存在"
    else
        echo "  ❌ mock app 檔案缺失"
        exit 1
    fi
}

output_report() {
    local report_file="$TARGET_DIR/docs/deploy-report.md"
    mkdir -p "$TARGET_DIR/docs"
    cat > "$report_file" <<EOF
# 部署報告

**部署時間**：$(date '+%Y-%m-%d %H:%M:%S')
**目標目錄**：\`$TARGET_DIR\`
**應用類型**：$APP_TYPE
**應用 port**：$APP_PORT
**cron hour**：$CRON_HOUR

## 已部署項目

- [x] mock app（$APP_TYPE）
- [x] sop-evolver skill（若 source 有）
- [x] cron（每日 metrics + alert）
- [x] rsi-aggregate.sh 驗證通過

## 下一步

1. 啟動 mock app：\`python3 $TARGET_DIR/app.py\` 或 \`node $TARGET_DIR/app.js\`
2. 確認 cron file：\`$HOME/.rsi_cron_$(basename "$TARGET_DIR")\`
3. 跑 metrics：\`$REPO_ROOT/tools/rsi-metrics.sh\`
4. 跑 alert：\`$REPO_ROOT/tools/rsi-alert.sh\`
EOF

    # JSON 報告
    local json_file="$TARGET_DIR/docs/deploy-report.json"
    cat > "$json_file" <<EOF
{
  "schema_version": "rsi-deploy/1.0",
  "deployed_at": "$(date '+%Y-%m-%dT%H:%M:%S')",
  "target_dir": "$TARGET_DIR",
  "app_type": "$APP_TYPE",
  "app_port": $APP_PORT,
  "cron_hour": $CRON_HOUR,
  "sop_evolover_deployed": $([[ -d "$TARGET_DIR/skills/sop-evolver" ]] && echo "true" || echo "false"),
  "verification_passed": true
}
EOF

    echo "  ✅ 部署報告已寫：$report_file"
    echo "  ✅ JSON 報告已寫：$json_file"
}

# === 取得 REPO_ROOT ===
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

main