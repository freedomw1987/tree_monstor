#!/usr/bin/env bash
# pre_tool_checkpoint.sh — Proactive checkpoint hook (v2)
#
# Called BEFORE any file-mutating tool. Snapshots the working directory to a
# git ref BEFORE mutation, so any botched edit can be reverted with /rollback.
#
# Why this exists: Hermes 0.15.1's built-in CheckpointManager is configured
# (enabled: true in config.yaml) but never actually triggered by AIAgent in
# developer profile — verified 2026-06-07. This hook is our safety net.
#
# Usage:
#   pre_tool_checkpoint.sh <workdir> <reason>
#
# Output (stdout, key=value):
#   STATUS=ok|skipped
#   CHECKPOINT_HASH=<7-char hash>
#   CHECKPOINT_REASON=<reason>
#   WORKDIR=<abs path>
#   FILES_DIRTY=<count>
#   DURATION_MS=<int>
#   REF=refs/checkpoints/<base>/<timestamp>

set -uo pipefail  # NOTE: removed -e, we handle errors explicitly

workdir="${1:-$(pwd)}"
reason="${2:-manual}"

# Reject root / home
case "$workdir" in
    /|"$HOME") echo "STATUS=skipped REASON=directory_too_broad"; exit 0 ;;
esac

if [[ ! -d "$workdir/.git" ]]; then
    echo "STATUS=skipped REASON=not_a_git_repo"
    exit 0
fi

ts="$(date +%s)"
short_ts="$(date +%H%M%S%3N)"  # millisecond precision
base="$(basename "$workdir")"
ref="checkpoints/${base}/${short_ts}"

start_ms=$(($(date +%s%N) / 1000000))

# Strategy: Use git stash to capture the working tree state, then create a
# ref pointing to the stash's commit. This way we never have to mess with
# HEAD/checkout (which is what broke v1).
pushd "$workdir" > /dev/null || { echo "STATUS=error REASON=cannot_chdir"; exit 1; }

# Count dirty files
dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Stash uncommitted changes (including untracked)
stash_msg="cp-${ts}-${short_ts}"
git stash push -u -m "$stash_msg" > /dev/null 2>&1 || true

# Stash@{0} now contains the pre-mutation state
stash_commit=$(git rev-parse "stash@{0}" 2>/dev/null) || stash_commit=""

if [[ -z "$stash_commit" ]]; then
    # Nothing was stashed (working tree was clean) — use HEAD
    stash_commit=$(git rev-parse HEAD 2>/dev/null) || stash_commit="unknown"
fi

# Create the ref pointing to the stash commit
git update-ref "refs/$ref" "$stash_commit" 2>/dev/null || true

# Update the per-directory "latest" ref
git update-ref "refs/checkpoints/$base" "$stash_commit" 2>/dev/null || true

# Restore the stashed changes (so the workdir is unchanged after the hook)
if [[ -n "$(git stash list 2>/dev/null | grep "$stash_msg")" ]]; then
    git stash pop > /dev/null 2>&1 || true
fi

popd > /dev/null || true

end_ms=$(($(date +%s%N) / 1000000))
duration=$((end_ms - start_ms))

short_hash="${stash_commit:0:7}"

# Output (machine-parseable)
echo "STATUS=ok"
echo "CHECKPOINT_HASH=$short_hash"
echo "CHECKPOINT_REASON=$reason"
echo "WORKDIR=$workdir"
echo "FILES_DIRTY=$dirty"
echo "DURATION_MS=$duration"
echo "REF=refs/$ref"

# Journal for /rollback list
journal="$workdir/.hermes-checkpoints.log"
echo "$ts $short_hash $reason" >> "$journal" 2>/dev/null || true
