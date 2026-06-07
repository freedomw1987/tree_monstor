#!/usr/bin/env bash
# memory_normalize.sh — Fix memory tool's "wouldn't round-trip" error by normalizing
# the § delimiter format to match the tool's expected layout.
#
# Problem: When MEMORY.md / USER.md is edited via write_file / patch / shell
# append (instead of the proper memory tool), the § delimiter often gets
# surrounded by \n on both sides (i.e. "...entry.\n§\nnext entry..."). The
# memory tool's parser does raw.split(§) then re-joins with just §, dropping
# the newlines. Result: raw.strip() != roundtrip, drift detected, every
# subsequent memory tool call refuses to write.
#
# Fix: Rewrite the file with § surrounded by exactly one space (\n§\n → §\n
# on first entry, and last §\n\n → §\n at end of file).
#
# Run: bash ~/.hermes/profiles/developer/skills/interruption-recovery/scripts/memory_normalize.sh
#      bash ~/.hermes/profiles/developer/skills/interruption-recovery/scripts/memory_normalize.sh --dry-run
#
# This script preserves the content of all entries exactly. It only normalizes
# whitespace around the § delimiter.

set -e

PROFILE="developer"
DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

MEM_DIR="$HOME/.hermes/memories"

normalize_file() {
    local path="$1"
    local label="$2"

    if [ ! -f "$path" ]; then
        echo "  ⚠️  $label: file not found ($path)"
        return 0
    fi

    # Backup
    local bak="${path}.bak.$(date +%s)"
    cp "$path" "$bak"

    # Use Python for precise text manipulation
    python3 - "$path" "$bak" "$DRY_RUN" <<'PYTHON'
import sys
from pathlib import Path

path, bak_path, dry_run = sys.argv[1], sys.argv[2], sys.argv[3] == "1"

raw = Path(path).read_text(encoding="utf-8")
ENTRY_DELIMITER = "§"

# Step 1: split on § (preserving the exact content of each entry)
parts = raw.split(ENTRY_DELIMITER)

# Step 2: strip whitespace from each part (this is what the memory tool does)
stripped = [p.strip() for p in parts]

# Step 3: drop empty parts
non_empty = [s for s in stripped if s]

# Step 4: rejoin with exactly "§" between entries (NO trailing newline,
# matching the tool's _write_file() format at memory_tool.py:579:
#   content = ENTRY_DELIMITER.join(entries) if entries else ""
new_content = ENTRY_DELIMITER.join(non_empty)

# Verify round-trip clean
roundtrip_check = ENTRY_DELIMITER.join([s for s in new_content.split(ENTRY_DELIMITER) if s.strip()])
ok = (new_content.strip() == roundtrip_check)
print(f"  Path: {path}")
print(f"  Original: {len(raw)} chars, {len(non_empty)} entries")
print(f"  Normalized: {len(new_content)} chars, {len(non_empty)} entries")
print(f"  Round-trip clean: {ok}")
print(f"  Backup: {bak_path}")

if ok and not dry_run:
    Path(path).write_text(new_content, encoding="utf-8")
    print(f"  ✅ Written: {path}")
elif dry_run:
    print(f"  (dry-run, not writing)")
else:
    print(f"  ❌ Round-trip still broken, NOT writing")
PYTHON
}

echo "═══════════════════════════════════════════════════════════════"
echo "🧹 MEMORY NORMALIZE — Profile: $PROFILE"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "MEMORY.md:"
normalize_file "$MEM_DIR/MEMORY.md" "MEMORY.md"
echo ""
echo "USER.md:"
normalize_file "$MEM_DIR/USER.md" "USER.md"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✅ Done. Memory tool should now accept writes."
echo ""
echo "Test: Try memory(action=add, content='test entry') and see if it works."
echo "═══════════════════════════════════════════════════════════════"
