#!/usr/bin/env bats
#
# tests/docs-reduction.bats
#
# TMO-010: docs/ reduction rules
# - Isolated handbook files (no references anywhere) should be cleaned up
# - Historical deliverables that violate v2.0 rules (HTML, separate reflection)
#   can be cleaned up in bulk-reduction mode (user explicitly approved)
# - Pre-existing v2.0 stock files remain unless bulk-reduction is approved

load 'helpers/test-env'

@test "DOCS-REDUCE-001: no leftover deliverable HTML files (v2.0 prohibits HTML)" {
  local deliverable_dir="$REPO_ROOT/docs/deliverable"
  # TMO-010 reduced HTML files: should have no .html in deliverable/
  if ls "$deliverable_dir"/*.html 2>/dev/null | head -1 | grep -q .; then
    echo "FAIL: deliverable/ should have no .html files (v2.0 rule)" >&2
    ls "$deliverable_dir"/*.html >&2
    return 1
  fi
}

@test "DOCS-REDUCE-002: no isolated handbook files (dav-wiki-cleanup removed)" {
  local isolated="$REPO_ROOT/docs/sop/handbook/dav-wiki-cleanup.md"
  [ ! -f "$isolated" ] || {
    echo "FAIL: $isolated should have been removed (isolated, 0 references)" >&2
    return 1
  }
}

@test "DOCS-REDUCE-003: pre-existing reflection files reduced (TMO-006/007)" {
  local ref1="$REPO_ROOT/docs/reflection/v1.8-dav-planner-ac-templates-reflection.md"
  local ref2="$REPO_ROOT/docs/reflection/v1.9-dav-planner-user-background-reflection.md"
  [ ! -f "$ref1" ] || {
    echo "FAIL: $ref1 should have been removed (TMO-010 bulk reduction)" >&2
    return 1
  }
  [ ! -f "$ref2" ] || {
    echo "FAIL: $ref2 should have been removed (TMO-010 bulk reduction)" >&2
    return 1
  }
}

@test "DOCS-REDUCE-004: trust-mode and v1.7.1 reflections remain (not in TMO-010 scope)" {
  local trust_ref="$REPO_ROOT/docs/reflection/trust-mode-2026-09-23-reflection.md"
  local v171_ref="$REPO_ROOT/docs/reflection/v1.7.1-tech-debt-cleanup-reflection.md"
  [ -f "$trust_ref" ] || {
    echo "FAIL: $trust_ref should remain (not in TMO-010 scope)" >&2
    return 1
  }
  [ -f "$v171_ref" ] || {
    echo "FAIL: $v171_ref should remain (not in TMO-010 scope)" >&2
    return 1
  }
}

@test "DOCS-REDUCE-005: changelog has TMO-010 entry" {
  local changelog="$REPO_ROOT/docs/sop/handbook/changelog.md"
  grep -qE '^## v2\.4|TMO-010|減法' "$changelog" || {
    echo "FAIL: changelog should have TMO-010 entry (or v2.4 entry)" >&2
    return 1
  }
}

@test "DOCS-REDUCE-006: trust-mode reflection predates v2.0 and is not subject to bulk reduction" {
  # This probe is informational. trust-mode-2026-09-23-reflection.md predates v2.0
  # (it's the historical trust-mode reflection). TMO-010 only covers v1.8/v1.9.
  local trust_ref="$REPO_ROOT/docs/reflection/trust-mode-2026-09-23-reflection.md"
  local trust_date
  trust_date=$(LC_ALL=C grep -oE '2026-09-23' "$trust_ref" | head -1 || echo "")
  [ -n "$trust_date" ] || {
    echo "WARN: trust-mode reflection should contain date 2026-09-23" >&2
  }
}

@test "DOCS-REDUCE-007: live code/docs must not point at a missing handbook file" {
  # TMO-034：`docs/sop/handbook/dav-wiki-cleanup.md` 被 TMO-028 刪除後，`wiki-cleanup.sh` 仍引用它。
  # 此探針掃「活檔案」（skills/ scripts/ .github/ + 根目錄文件），任何指向不存在的
  # docs/sop/handbook/*.md 都算死引用。（docs/ 內含歷史紀錄，不在掃描範圍。）
  local refs ref
  # round C P2-6：① 逐掃描根檢查存在（若 `skills/` 被改名，grep rc=2 被 2>/dev/null 吞掉，
  # 其他根的命中仍讓 refs 非空 → 覆蓋靜默丟失還綠）；② 把 `lib/`/`install.sh`/`SOUL.md`
  # 也納入（round C 前未掃）。`tests/` **刻意不納**：內含「故意引用已刪檔」的負向探針
  # （DOCS-REDUCE-002 的 `dav-wiki-cleanup.md`），納入必誤紅。
  local roots=(skills scripts .github lib CONTRIBUTING.md README.md AGENTS.md install.sh SOUL.md)
  local r
  for r in "${roots[@]}"; do
    [ -e "$REPO_ROOT/$r" ] || {
      echo "FAIL: 掃描根不存在（覆蓋靜默丟失）：$r" >&2
      return 1
    }
  done
  refs="$(grep -rhoE 'docs/sop/handbook/[0-9A-Za-z._-]+\.md' \
      "${roots[@]/#/$REPO_ROOT/}" 2>/dev/null \
      | sort -u || true)"
  # 正向錨定：掃不到任何引用＝掃描器失效，不可是「安靜地綠」
  [ -n "$refs" ] || {
    echo "FAIL: 掃不到任何 handbook 引用，掃描器可能失效" >&2
    return 1
  }
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    [ -f "$REPO_ROOT/$ref" ] || {
      echo "FAIL: 活檔案仍指向不存在的 handbook 檔：$ref" >&2
      grep -rn "$ref" "${roots[@]/#/$REPO_ROOT/}" 2>/dev/null >&2
      return 1
    }
  done <<< "$refs"
}
