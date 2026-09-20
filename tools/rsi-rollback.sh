#!/usr/bin/env bash
# tools/rsi-rollback.sh — RSI 機制一鍵回滾 CLI
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §6.4
# 對應 Backlog US-014

set -uo pipefail

# === 預設值 ===
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TARGET="$REPO_ROOT"
LOG_FILE="$TARGET/docs/sop/rsi-log.md"
ASSUME_YES=false
TAG=""
MESSAGE=""
CMD=""

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-rollback.sh [COMMAND] [options]

回滾 RSI 機制的 SOP 改動到任一歷史版本。

Commands:
  list                       列出所有可回滾版本（rsi-v* tags）
  tag --message <msg>        寫一個新的 rsi-vYYYYMMDD-NN tag
  --target <tag>             回滾到指定 rsi-v 標籤
  --help / -h                顯示說明

Options:
  --target <path>            指定 repo 根目錄（預設當前 git repo）
  --message <msg> / -m <msg>  tag commit 訊息
  --yes / -y                 跳過互動確認

機制：
  - 每次 SOP 改動合併時自動寫 git tag：rsi-vYYYYMMDD-NN
  - 回滾用 git revert（保留變更歷史）+ 衝突時 fallback 到 git checkout
  - 回滾時間 < 5 秒
  - 觀察記錄不刪（~/.tree-monstor/observations/）

Example:
  ./tools/rsi-rollback.sh list
  ./tools/rsi-rollback.sh tag --message "fix: rsi rollback"
  ./tools/rsi-rollback.sh --target rsi-v20250920-01 --yes
EOF
}

# === 子命令：列出所有 rsi-v tags ===
cmd_list() {
    local target_repo="$TARGET"

    if ! git -C "$target_repo" rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ 錯誤：$target_repo 不是 git repo" >&2
        exit 1
    fi

    echo "=== 可回滾版本（rsi-v* tags）==="
    local tags
    tags=$(git -C "$target_repo" tag -l "rsi-v*" --sort=-creatordate 2>/dev/null)

    if [[ -z "$tags" ]]; then
        echo "（無）"
        echo ""
        echo "要寫 tag 的時機：每次合併 RSI 改動時自動寫。格式：rsi-vYYYYMMDD-NN"
        return 0
    fi

    local tag
    while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue
        local commit msg date
        commit=$(git -C "$target_repo" rev-parse --short "$tag" 2>/dev/null)
        msg=$(git -C "$target_repo" log -1 --format='%s' "$tag" 2>/dev/null)
        date=$(git -C "$target_repo" log -1 --format='%ai' "$tag" 2>/dev/null)
        echo "  $tag | $commit | $date | $msg"
    done <<< "$tags"

    echo ""
    echo "用法：$0 --target <tag>"
}

# === 子命令：回滾到指定 tag ===
cmd_rollback() {
    local target_repo="$TARGET"
    local target_tag="$TAG"

    if [[ -z "$target_tag" ]]; then
        echo "❌ 錯誤：--target <tag> 必填" >&2
        echo "先跑 '$0 list' 看有哪些可回滾版本" >&2
        exit 1
    fi

    # 確認 tag 存在
    if ! git -C "$target_repo" rev-parse --verify "$target_tag" >/dev/null 2>&1; then
        echo "❌ 錯誤：tag '$target_tag' 不存在" >&2
        echo "先跑 '$0 list' 看有哪些可回滾版本" >&2
        exit 1
    fi

    # 確認 tag 是 rsi-v* 開頭（避免誤回滾到任意 tag）
    if [[ ! "$target_tag" =~ ^rsi-v[0-9]{8}(-[0-9]+)?$ ]]; then
        echo "⚠️  警告：tag '$target_tag' 不是 rsi-v* 格式" >&2
        echo "RSI tag 格式：rsi-vYYYYMMDD-NN（如 rsi-v20250920-01）" >&2
        if [[ "$ASSUME_YES" != "true" ]]; then
            echo "（加 --yes 強制執行）"
            exit 1
        fi
    fi

    # 確認動作
    echo "=== 即將回滾 ==="
    echo "  Repo:   $target_repo"
    echo "  Tag:    $target_tag"
    echo "  Commit: $(git -C "$target_repo" rev-parse --short "$target_tag")"
    echo "  Message: $(git -C "$target_repo" log -1 --format='%s' "$target_tag")"
    echo ""

    if [[ "$ASSUME_YES" != "true" ]]; then
        read -rp "確認回滾？[y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "已取消"
            exit 0
        fi
    fi

    # 檢查 working tree 是否乾淨
    if ! git -C "$target_repo" diff --quiet HEAD 2>/dev/null; then
        echo "❌ 錯誤：working tree 有未提交的修改" >&2
        echo "請先 commit 或 stash：" >&2
        git -C "$target_repo" status --short >&2
        exit 1
    fi

    # 執行回滾（git revert -n + commit）
    echo "正在回滾..."
    if git -C "$target_repo" revert --no-edit "$target_tag" 2>/dev/null; then
        echo ""
        echo "✅ 回滾完成（git revert）"
    else
        echo "⚠️  git revert 衝突，改用 git checkout 強制 reset"
        echo "（這會丟失該 tag 之後的所有 commit，建議先備份）"
        if [[ "$ASSUME_YES" != "true" ]]; then
            read -rp "強制 checkout？[y/N] " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo "已取消"
                exit 0
            fi
        fi
        git -C "$target_repo" checkout "$target_tag" -- .
        echo ""
        echo "✅ 回滾完成（git checkout）"
    fi

    echo ""
    echo "現在的 HEAD："
    git -C "$target_repo" log -1 --format='  %h | %s | %ai'
    echo ""
    echo "如果要繼續往後走：git reset HEAD~1 取消 revert"
    echo "如果回滾後發現問題：git reset --hard $target_tag 直接回去"
}

# === 子命令：寫 tag ===
cmd_tag() {
    local target_repo="$TARGET"
    local message="${MESSAGE:-rsi update}"

    if ! git -C "$target_repo" rev-parse --git-dir >/dev/null 2>&1; then
        echo "❌ 錯誤：$target_repo 不是 git repo" >&2
        exit 1
    fi

    # 計算當天日期（YYYYMMDD）
    local date_prefix
    date_prefix=$(date +%Y%m%d)

    # 找當天現有最大序號
    local max_seq=0
    local existing_tags
    existing_tags=$(git -C "$target_repo" tag -l "rsi-v${date_prefix}-*" 2>/dev/null)
    local tag
    while IFS= read -r tag; do
        [[ -z "$tag" ]] && continue
        # 提取序號部分（最後 -NN）
        local seq="${tag##*-}"
        if [[ "$seq" =~ ^[0-9]+$ ]]; then
            seq=$((10#$seq))
            if (( seq > max_seq )); then
                max_seq=$seq
            fi
        fi
    done <<< "$existing_tags"

    local new_seq
    new_seq=$(printf "%02d" $((max_seq + 1)))
    local new_tag="rsi-v${date_prefix}-${new_seq}"

    # 寫 tag（annotated tag 含 message）
    if git -C "$target_repo" tag -a "$new_tag" -m "$message" 2>/dev/null; then
        echo "✅ 已寫 tag：$new_tag"
        echo "   訊息：$message"
        echo "   下一步：git push origin $new_tag（如需遠端同步）"
    else
        echo "❌ 寫 tag 失敗：$new_tag" >&2
        exit 1
    fi
}

# === 主程式：參數解析 ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        list)
            CMD="list"
            shift
            ;;
        tag)
            CMD="tag"
            shift
            ;;
        --target)
            # 判斷是 tag 還是 path：rsi-v 開頭就是 tag，否則是 path
            if [[ "$2" =~ ^rsi-v ]]; then
                TAG="$2"
            else
                TARGET="$2"
            fi
            shift 2
            ;;
        --message|-m)
            MESSAGE="$2"
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
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 1
            ;;
        *)
            # 第一個位置參數：可能是子命令或 tag
            if [[ "$1" =~ ^rsi-v ]]; then
                TAG="$1"
            elif [[ -z "$CMD" ]]; then
                CMD="$1"
            fi
            shift
            ;;
    esac
done

# === 執行 ===
if [[ "$CMD" == "list" ]]; then
    cmd_list
elif [[ "$CMD" == "tag" ]]; then
    cmd_tag
elif [[ -n "$TAG" ]]; then
    cmd_rollback
else
    usage
    exit 0
fi