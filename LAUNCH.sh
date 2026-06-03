#!/usr/bin/env bash
# Tree Monstor — Developer Profile 啟動腳本
# macOS + Hermes 0.15.1+ 友善
#
# 用法:
#   ./LAUNCH.sh                  # 啟動 developer profile
#   ./LAUNCH.sh chat -q "你好"     # 單次查詢模式
#   ./LAUNCH.sh gateway run       # 跑 gateway(背景跑 Discord bot)
#   ./LAUNCH.sh profile show      # 看目前 profile 狀態
#
# 不傳任何參數時,預設進入 chat 互動模式

set -euo pipefail

# 找 hermes CLI(支援幾個常見位置)
HERMES_BIN=""
for path in \
    ~/.hermes/hermes-agent/venv/bin/hermes \
    ~/.local/bin/hermes \
    /usr/local/bin/hermes \
    $(command -v hermes 2>/dev/null || true); do
    if [ -x "$path" ]; then
        HERMES_BIN="$path"
        break
    fi
done

if [ -z "$HERMES_BIN" ]; then
    echo "❌ 找不到 hermes CLI。請先安裝:"
    echo "   curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"
    exit 1
fi

# 確認 developer profile 存在
PROFILE_DIR="$HOME/.hermes/profiles/developer"
if [ ! -d "$PROFILE_DIR" ]; then
    echo "❌ 找不到 developer profile: $PROFILE_DIR"
    echo "   請先 git clone:"
    echo "   git clone git@github.com:freedomw1987/tree_monstor.git $PROFILE_DIR"
    exit 1
fi

# 確認 .env 已填(沒填會 warn 但不擋)
if [ ! -f "$PROFILE_DIR/.env" ]; then
    echo "⚠️  找不到 $PROFILE_DIR/.env"
    echo "   請執行: cp $PROFILE_DIR/adapters/hermes/.env.template $PROFILE_DIR/.env"
    echo "   然後 nano $PROFILE_DIR/.env 把 token 填好"
    read -p "   還是要繼續啟動?(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 確認 SOUL.md 在(這是 Tree Monstor 的身份)
if [ ! -f "$PROFILE_DIR/SOUL.md" ]; then
    echo "❌ 找不到 $PROFILE_DIR/SOUL.md — Tree Monstor 身份檔不見了"
    echo "   請重新 clone profile"
    exit 1
fi

# 顯示啟動資訊
echo "🌳 Tree Monstor Developer Profile"
echo "   Profile dir: $PROFILE_DIR"
echo "   Hermes bin:  $HERMES_BIN"
echo "   SOUL.md:     $(wc -c < $PROFILE_DIR/SOUL.md | tr -d ' ') bytes"
echo ""

# 啟動(把 developer 之前的命令列參數原封不動傳給 hermes)
exec "$HERMES_BIN" --profile developer "$@"
