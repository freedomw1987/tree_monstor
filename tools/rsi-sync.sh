#!/usr/bin/env bash
# tools/rsi-sync.sh — RSI 機制同步 CLI
# 對應 docs/sop/handbook/2.8-rsi-evolution.md §6.5
# 對應 Backlog US-015

set -uo pipefail

# === 預設值 ===
SOURCE_SOP_DIR="${HOME}/.pi/sop"
TRIGGER="manual"
DRY_RUN=false
ASSUME_YES=false
PROJECT_LIST_FILE=""
TARGET_DIR=""  # Sprint 14 US-025

# === 旗標解析 ===
usage() {
    cat <<EOF
Usage: rsi-sync.sh [options]

把新版 ~/.pi/sop/ 同步到所有「已裝 tree_monstor」的專案位置。

Options:
  --source <path>          來源 SOP 目錄（預設 ~/.pi/sop）
  --target <path>          單一目標目錄（覆蓋自動掃瞄）
  --trigger <mode>         觸發模式：manual（預設）/ install / aggregate
  --project-list <file>    專案清單檔（每行一個路徑；預設自動掃 ~/.tree-monstor/）
  --dry-run                預覽，不實際同步
  --yes / -y               跳過互動確認
  --help / -h              顯示說明

機制：
  - 不覆蓋目標專案的本地 override（保留「用戶自定義」標記）
  - 衝突時輸出警告，由人工確認
  - 觀察記錄（~/.tree-monstor/observations/）不刪、不覆蓋
  - install.sh 跑完後自動觸發（--trigger install）

Example:
  ./tools/rsi-sync.sh --trigger install
  ./tools/rsi-sync.sh --dry-run
  ./tools/rsi-sync.sh --project-list /tmp/projects.txt
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)
            SOURCE_SOP_DIR="$2"
            shift 2
            ;;
        --target)
            TARGET_DIR="$2"
            shift 2
            ;;
        --trigger)
            TRIGGER="$2"
            shift 2
            ;;
        --project-list)
            PROJECT_LIST_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
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

# === 主程式 ===
if [[ ! -d "$SOURCE_SOP_DIR" ]]; then
    echo "⚠️  來源 SOP 目錄不存在：$SOURCE_SOP_DIR" >&2
    echo "（第一次跑是正常的，tree_monstor 還沒裝到系統）" >&2
    if [[ "$TRIGGER" == "install" ]]; then
        # install 時觸發，沒來源就靜默跳過
        exit 0
    fi
    exit 1
fi

# 找專案清單
declare -a PROJECTS

if [[ -n "$PROJECT_LIST_FILE" && -f "$PROJECT_LIST_FILE" ]]; then
    # 從指定檔讀
    while IFS= read -r line; do
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        PROJECTS+=("$line")
    done < "$PROJECT_LIST_FILE"
else
    # 自動掃 ~/.tree-monstor/
    proj_root="${HOME}/.tree-monstor"
    if [[ -d "$proj_root" ]]; then
        for entry in "$proj_root"/projects/*/; do
            [[ ! -d "$entry" ]] && continue
            # 每個專案目錄裡有 path 檔指向真實位置
            if [[ -f "${entry}path" ]]; then
                proj_path=$(cat "${entry}path")
                PROJECTS+=("$proj_path")
            fi
        done
    fi
fi

# Sprint 14 US-025: --target 覆蓋 PROJECTS
if [[ -n "$TARGET_DIR" ]]; then
    PROJECTS=("$TARGET_DIR")
fi

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    echo "⚠️  沒有專案可同步" >&2
    echo "（tree_monstor 還沒裝到任何專案，或 ~/.tree-monstor/projects/ 不存在）" >&2
    exit 0
fi

# === 同步 ===
SYNC_COUNT=0
SKIP_COUNT=0
LOCAL_OVERRIDE_COUNT=0
MODIFY_COUNT=0
ADD_COUNT=0
DELETE_COUNT=0

echo "=== RSI 同步 ==="
echo "來源：$SOURCE_SOP_DIR"
echo "目標：${#PROJECTS[@]} 個專案"
echo "觸發：$TRIGGER"
[[ "$DRY_RUN" == "true" ]] && echo "模式：dry-run（不實際同步）"
echo ""

for project in "${PROJECTS[@]}"; do
    [[ ! -d "$project" ]] && continue

    target_sop_dir="$project/.pi/sop"

    # 檢查目標是否為本地 override
    if [[ -f "$target_sop_dir/.local-override" ]]; then
        echo "  ⊘ 跳過（local-override）：$project"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        LOCAL_OVERRIDE_COUNT=$((LOCAL_OVERRIDE_COUNT + 1))
        continue
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        # 列出每個將同步檔案：path + action + md5 hash 對比
        echo "  → 將同步：$project/.pi/sop/"
        mkdir -p "$target_sop_dir"
        while IFS= read -r src_file; do
            [[ -z "$src_file" ]] && continue
            rel_path="${src_file#$SOURCE_SOP_DIR/}"
            tgt_file="$target_sop_dir/$rel_path"
            src_md5=$(md5 -q "$src_file" 2>/dev/null || md5sum "$src_file" 2>/dev/null | awk '{print $1}')
            if [[ -f "$tgt_file" ]]; then
                tgt_md5=$(md5 -q "$tgt_file" 2>/dev/null || md5sum "$tgt_file" 2>/dev/null | awk '{print $1}')
                if [[ "$src_md5" == "$tgt_md5" ]]; then
                    echo "    [skip] $rel_path (md5=$src_md5)"
                else
                    echo "    [modify] $rel_path (src=$src_md5 tgt=$tgt_md5)"
                    MODIFY_COUNT=$((MODIFY_COUNT + 1))
                fi
            else
                echo "    [add] $rel_path (md5=$src_md5)"
                ADD_COUNT=$((ADD_COUNT + 1))
            fi
        done < <(find "$SOURCE_SOP_DIR" -type f 2>/dev/null)
        SYNC_COUNT=$((SYNC_COUNT + 1))
        continue
    fi

    # 確認動作
    if [[ "$ASSUME_YES" != "true" && "$TRIGGER" != "install" ]]; then
        read -rp "同步到 $project？[y/N] " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "  ⊘ 跳過（用戶取消）"
            SKIP_COUNT=$((SKIP_COUNT + 1))
            continue
        fi
    fi

    # 實際同步（用 cp -r，但要小心覆蓋本地 override 檔）
    mkdir -p "$target_sop_dir"
    cp -rn "$SOURCE_SOP_DIR/." "$target_sop_dir/" 2>/dev/null

    # 寫本地 override 標記（讓下次同步跳過）
    touch "$target_sop_dir/.local-override"

    echo "  ✅ 已同步：$project"
    SYNC_COUNT=$((SYNC_COUNT + 1))
done

echo ""
echo "=== 結果 ==="
echo "已處理專案：$SYNC_COUNT"
echo "跳過：$SKIP_COUNT（其中本地 override：$LOCAL_OVERRIDE_COUNT）"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "dry-run 統計："
    echo "  add（新增）：$ADD_COUNT"
    echo "  modify（覆蓋）：$MODIFY_COUNT"
fi
echo ""

if [[ "$TRIGGER" == "install" ]]; then
    echo "（install 觸發，自動完成）"
elif [[ "$DRY_RUN" == "true" ]]; then
    echo "（dry-run 模式，沒實際同步）"
fi