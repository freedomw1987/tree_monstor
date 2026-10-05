#!/usr/bin/env bash
# tools/wiki-media-describe.sh — Sprint 08 FR-2.6.2 dav-wiki 多模組 AI 描述
# 對應 docs/prd/03-knowledge-extraction.md FR-3 / docs/plan/2026-01-15-dav-wiki-sprint-08.md

set -uo pipefail

# === 預設值 ===
MODE=""
INPUT=""
INPUT_DIR=""
OUTPUT_JSON=""
OUTPUT_DIR=""
API_KEY=""
MOCK=false
DRY_RUN=false
# TMO-060：本旗標=「單次批次最多**嘗試**處理幾檔」，不是並發度（實作是逐檔同步）。
# 舊名 --max-concurrency 會誤導成平行度，故正名 --batch-limit；舊名保留為等價別名。
# 0＝無限制（新預設；舊預設 4 會讓任何 >4 檔的批次靜默丟檔，是真 bug）。
BATCH_LIMIT=0
LIMIT_FLAG="--batch-limit"   # 只在此處與旗標解析處設定（勿在別處寫死旗標名）
LANGUAGE="auto"

# === 環境變數支援 ===
if [[ "${DAV_WIKI_MOCK:-}" == "1" ]]; then
    MOCK=true
fi
API_KEY="${API_KEY:-${OPENAI_API_KEY:-}}"

# === 副檔名白名單（單一來源，reviewer P2-6）===
# describe 只吃圖片、transcript 只吃音訊/影片；批次（process_batch）與單檔白名單共用這份。
# ⚠️ 合約邊界：`.webm` / `.flac` / `.tiff` 從未在本檔白名單內（單檔模式一直會發 WARN），
#    故批次也只略過不處理；若產品要支援，請同時改這裡與 usage 說明。
IMAGE_EXTS="png|jpg|jpeg|gif|webp"
AUDIO_EXTS="mp3|wav|m4a|mp4|mov|mkv"

# === 錯誤碼 ===
EXIT_OK=0
EXIT_USAGE=1
EXIT_NOINPUT=2
EXIT_BADMODE=3
# TMO-058：real 模式（Vision / Whisper API）尚未實作。
# 原本借用「錯誤碼 4（必要工具缺失）」→ 語意錯：本檔根本沒有工具檢查，
# 且 SKILL.md 已明說「不要期待安裝提示」。改用獨立碼，讓 caller 能分辨
# 「未實作」vs「缺工具」（其他腳本的 4 不受影響）。
# 注意：5 在本檔是「未實作」，`wiki-extract-media.sh` 的 5 是 `EXIT_EXTRACT`（抽不到產物）
# ——同號不同義（本檔沒有 skill 級 exit code 總表，故在此就地聲明，勿跨腳本比對 rc）。
EXIT_NOTIMPL=5
# 輸出寫入失敗（mkdir 不出來 / 產物寫不下去）。TMO-058 順修：原版這些路徑完全不看 rc。
EXIT_WRITE=6

# === 使用說明 ===
usage() {
    cat <<EOF
Usage: wiki-media-describe.sh --mode <describe|transcript> [options]

呼叫 Vision / Whisper API 生成圖片描述或音訊/影片轉錄。

Modes:
  describe       圖片描述（Vision API）
  transcript     音訊/影片轉錄（Whisper API）

Options:
  --input <file>           單一輸入檔案
  --input-dir <dir>        批次處理目錄
  --output-json <file>     describe mode 單檔輸出 JSON 路徑
  --output-dir <dir>       batch mode 輸出目錄
  --mock                   強制 mock 模式（不連真實 API）
  --api-key <key>          API key（也可從 OPENAI_API_KEY 環境變數讀）
  --language <zh|en|auto>  語言（預設 auto）
  --batch-limit <N>        單次批次最多嘗試處理 N 檔（0＝無限制、預設 0；不得有前導零）
  --max-concurrency <N>    同上（歷史名稱，不是並發度，僅為相容別名）
  --dry-run                只印計畫不執行
  --help / -h              顯示說明

注：--batch-limit / --max-concurrency 算的是「嘗試處理」的檔數
（失敗的檔也佔額度；0＝無限制）。

Output JSON (describe):
  { "mode": "describe", "source": "<file>", "caption": "...",
    "alt_text": "...", "extracted_at": "ISO 8601", "mock": true/false }

Output JSON (transcript):
  { "mode": "transcript", "source": "<file>", "text": "...",
    "duration": <seconds>, "language": "zh", "extracted_at": "..." }

Exit codes:
  0  成功
  1  用法錯誤
  2  輸入檔案 / 目錄不存在
  3  不支援的 mode
  5  未實作（real 模式：Vision / Whisper API 尚未接上）
  6  輸出寫入失敗（無法建立輸出目錄 / 寫不進產物）

注：real 模式失敗**不會**回 0（TMO-058：原本零產出卻回報成功）。
     本機測試請用 mock：加 --mock 或設 DAV_WIKI_MOCK=1。

對應手冊: docs/prd/03-knowledge-extraction.md (FR-3.4 / FR-3.7)
EOF
}

# === Mock 描述生成 ===
mock_describe() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    local color="colored image"
    case "$basename" in
        red*)   color="red square diagram" ;;
        blue*)  color="blue square diagram" ;;
        *)      color="generic image" ;;
    esac
    cat <<EOF
{
  "mode": "describe",
  "source": "$file",
  "caption": "[MOCK] A $color used for testing the dav-wiki pipeline",
  "alt_text": "[MOCK] $color",
  "model": "mock-vision-v1",
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mock": true
}
EOF
}

# === Mock 轉錄 ===
mock_transcribe() {
    local file="$1"
    local duration
    if command -v ffprobe &>/dev/null; then
        duration=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$file" 2>/dev/null || echo "0")
    else
        duration="0"
    fi
    cat <<EOF
{
  "mode": "transcript",
  "source": "$file",
  "text": "[MOCK] This is a placeholder transcript for $file",
  "duration": $duration,
  "language": "$LANGUAGE",
  "model": "mock-whisper-v1",
  "extracted_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "mock": true
}
EOF
}

# === Real API describe（未實作，留 TODO） ===
real_describe() {
    local file="$1"
    echo "ERROR: real Vision API not implemented yet" >&2
    echo "  set DAV_WIKI_MOCK=1 or pass --mock for testing" >&2
    return "$EXIT_NOTIMPL"
}

# === Real API transcript（未實作，留 TODO） ===
real_transcribe() {
    local file="$1"
    echo "ERROR: real Whisper API not implemented yet" >&2
    echo "  set DAV_WIKI_MOCK=1 or pass --mock for testing" >&2
    return "$EXIT_NOTIMPL"
}

# === 處理單檔 ===
process_single() {
    local file="$1"
    local output="$2"

    if [[ ! -f "$file" ]]; then
        echo "ERROR: input '$file' does not exist" >&2
        return 2
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] Would process: mode=$MODE file=$file output=$output"
        return 0
    fi

    local result
    local rc=0
    if [[ "$MOCK" == true ]]; then
        case "$MODE" in
            describe)   result=$(mock_describe "$file") ;;
            transcript) result=$(mock_transcribe "$file") ;;
        esac
    else
        case "$MODE" in
            describe)   real_describe "$file" || rc=$? ;;
            transcript) real_transcribe "$file" || rc=$? ;;
        esac
        # 失敗就不准再往前（尤其不准寫任何產出）
        if [[ $rc -ne 0 ]]; then
            echo "ERROR: 未產生任何輸出（${file}）" >&2
            return "$rc"
        fi
    fi

    if [[ -n "$output" ]]; then
        # TMO-058 順修（已揭露）：原版 `echo > "$output"` 不看 rc，寫入失敗（目錄不可寫、
        # 路徑被佔成目錄、磁碟滿）照樣印 `✓ wrote` 並回 0 → 同一家族「零產出卻假成功」。
        if ! echo "$result" > "$output"; then
            echo "ERROR: 寫入輸出失敗（${output}）" >&2
            return "$EXIT_WRITE"
        fi
        echo "  ✓ wrote: $output"
    else
        echo "$result"
    fi
}

# === 批次處理 ===
process_batch() {
    local dir="$1"
    local outdir="$2"

    if [[ ! -d "$dir" ]]; then
        echo "ERROR: input-dir '$dir' does not exist" >&2
        return 2
    fi

    mkdir -p "$outdir" || {
        echo "ERROR: 無法建立 output-dir（${outdir}）" >&2
        return "$EXIT_WRITE"
    }
    # TMO-058：原版 `count` 只數成功、失敗 `continue` 後照樣印「✅ 批次完成」
    # → 全部失敗也會回報成功。改成 ok / fail / truncated 三個計數 + 聚合 rc。
    local ok=0
    local fail=0
    local truncated=0
    local skipped_ext=0
    local attempted=0
    local first_err=0

    # 依 mode 決定接受哪些副檔名。
    # 2026-10-05 TMO-043：原 `ext_pattern` 算完從未使用（shellcheck SC2034），
    # `find` 反而寫死「圖片 + 音訊/影片」全部副檔名 → describe 模式會誤吃 .wav/.mp4，
    # transcript 模式會誤吃 .png（真 bug，見 AC-D17/AC-D18）。
    local ext_pattern=""
    case "$MODE" in
        describe)   ext_pattern="$IMAGE_EXTS" ;;
        transcript) ext_pattern="$AUDIO_EXTS" ;;
        *)
            echo "ERROR: unsupported --mode '$MODE' for --input-dir" >&2
            return 3
            ;;
    esac

    # TMO-060：不再靠 `find -iname` 過濾，改成掃全部檔再自行判白名單——
    # 這樣才「數得到」不符白名單而被略過的檔（原本批次是靜默略過）。
    # 點開頭**且不符白名單**的檔名（.DS_Store 等）不計不報，避免噪音。
    while IFS= read -r -d '' file; do
        local base
        base=$(basename "$file")
        # P1-1：必須 case-insensitive（舊版用 `find -iname`，IMG_001.JPG 會被處理）；
        # 用 `grep -qiE`（bash 3.2 安全，勿用 ${var,,}）。
        if ! printf '%s\n' "${file##*.}" | grep -qiE "^(${ext_pattern})$"; then
            # P2-1：只有「隱藏**且**不符白名單」才不計不報（.DS_Store 等）；隱藏但符合
            # 白名單的檔（如 .cover.png）仍要處理——否則就是本票在修的「靜默丟檔」。
            case "$base" in
                .*) continue ;;
            esac
            skipped_ext=$((skipped_ext + 1))
            continue
        fi
        # TMO-060：上限是「處理額度」不是「成功額度」——失敗檔也佔額度
        # （舊版以成功數計，`--max-concurrency 1` 遇失敗時實際會處理 2 檔）。
        # 達上限仍**要數**：原版 `break` 直接靜默丟掉剩下的檔（訊息卻說「批次完成」）。
        if [[ $BATCH_LIMIT -gt 0 && $attempted -ge $BATCH_LIMIT ]]; then
            truncated=$((truncated + 1))
            continue
        fi
        attempted=$((attempted + 1))
        local name
        name=$(basename "${file%.*}")
        local output="$outdir/$name.desc.json"
        local rc=0
        process_single "$file" "$output" || rc=$?
        if [[ $rc -ne 0 ]]; then
            echo "  ⚠ skipped: $file" >&2
            fail=$((fail + 1))
            if [[ $first_err -eq 0 ]]; then
                first_err=$rc
            fi
            continue
        fi
        ok=$((ok + 1))
    done < <(find "$dir" -maxdepth 1 -type f -print0)

    echo ""
    if [[ $skipped_ext -gt 0 ]]; then
        echo "⚠ 已略過 $skipped_ext 個不符 ${MODE} 白名單的檔" >&2
    fi
    if [[ $truncated -gt 0 ]]; then
        echo "⚠ 已達 ${LIMIT_FLAG} 上限（${BATCH_LIMIT}），尚有 $truncated 個未處理" >&2
    fi
    if [[ $fail -gt 0 ]]; then
        if [[ $ok -gt 0 ]]; then
            echo "❌ 批次部分失敗：成功 $ok / 失敗 $fail"
        else
            echo "❌ 批次失敗：成功 0 / 失敗 $fail"
        fi
        return "$first_err"
    fi
    # TMO-060：dry-run 沒有真的做事，不得宣稱「完成」
    if [[ "$DRY_RUN" == true ]]; then
        echo "[DRY-RUN] 批次完成：$ok 個檔案"
    else
        echo "✅ 批次完成：$ok 個檔案"
    fi
    return 0
}

# === 旗標解析 ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --input)
            INPUT="$2"
            shift 2
            ;;
        --input-dir)
            INPUT_DIR="$2"
            shift 2
            ;;
        --output-json)
            OUTPUT_JSON="$2"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --mock)
            MOCK=true
            shift
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --batch-limit|--max-concurrency)
            # TMO-060：0 合法（＝無限制）；拒絕負數／小數／非數字。
            LIMIT_FLAG="$1"
            BATCH_LIMIT="${2:-}"
            # TMO-058 順修（reviewer Round-1 P2-2）：非法值不可變「零產出卻印 ✅ 回 0」
            # 或「[[ ]] 算術報錯後默默不限制」→ 一律擋掉。
            # TMO-060：`0` 由非法改為合法（＝無限制，新預設），故訊息改「0 或正整數」。
            if [[ ! "$BATCH_LIMIT" =~ ^([0-9]|[1-9][0-9]*)$ ]]; then
                # P3-5：缺值時 `$2` 在 set -u 下會直接炸 → 走同一條友善錯誤（${2:-}）
                echo "ERROR: ${LIMIT_FLAG} 需為 0 或正整數（不得有前導零）（收到：${BATCH_LIMIT}）" >&2
                exit "$EXIT_USAGE"
            fi
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            exit "$EXIT_OK"
            ;;
        *)
            echo "ERROR: unknown flag: $1" >&2
            usage >&2
            exit "$EXIT_USAGE"
            ;;
    esac
done

# === 驗證 ===
if [[ -z "$MODE" ]]; then
    echo "ERROR: --mode is required (describe | transcript)" >&2
    usage >&2
    exit "$EXIT_USAGE"
fi

case "$MODE" in
    describe|transcript) ;;
    *)
        echo "ERROR: unsupported mode '$MODE' (supported: describe, transcript)" >&2
        exit "$EXIT_BADMODE"
        ;;
esac

# === 執行 ===
if [[ -n "$INPUT_DIR" ]]; then
    # 批次模式
    if [[ -z "$OUTPUT_DIR" ]]; then
        OUTPUT_DIR="./out"
    fi
    if [[ ! -d "$INPUT_DIR" ]]; then
        echo "ERROR: input-dir '$INPUT_DIR' does not exist" >&2
        exit "$EXIT_NOINPUT"
    fi
    echo "→ Batch mode: $MODE in $INPUT_DIR"
    process_batch "$INPUT_DIR" "$OUTPUT_DIR" || exit $?
else
    # 單檔模式
    if [[ -z "$INPUT" ]]; then
        echo "ERROR: --input or --input-dir is required" >&2
        usage >&2
        exit "$EXIT_USAGE"
    fi
    if [[ ! -f "$INPUT" ]]; then
        echo "ERROR: input '$INPUT' does not exist" >&2
        exit "$EXIT_NOINPUT"
    fi

    # describe 對非圖、副檔名警告（mock 仍執行）；白名單來自單一來源常數（不用 case 展開，免 SC2254）
    if [[ "$MODE" == "describe" ]]; then
        # TMO-060 順修（已揭露）：改 `-qi`——`IMG_001.JPG` 是圖片，不該被警告成
        # 「not an image file」；批次端已 case-insensitive，兩端結論必須一致。
        if ! printf '%s\n' "${INPUT##*.}" | grep -qiE "^($IMAGE_EXTS)$"; then
            echo "WARN: input '$INPUT' is not an image file" >&2
        fi
    fi
    if [[ "$MODE" == "transcript" ]]; then
        if ! printf '%s\n' "${INPUT##*.}" | grep -qiE "^($AUDIO_EXTS)$"; then
            echo "WARN: input '$INPUT' is not an audio/video file" >&2
        fi
    fi

    echo "→ Single mode: $MODE"
    # TMO-058：回傳值必須傳出去（`set -uo pipefail` 沒有 `-e`，不接就變 rc 0）
    process_single "$INPUT" "$OUTPUT_JSON" || exit $?
fi

exit "$EXIT_OK"
