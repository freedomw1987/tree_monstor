#!/usr/bin/env bash
# tools/wiki-merge-media.sh — Sprint 08 FR-2.2.4 + FR-2.5.1
# 對應 docs/prd/03-knowledge-extraction.md FR-3.4 / docs/plan/2026-01-15-dav-wiki-sprint-08.md
#
# 把 media manifest JSON 合併進 wiki 屬性的 frontmatter。
# 用 Python PyYAML 確保 frontmatter 結構正確（與其他 dav-wiki 工具一致）。

set -uo pipefail

# === 預設值 ===
WIKI_FILE=""
MEDIA_FILE=""
MEDIA_TYPE=""
DRY_RUN=false

# === 錯誤碼 ===
EXIT_OK=0
EXIT_USAGE=1
EXIT_NOINPUT=2

# === 使用說明 ===
usage() {
    cat <<EOF
Usage: wiki-merge-media.sh --wiki <md> --media <json> --media-type <type> [options]

把單筆 media manifest JSON 合併進 wiki 屬性的 frontmatter。

Media types:
  image     圖片 → frontmatter images 陣列
  video     影片 → frontmatter videos 陣列
  audio     音訊 → frontmatter audios 陣列

Options:
  --wiki <file>            必填：wiki 屬性路徑
  --media <file>           必填：media manifest JSON
  --media-type <type>      必填：image | video | audio
  --dry-run                只印計畫不修改
  --help / -h              顯示說明

Exit codes:
  0  成功
  1  用法錯誤
  2  輸入檔案不存在

對應手冊: docs/prd/03-knowledge-extraction.md (FR-3.4 / FR-3.5)
EOF
}

# === 旗標解析 ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --wiki)
            WIKI_FILE="$2"
            shift 2
            ;;
        --media)
            MEDIA_FILE="$2"
            shift 2
            ;;
        --media-type)
            MEDIA_TYPE="$2"
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
if [[ -z "$WIKI_FILE" || -z "$MEDIA_FILE" || -z "$MEDIA_TYPE" ]]; then
    echo "ERROR: --wiki, --media, --media-type are all required" >&2
    usage >&2
    exit "$EXIT_USAGE"
fi

if [[ ! -f "$WIKI_FILE" ]]; then
    echo "ERROR: wiki file '$WIKI_FILE' does not exist" >&2
    exit "$EXIT_NOINPUT"
fi

if [[ ! -f "$MEDIA_FILE" ]]; then
    echo "ERROR: media file '$MEDIA_FILE' does not exist" >&2
    exit "$EXIT_NOINPUT"
fi

case "$MEDIA_TYPE" in
    image|video|audio) ;;
    *)
        echo "ERROR: invalid media-type '$MEDIA_TYPE'" >&2
        exit "$EXIT_USAGE"
        ;;
esac

# === 呼叫 Python 做實際合併 ===
# 從 media-type 推 frontmatter key
case "$MEDIA_TYPE" in
    image) FM_KEY="images" ;;
    video) FM_KEY="videos" ;;
    audio) FM_KEY="audios" ;;
esac

if [[ "$DRY_RUN" == true ]]; then
    echo "[DRY-RUN] Would merge $MEDIA_TYPE into $WIKI_FILE"
    echo "[DRY-RUN] Frontmatter key: $FM_KEY"
    exit "$EXIT_OK"
fi

python3 - "$WIKI_FILE" "$MEDIA_FILE" "$FM_KEY" "$MEDIA_TYPE" <<'PYEOF'
import sys
import json
import re

wiki_path = sys.argv[1]
media_path = sys.argv[2]
fm_key = sys.argv[3]
media_type = sys.argv[4]

# 讀 wiki
with open(wiki_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 拆 frontmatter / body
m = re.match(r'^---\n(.*?)\n---\n(.*)$', content, re.DOTALL)
if not m:
    print(f"ERROR: no frontmatter in {wiki_path}", file=sys.stderr)
    sys.exit(1)

front_yaml = m.group(1)
body = m.group(2)

# 用 PyYAML 解析（不匯入 yaml 模組也可用正則，但 PyYAML 更安全）
try:
    import yaml
    have_yaml = True
except ImportError:
    have_yaml = False

if have_yaml:
    fm = yaml.safe_load(front_yaml) or {}
    # 構造新 entry
    with open(media_path, 'r', encoding='utf-8') as f:
        media = json.load(f)
    entry = {k: v for k, v in media.items() if v is not None and v != ""}
    # 確保必要欄位
    if 'source' in entry:
        entry['source'] = entry['source']
    # 加入陣列
    if fm_key not in fm:
        fm[fm_key] = []
    if not isinstance(fm[fm_key], list):
        fm[fm_key] = [fm[fm_key]]
    fm[fm_key].append(entry)
    # 序列化
    new_front = yaml.dump(fm, allow_unicode=True, sort_keys=False, default_flow_style=False)
else:
    # Fallback：正則 append（精簡版）
    with open(media_path, 'r', encoding='utf-8') as f:
        media = json.load(f)
    entry_lines = [f"  - source: \"{media.get('source', '')}\""]
    if 'caption' in media:
        entry_lines.append(f"    caption: \"{media['caption']}\"")
    if 'alt_text' in media:
        entry_lines.append(f"    alt_text: \"{media['alt_text']}\"")
    if 'duration' in media:
        entry_lines.append(f"    duration: {media['duration']}")
    if 'thumb' in media:
        entry_lines.append(f"    thumb: \"{media['thumb']}\"")
    if 'transcript' in media:
        entry_lines.append(f"    transcript: \"{media['transcript']}\"")
    new_entry = "\n".join(entry_lines)
    # 找 `${fm_key}:` 行，若有則在第一個 `-` 後插入；沒有則附加
    pattern_key = f"^{fm_key}:"
    if re.search(pattern_key, front_yaml, re.MULTILINE):
        # 找到 `${fm_key}:` 行，在該行插入（其後第一個 `-` 之前）
        new_front = re.sub(
            pattern_key,
            f"{fm_key}:\n{new_entry}",
            front_yaml,
            count=1,
            flags=re.MULTILINE
        )
    else:
        new_front = front_yaml.rstrip() + f"\n{fm_key}:\n{new_entry}\n"

# 寫回
new_content = f"---\n{new_front}---\n{body}"
if not body.startswith('\n'):
    new_content = f"---\n{new_front.rstrip()}\n---\n{body}"

with open(wiki_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"  ✓ Merged {media_type} into {wiki_path} (key: {fm_key})")
PYEOF

exit "$EXIT_OK"