#!/usr/bin/env bats
# tests/framework-weight.bats
#
# TMO-082（第二刀 A+D）守門：框架體重 / context 成本 / 指標完整性。
#
# 背景：TMO-075 第一刀砍咗 meta 探針，但「衍生膨脹」嘅機制仲喺度；
#       第二刀做咗 context 瘦身（A）＋ 量度守門（D），呢支探針就係 D 嘅守護。
#
# 守三樣嘢：
#   ① 每個 skill 嘅 context 預算（SKILL.md + 支援 .md ≤ cap）—— 防止 agent 讀入量再膨脹
#   ② 指標完整性（SKILL.md 點名嘅子檔必須存在且非空）—— 防止「指標指住空檔」嘅假覆蓋
#   ③ 框架／產品行數比唔可以明顯上升（baseline + tolerance ratchet）
#
# 全部探針都用 fixture root 實測（唔係淨係讀設定檔），
# 而且**每一支都要證明「壞嘅情況真係會紅」**（防空過）。
load 'helpers/test-env'

setup() {
  SCRIPT="$REPO_ROOT/scripts/ci/check-framework-weight.py"
  CFG="$REPO_ROOT/docs/ci/framework-weight.json"
  WORK="$BATS_TEST_TMPDIR/fw"
  rm -rf "$WORK"
  mkdir -p "$WORK"
}

# 建一個最小但合法嘅 fixture repo：
#   skills/<name>/SKILL.md      （主檔）
#   skills/<name>/sub.md        （支援檔）
#   docs/ci/framework-weight.json（設定）
#   product 檔（skills/**/code.py）—— 令 ratio 有分母
make_fixture() {
  local root="$1" skill="${2:-demo-skill}" sub_lines="${3:-40}"
  mkdir -p "$root/skills/$skill" "$root/docs/ci" "$root/tests"
  {
    echo "# $skill"
    echo
    echo "見 [子檔](./sub.md)。"
    echo
    # ⚠️ code fence 要用單引號：雙引號入面嘅 ``` 會被 bash 當成反引號命令替換
    #    → 會吞晒下面嘅 for loop（2026-10-26 實測踩到）
    echo '```'
    for i in $(seq 1 "$sub_lines"); do echo "line $i"; done
    echo '```'
  } > "$root/skills/$skill/SKILL.md"
  {
    echo "# sub"
    for i in $(seq 1 "$sub_lines"); do echo "content $i"; done
  } > "$root/skills/$skill/sub.md"
  for i in $(seq 1 50); do echo "x = $i"; done > "$root/skills/$skill/code.py"
  cp "$CFG" "$root/docs/ci/framework-weight.json"
}

# 用指定嘅設定覆寫 fixture 嘅設定
write_cfg() {
  local root="$1"; shift
  cat > "$root/docs/ci/framework-weight.json"
}

@test "FW-1: guard script and config file exist and are usable" {
  [ -f "$SCRIPT" ] || { echo "FAIL: 缺 $SCRIPT" >&2; return 1; }
  [ -f "$CFG" ] || { echo "FAIL: 缺 $CFG" >&2; return 1; }
  [ -x "$SCRIPT" ] || { echo "FAIL: $SCRIPT 唔可執行" >&2; return 1; }
  # 設定檔必含關鍵欄位（缺欄位 = 守門名存實亡）
  for key in min_skills skill_caps total_context_cap ratio; do
    grep -q "\"$key\"" "$CFG" || { echo "FAIL: 設定檔缺欄位 $key" >&2; return 1; }
  done
  grep -q '"baseline"' "$CFG" || { echo "FAIL: ratio 缺 baseline" >&2; return 1; }
  grep -q '"tolerance"' "$CFG" || { echo "FAIL: ratio 缺 tolerance" >&2; return 1; }
}

@test "FW-2: the real repo passes with rc=0" {
  run python3 "$SCRIPT" --root "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 真實 repo 應該通過，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  # 儀表板必須真係印出 per-skill context 表（唔係空過）
  printf '%s' "$output" | grep -q "context 成本" || {
    echo "FAIL: 儀表板冇印 context 成本表" >&2; return 1; }
  printf '%s' "$output" | grep -q "框架／產品比" || {
    echo "FAIL: 儀表板冇印框架／產品比" >&2; return 1; }
}

@test "FW-3: context over budget must fail" {
  make_fixture "$WORK" demo-skill 40
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 10, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: context 超上限應該 rc=1，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  # 斷言要咬到「違規特徵字串」，唔係「context」（儀表板標題就有 context → 會空轉）
  printf '%s' "$output" | grep -q "上限" || {
    echo "FAIL: 應該報『超上限』嘅違規訊息" >&2
    printf '%s\n' "$output" >&2
    return 1; }
}

@test "FW-4: dangling subfile pointer must fail" {
  make_fixture "$WORK" demo-skill 40
  # 指標指向一個唔存在嘅檔
  echo "見 [壞指標](./missing.md)。" >> "$WORK/skills/demo-skill/SKILL.md"
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 死指標應該 rc=1，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "missing.md" || {
    echo "FAIL: 應該指名 missing.md" >&2; return 1; }
}

@test "FW-5: emptied subfile must fail" {
  make_fixture "$WORK" demo-skill 40
  : > "$WORK/skills/demo-skill/sub.md"   # 掏空
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 被掏空嘅子檔應該 rc=1，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "掏空" || {
    echo "FAIL: 應該報『掏空』" >&2; return 1; }
}

@test "FW-6: broken enumeration must fail (no silent green)" {
  make_fixture "$WORK" demo-skill 40
  write_cfg "$WORK" <<'EOF'
{"min_skills": 13, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 枚舉唔過應該 rc=1（唔可以當綠），但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "防空過" || {
    echo "FAIL: 應該報『防空過』" >&2; return 1; }
}

@test "FW-7: framework/product ratio over ceiling must fail" {
  make_fixture "$WORK" demo-skill 40
  # baseline 極低 = 任何比值都超標
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.0001}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: ratio 超標應該 rc=1，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "行數比" || {
    echo "FAIL: 應該報行數比違規" >&2; return 1; }
}

@test "FW-8: missing skills dir exits 2 (not green)" {
  mkdir -p "$WORK/empty"
  run python3 "$SCRIPT" --root "$WORK/empty"
  [ "$status" -eq 2 ] || {
    echo "FAIL: 冇 skills/ 應該 rc=2，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
}

@test "FW-9: CI runs the guard and it is not a fake green" {
  local ci="$REPO_ROOT/.github/workflows/ci.yml"
  [ -f "$ci" ] || { echo "FAIL: 缺 ci.yml" >&2; return 1; }
  grep -q 'check-framework-weight' "$ci" || {
    echo "FAIL: ci.yml 冇接上 check-framework-weight" >&2; return 1; }
  # 假綠防線：ci.yml 內唔准出現 continue-on-error
  # （註：只係 ci.yml 內；repo 其他 workflow（例如 jev-poc.yml）另有自己的政策）
  local code
  code=$(grep -vE '^[[:space:]]*#' "$ci")
  if printf '%s\n' "$code" | grep -q 'continue-on-error'; then
    echo "FAIL: ci.yml 內有 continue-on-error（該 step 唔會擋）" >&2; return 1
  fi
  # 假綠防線：抽「嗰個 step 嘅完整區塊」（由 - name: 行到下一個 step）
  # → 逐行查 `|| true` / `|| :`（只查同一行會漏咗多行 run: | 區塊寫法）
  local block
  block=$(printf '%s\n' "$code" | awk '
    /- name: Verify framework weight/ {flag=1}
    flag && /^      - / && !/Verify framework weight/ {exit}
    flag {print}
  ')
  [ -n "$block" ] || { echo "FAIL: 抽唔到 framework weight step 區塊" >&2; return 1; }
  if printf '%s\n' "$block" | tr -d '[:space:]' | grep -qE '\|\|(true|:)'; then
    echo "FAIL: check-framework-weight step 有 || true / || :（假綠）" >&2
    printf '%s\n' "$block" >&2
    return 1
  fi
  # 嗰個 step 必須真係執行個腳本（唔止係提一句）
  printf '%s\n' "$block" | grep -q 'python3 scripts/ci/check-framework-weight.py' || {
    echo "FAIL: 嗰個 step 冇真正執行 check-framework-weight.py" >&2
    printf '%s\n' "$block" >&2
    return 1
  }
}


@test "FW-10: the context check really runs (self proof)" {
  # 用「設定檔刻意收窄到極細」模擬守門失效：若腳本根本冇檢查 context，
  # 下面呢個 fixture 應該會 rc=0 → 證明現時係真檢查。
  make_fixture "$WORK" demo-skill 40
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 5, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 極細 cap 應該 rc=1（證明 context 檢查真係有做）" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
}

@test "FW-11: a repo under a dir named tmp/ or cache/ is still measured" {
  # 2026-10-26 實測踩到嘅真 bug：跳過清單如果連 root 路徑都睇，
  # 將 repo 放喺 /tmp/xxx 或 .../cache/xxx 之下 → 全部檔案被當成排除項 → 量度變 0
  # → 守門會「因為冇嘢可查」而永遠綠（假綠）。呢支探針鎖住呢個回歸。
  local weird="$BATS_TEST_TMPDIR/cache/weird-root"
  mkdir -p "$weird"
  make_fixture "$weird" demo-skill 40
  write_cfg "$weird" <<'EOF'
{"min_skills": 1, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 10, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$weird" --json
  [ "$status" -eq 0 ] || {
    echo "FAIL: 怪路徑下應該 rc=0，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  # 量度結果必須非 0（唔係「掃唔到就當 0」）
  printf '%s' "$output" | grep -q '"total_context_lines": 0' && {
    echo "FAIL: 怪路徑下量度結果係 0 → 量度壞咗（防空過）" >&2
    return 1
  }
  # 同時必須真係量到 skill（枚舉唔係空）
  printf '%s' "$output" | grep -q '"name": "demo-skill"' || {
    echo "FAIL: 怪路徑下枚舉唔到 skill → 枚舉壞咗" >&2
    return 1
  }
}

@test "FW-12: an emptied subfile fails even when it is referenced by bare name" {
  # repo 主流寫法係裸名引用（`同套 workflow.md`），唔係 `./workflow.md`。
  # 原本守門只捉 `./` 形式 → 裸名引用嘅子檔被掏空唔會紅（Reviewer P1-2）。
  # 而家改成「庫存檢查」：skill 目錄內任何 .md 被掏空就報。
  make_fixture "$WORK" demo-skill 40
  # 用裸名引用 sub.md（唔加 ./）
  echo "見同套 sub.md 嘅內容。" >> "$WORK/skills/demo-skill/SKILL.md"
  : > "$WORK/skills/demo-skill/sub.md"
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 被掏空嘅子檔應該 rc=1，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "掏空" || {
    echo "FAIL: 應該報『掏空』" >&2; return 1; }
}

@test "FW-13: a deleted subfile fails (git tracked but missing on disk)" {
  # 需要一個真 git repo（tracked → 磁碟上冇）先測得到
  local repo="$WORK/gitrepo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email t@t.t
  git -C "$repo" config user.name t
  make_fixture "$repo" demo-skill 40
  git -C "$repo" add -A >/dev/null 2>&1
  git -C "$repo" commit -qm init >/dev/null 2>&1
  rm -f "$repo/skills/demo-skill/sub.md"
  write_cfg "$repo" <<'EOF'
{"min_skills": 1, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$repo"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 被刪除嘅子檔應該 rc=1，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "已被刪除" || {
    echo "FAIL: 應該報『已被刪除』" >&2; return 1; }
}

@test "FW-14: a dead pointer inside a support file fails (not only in SKILL.md)" {
  make_fixture "$WORK" demo-skill 40
  # 支援檔入面嘅死指標（`.//` 寫法）→ 必須紅（Reviewer P1-3：守門原本只掃 SKILL.md）
  echo "細節見 [壞指標](./nowhere.md)。" >> "$WORK/skills/demo-skill/sub.md"
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 支援檔入面嘅死指標應該 rc=1，但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "nowhere.md" || {
    echo "FAIL: 應該指名 nowhere.md" >&2; return 1; }
}

@test "FW-15: a zero cap in the config fails closed (guard must not silently disable itself)" {
  make_fixture "$WORK" demo-skill 40
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 0, "total_context_cap": 0,
 "skill_caps": {}, "ratio": {"baseline": 0, "tolerance": 0}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: cap/baseline 被設成 0 應該 rc=1（唔可以靜靜哋唔檢查），但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "靜靜哋失效" || {
    echo "FAIL: 應該報『靜靜哋失效』" >&2; return 1; }
}

@test "FW-16: zero product lines fails closed (ratio must not become vacuously true)" {
  # 產品層 = skills 內非 .md 嘅內容；全部刪走 → ratio 冇分母 → 必須紅（Reviewer P2-2）
  make_fixture "$WORK" demo-skill 40
  rm -f "$WORK/skills/demo-skill/code.py"
  write_cfg "$WORK" <<'EOF'
{"min_skills": 1, "default_skill_cap": 100000, "total_context_cap": 100000,
 "skill_caps": {}, "ratio": {"baseline": 0.0001, "tolerance": 0.5}}
EOF
  run python3 "$SCRIPT" --root "$WORK"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 產品層 0 行應該 rc=1（ratio 唔可以恆真），但 rc=$status" >&2
    printf '%s\n' "$output" >&2
    return 1
  }
  printf '%s' "$output" | grep -q "產品層" || {
    echo "FAIL: 應該報產品層為 0" >&2; return 1; }
}
