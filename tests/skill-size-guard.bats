#!/usr/bin/env bats
#
# tests/skill-size-guard.bats
#
# 規範：`skills/**/SKILL.md` 主檔 ≤ 150 行（見 skills/dav-skill-creater/editor-guide.md）。
#
# 為什麼要這支（TMO-041 追加，審查後補）：
#   CI 的「Verify SKILL.md size」原本**只硬編檢查 `skills/dav-wiki/SKILL.md` 一檔**，
#   其他 10 檔（含 149 行的 `tdd-test-writer/SKILL.md`）改爆了也不會被擋
#   —— 同 TMO-038 ④ / TMO-033 的教訓：硬編清單＝靜默覆蓋缺口。
#   現在 CI 改成呼叫 `scripts/ci/check-skill-size.sh`（自動列舉），本檔負責鎖這件事。
#
# SSG-1：repo 內每個 SKILL.md 都 ≤150 行，且列舉數 ≥11（防空過）
# SSG-2：CI 的那一步必須呼叫腳本、且不得再硬編單一檔案路徑
# SSG-3：腳本本身可被實測（假 root：151 行→紅；150 行→綠；空目錄→紅，防空過）

load 'helpers/test-env'

setup() {
  SCRIPT="$REPO_ROOT/scripts/ci/check-skill-size.sh"
}

@test "SSG-1: every SKILL.md is within 150 lines (auto-enumerated, not a hardcoded list)" {
  [ -f "$SCRIPT" ] || {
    echo "FAIL: 缺 $SCRIPT" >&2
    return 1
  }
  local n=0 worst=0 worst_f="" f lines
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    lines=$(wc -l < "$f" | tr -d ' ')
    n=$((n + 1))
    if [ "$lines" -gt "$worst" ]; then worst="$lines"; worst_f="$f"; fi
    if [ "$lines" -gt 150 ]; then
      echo "FAIL: $f = $lines 行（上限 150）" >&2
      return 1
    fi
  done < <(find "$REPO_ROOT/skills" -name SKILL.md -type f | sort)
  [ "$n" -ge 11 ] || {
    echo "FAIL: 只列舉到 $n 個 SKILL.md（< 11）→ 列舉壞掉（防空過）" >&2
    return 1
  }
  echo "OK: $n 個 SKILL.md 皆 <= 150 行（最長 $worst 行：${worst_f}）" >&2
}

@test "SSG-2: CI step runs the auto-enumerating script (no single-file hardcode)" {
  local ci="$REPO_ROOT/.github/workflows/ci.yml"
  [ -f "$ci" ] || {
    echo "FAIL: 缺 $ci" >&2
    return 1
  }
  local block
  block=$(awk '/- name: Verify SKILL\.md size/{f=1} f && /^      - name: / && !/Verify SKILL\.md size/{exit} f' "$ci")
  [ -n "$block" ] || {
    echo "FAIL: 抽不到 CI 的 SKILL.md size 步驟（anchor 可能被改名）" >&2
    return 1
  }
  printf '%s' "$block" | grep -q 'scripts/ci/check-skill-size\.sh' || {
    echo "FAIL: CI 的 SKILL.md size 步驟沒呼叫自動列舉腳本：" >&2
    printf '%s\n' "$block" >&2
    return 1
  }
  if printf '%s' "$block" | grep -qE 'skills/[a-z0-9-]+/SKILL\.md'; then
    echo "FAIL: CI 的 SKILL.md size 步驟仍硬編單一檔案路徑（其他 skill 改爆不會被擋）：" >&2
    printf '%s\n' "$block" >&2
    return 1
  fi
  echo "OK: CI 呼叫 check-skill-size.sh 且無硬編路徑" >&2
}

@test "SSG-3: size script is measurable in both directions (over-long fails, at-limit passes, empty fails)" {
  local fake="$BATS_TEST_TMPDIR/fake-repo"
  mkdir -p "$fake/skills/aaa" "$fake/skills/bbb"
  # 150 行＝上限內（綠）；151 行＝超限（紅）
  awk 'BEGIN{for(i=1;i<=150;i++) print "line " i}' > "$fake/skills/aaa/SKILL.md"
  awk 'BEGIN{for(i=1;i<=151;i++) print "line " i}' > "$fake/skills/bbb/SKILL.md"

  # (a) 151 行 → 紅（且訊息要指出是哪一檔）
  run env SKILL_MIN=1 bash "$SCRIPT" "$fake"
  [ "$status" -ne 0 ] || {
    echo "FAIL: 超限（151 行）竟然綠 → 檢查沒在做事：$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q 'bbb/SKILL.md' || {
    echo "FAIL: 紅了但沒指出超限檔案：$output" >&2
    return 1
  }

  # (b) 全部 ≤150 → 綠
  awk 'BEGIN{for(i=1;i<=150;i++) print "line " i}' > "$fake/skills/bbb/SKILL.md"
  run env SKILL_MIN=1 bash "$SCRIPT" "$fake"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 150 行（上限內）竟然紅：$output" >&2
    return 1
  }

  # (c) 空目錄 → 紅（防空過：列舉不到檔案時不可以靜默綠）
  local empty="$BATS_TEST_TMPDIR/empty-repo"
  mkdir -p "$empty/skills"
  run env SKILL_MIN=1 bash "$SCRIPT" "$empty"
  [ "$status" -ne 0 ] || {
    echo "FAIL: 完全沒有 SKILL.md 卻綠（空過）：$output" >&2
    return 1
  }
}
