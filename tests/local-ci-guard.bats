#!/usr/bin/env bats
#
# tests/local-ci-guard.bats
#
# TMO-084：守「本機 CI 等價 runner」（`scripts/check-all.sh`）唔會悄悄走樣。
#
# 背景：本 repo 嘅 CI 係 GitHub Actions（clean clone、雙 OS、乾淨依賴、冇 API key）。
# 「本機綠 ≠ CI 綠」係已知嘅坑（shellcheck 版本、bash 3.2 vs 5、locale、未版控檔、真 API key、暖快取⋯⋯）。
# TMO-084 加咗 `scripts/check-all.sh`，令開發者 push 前喺本機跑一次（唔使事後等 Actions）。
#
# ⚠️ 本機 runner 本身就係一件會漂移嘅嘢 —— 冇人守佢嘅話會出現：① ci.yml 加咗新 step 但本機冇跟
#    （**假覆蓋**）② 本機加咗新 step 但 ci.yml 冇跟（兩邊唔等價）③「失敗匯總」被改成吞掉
#    （**假綠**）④ hook 唔再叫 check-all.sh（閘形同虛設）⑤ 探針守門本身冇 mutant（TMO-066 嘅教訓）。
# → 本檔用**雙向對齊**（ci.yml ↔ 本機 runner）+ **行為自證**（LC-8 真跑一次）鎖住佢；
#   守門探針嘅 mutant 列：`LC-M1`（見 `scripts/ci/mutants.tsv`）。
# 探針名全用 ASCII：bash 3.2 + UTF-8 locale 下 bats 會**靜默丟棄** CJK 名 → 假綠（見 PNA-1）。

load 'helpers/test-env'

setup() {
  CHECK_ALL="$REPO_ROOT/scripts/check-all.sh"
  HOOK_SRC="$REPO_ROOT/scripts/hooks/pre-push.sh"
  INSTALLER="$REPO_ROOT/scripts/install-local-hooks.sh"
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
  MUTANTS="$REPO_ROOT/scripts/ci/mutants.tsv"
  export CHECK_ALL HOOK_SRC INSTALLER CI_YML MUTANTS
}

@test "LC-1: the new files exist, pass bash -n, are shellcheck clean and have a mutant row" {
  local f
  for f in "$CHECK_ALL" "$HOOK_SRC" "$INSTALLER"; do
    [ -f "$f" ] || { echo "FAIL: 搵唔到 $f" >&2; return 1; }
    bash -n "$f" || { echo "FAIL: bash -n 紅：$f" >&2; return 1; }
  done
  if command -v shellcheck >/dev/null 2>&1; then
    run shellcheck -x -S style "$CHECK_ALL" "$HOOK_SRC" "$INSTALLER"
    [[ "$status" -eq 0 ]] || {
      echo "FAIL: shellcheck 有錯（CI 用 -S style，唔可以只做到 warning）：" >&2
      echo "$output" >&2
      return 1
    }
  else
    echo "注意：本機冇 shellcheck → 呢次**冇驗** shellcheck（CI 兩條腿都會驗；建議本機裝：brew install shellcheck）" >&2
  fi
  local row
  row="$(grep -F 'scripts/check-all.sh' "$MUTANTS" | grep -v '^#')"
  [[ -n "$row" ]] || {
    echo "FAIL: scripts/ci/mutants.tsv 冇 check-all.sh 嘅列 → 呢個閘冇人守" >&2
    return 1
  }
  printf '%s\n' "$row" | grep -qF 'tests/local-ci-guard.bats' || {
    echo "FAIL: 嗰列嘅探針唔係 tests/local-ci-guard.bats" >&2; return 1; }
}

@test "LC-2: the local runner must not contain fail-open patterns" {
  # ⚠️ 剝走「行首 # 嘅整行註解」先掃（做法同 MLG-2 一致）：否則註解入面解釋
  #    「點解唔可以有 || true」嘅句子會自我命中 → 假紅。
  local code n
  code="$(grep -vE '^[[:space:]]*#' "$CHECK_ALL")"
  [[ -n "$code" ]] || { echo "FAIL: 剝註解後 check-all.sh 變空（抽取邏輯壞咗）" >&2; return 1; }
  n="$(printf '%s\n' "$code" | grep -cE '\|\|[[:space:]]*true|set[[:space:]]+\+e|continue-on-error')" || n=0
  [[ "$n" -eq 0 ]] || {
    echo "FAIL: check-all.sh 有 fail-open 寫法（|| true／set +e／continue-on-error）→ 失敗會被吞 → 假綠" >&2
    printf '%s\n' "$code" | grep -nE '\|\|[[:space:]]*true|set[[:space:]]+\+e|continue-on-error' >&2
    return 1
  }
}

@test "LC-3: --list prints one tab-separated row per step and the runner really runs a step" {
  run bash "$CHECK_ALL" --list
  [[ "$status" -eq 0 ]] || { echo "FAIL: --list 唔係 0 退出" >&2; return 1; }
  local n
  n="$(printf '%s\n' "$output" | grep -c .)" || n=0
  [[ "$n" -ge 10 ]] || {
    echo "FAIL: --list 只有 $n 行（預期 >= 10；少過就代表有步驟冇被登記）" >&2
    return 1
  }
  local line fields
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    fields="$(printf '%s\n' "$line" | awk -F'\t' '{print NF}')"
    [[ "$fields" -eq 3 ]] || {
      echo "FAIL: --list 某行唔係 3 欄（id/ci-ref/label）：$line" >&2
      return 1
    }
  done <<< "$output"
  # 順帶證明 runner 真係跑得到（唔止格式啱）
  run bash "$CHECK_ALL" --only heredoc
  [[ "$status" -eq 0 ]] || {
    echo "FAIL: --only heredoc 唔係 0 退出（runner 壞咗）：" >&2
    echo "$output" >&2
    return 1
  }
}

@test "LC-4: every ci.yml step is covered locally and every local step exists in ci.yml" {
  local ci_names
  ci_names="$(grep -E '^[[:space:]]*- name: ' "$CI_YML" \
    | sed -E 's/^[[:space:]]*- name:[[:space:]]*//' | LC_ALL=C sort -u)"
  [[ -n "$ci_names" ]] || { echo "FAIL: 由 ci.yml 抽唔到 step 名" >&2; return 1; }

  local local_refs
  local_refs="$(bash "$CHECK_ALL" --list | cut -f2 | tr '|' '\n' | sed '/^$/d' | LC_ALL=C sort -u)"
  [[ -n "$local_refs" ]] || { echo "FAIL: 本機 runner 冇報任何 ci-ref" >&2; return 1; }

  # ① CI 有、本機冇。Checkout / Setup Python 係**純環境**步驟（拉 code／裝 python），本機唔重演
  #    → 明確豁免。改名咗就要更新呢個豁免（刻意 fail-closed）。
  local missing
  missing="$(LC_ALL=C comm -23 \
    <(printf '%s\n' "$ci_names" | grep -v -x -E 'Checkout|Setup Python') \
    <(printf '%s\n' "$local_refs"))"
  [[ -z "$missing" ]] || {
    echo "FAIL: ci.yml 有呢啲 step，但本機 runner 冇對應 → 會出現『本機跑咗但 CI 冇跑』嘅假覆蓋：" >&2
    printf '%s\n' "$missing" >&2
    return 1
  }

  # ② 本機有、CI 冇（ci-ref 名打錯／CI 改咗 step 名 → 兩邊唔等價）
  local extra
  extra="$(LC_ALL=C comm -13 \
    <(printf '%s\n' "$ci_names") \
    <(printf '%s\n' "$local_refs"))"
  [[ -z "$extra" ]] || {
    echo "FAIL: 本機 runner 嘅 ci-ref 喺 ci.yml 搵唔到（名打錯／CI 改咗 step 名）：" >&2
    printf '%s\n' "$extra" >&2
    return 1
  }
}

@test "LC-5: the local runner resolves markdownlint globs and doc-drift date from ci.yml" {
  run bash "$CHECK_ALL" --plan
  [[ "$status" -eq 0 ]] || { echo "FAIL: --plan 唔係 0 退出" >&2; return 1; }
  local md_line globs
  # ⚠️ 抽取條件要同 scripts/check-all.sh 一致（否則兩邊用唔同嘅 glob 去比 → 假綠）：
  #    `markdownlint-cli2` 喺 ci.yml 第一個出現嘅地方係 `npm install -g markdownlint-cli2`（冇 glob）
  #    → 一定要要求「同一行、命令後面有引號括住嘅 glob」。
  md_line="$(grep -E 'markdownlint-cli2[[:space:]]+".*"' "$CI_YML" | head -1)"
  [[ -n "$md_line" ]] || { echo "FAIL: 抽唔到 ci.yml 嘅 markdownlint 執行行" >&2; return 1; }
  globs="$(printf '%s\n' "$md_line" | grep -oE '"[^"]+"' | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  [[ -n "$globs" ]] || { echo "FAIL: 抽唔到 ci.yml 嘅 markdownlint glob" >&2; return 1; }
  [[ "$output" == *"$globs"* ]] || {
    echo "FAIL: --plan 嘅 markdownlint glob 同 ci.yml 唔一致（→ 本機 lint 嘅 glob ≠ CI）：" >&2
    echo "  ci.yml：$globs" >&2
    return 1
  }
  local d
  d="$(grep -F 'check-doc-drift.sh' "$CI_YML" | head -1 \
    | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
  [[ -n "$d" ]] || { echo "FAIL: 抽唔到 ci.yml 嘅 --from-date" >&2; return 1; }
  [[ "$output" == *"--from-date $d"* ]] || {
    echo "FAIL: --plan 嘅 --from-date 同 ci.yml 唔一致（→ 本機檢查嘅日期窗 ≠ CI）" >&2
    return 1
  }
}

@test "LC-6: the pre-push hook calls the local runner and the installer backs up an existing hook" {
  [ -f "$HOOK_SRC" ] || { echo "FAIL: 搵唔到 $HOOK_SRC" >&2; return 1; }
  grep -qF 'check-all.sh' "$HOOK_SRC" || {
    echo "FAIL: pre-push hook 冇叫 scripts/check-all.sh" >&2; return 1; }
  grep -qF 'SKIP_LOCAL_CI' "$HOOK_SRC" || {
    echo "FAIL: pre-push hook 冇支援 SKIP_LOCAL_CI（冇一次性繞過＝ debugging 時冇出路）" >&2
    return 1; }
  grep -qF 'exit "$rc"' "$HOOK_SRC" || {
    echo "FAIL: pre-push hook 冇用失敗碼退出（印個訊息就放行 ≠ 閘）" >&2; return 1; }
  [ -f "$INSTALLER" ] || { echo "FAIL: 搵唔到 $INSTALLER" >&2; return 1; }
  [ -f "$INSTALLER" ] || { echo "FAIL: 搵唔到 ${INSTALLER}（應該喺 scripts/，唔喺 scripts/ci/）" >&2; return 1; }
  grep -qF 'pre-push' "$INSTALLER" || {
    echo "FAIL: 安裝腳本冇提到 pre-push" >&2; return 1; }
  grep -qF 'chmod' "$INSTALLER" || {
    echo "FAIL: 安裝腳本冇 chmod +x（裝完唔會執行）" >&2; return 1; }
  grep -qF 'rm -f' "$INSTALLER" || {
    echo "FAIL: 安裝腳本冇俾移除指令" >&2; return 1; }
  grep -qF 'bak' "$INSTALLER" || {
    echo "FAIL: 安裝腳本冇備份原有 hook（會靜靜哋覆蓋用戶自己嘅 hook）" >&2; return 1; }
}

@test "LC-7: CONTRIBUTING documents the local CI command, hook install and bypass" {
  local c="$REPO_ROOT/CONTRIBUTING.md"
  grep -qF 'scripts/check-all.sh' "$c" || {
    echo "FAIL: CONTRIBUTING 冇寫本機 CI 等價指令" >&2; return 1; }
  grep -qF 'install-local-hooks.sh' "$c" || {
    echo "FAIL: CONTRIBUTING 冇寫 pre-push hook 安裝指令" >&2; return 1; }
  grep -qF 'SKIP_LOCAL_CI' "$c" || {
    echo "FAIL: CONTRIBUTING 冇寫一次性繞過方法" >&2; return 1; }
}

@test "LC-8: a failing step must make the whole run exit non-zero" {
  # 行為自證（唔係靜態文字鎖）：用只會令嘢變紅嘅 seam 強制一個步驟失敗，
  # 然後要求**整體**退出碼非 0。mutant `LC-M1` 就係改呢個行為 → 必須令本探針轉紅。
  run env LOCAL_CI_SELF_TEST_FAIL=deps bash "$CHECK_ALL" --only deps
  [[ "$status" -ne 0 ]] || {
    echo "FAIL: 有步驟失敗，但整體仍然退出 0 → 失敗被吞掉（假綠）" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"SELF-TEST"* ]] || {
    echo "FAIL: 預期 SELF-TEST 標記（否則紅嘅可能係『本機缺工具』而唔係 seam 生效）：" >&2
    echo "$output" >&2
    return 1
  }
}

@test "LC-9: the pre-push hook really blocks a failing gate and the installer really backs up" {
  # 行為自證（唔係 grep 文字鎖）：AC05 聲稱嘅「紅就擋 push」「唔會靜靜哋覆蓋原有 hook」
  # 之前**從未被執行過** → 呢支探針喺 temp git repo 真正跑一次。
  local tmp="$BATS_TEST_TMPDIR/hookrepo"
  mkdir -p "$tmp/scripts/hooks"
  cp "$HOOK_SRC" "$tmp/scripts/hooks/pre-push.sh"
  # ① 假嘅 runner（必定失敗）→ pre-push hook 必須擋（exit ≠ 0）
  printf '#!/usr/bin/env bash\necho "故意失敗" >&2\nexit 1\n' > "$tmp/scripts/check-all.sh"
  chmod +x "$tmp/scripts/check-all.sh"
  ( cd "$tmp" && git init -q )
  # ⚠️ 必須喺 fake repo 入面行（hook 用 `git rev-parse --show-toplevel` 搵 repo root）：
  #    喺外層 repo 行 → hook 會攞到**真** repo 嘅 check-all.sh → 測嘅唔係假 runner（假綠）
  run bash -c "cd '$tmp' && bash scripts/hooks/pre-push.sh"
  [[ "$status" -ne 0 ]] || {
    echo "FAIL: 閘紅但 pre-push hook 唔擋（exit 0）→ hook 形同虛設" >&2
    echo "$output" >&2
    return 1
  }
  # ② 安裝器對住一個已存在嘅（用戶自己嘅）hook → 必須備份，而且原檔內容要喺備份入面
  local existing="$tmp/.git/hooks/pre-push"
  printf '#!/usr/bin/env bash\necho mine\n' > "$existing"
  chmod +x "$existing"
  ( cd "$tmp" && bash "$INSTALLER" ) > "$tmp/install.out" 2>&1
  local rc=$?
  [[ "$rc" -eq 0 ]] || {
    echo "FAIL: 安裝器唔係 0 退出（${rc}）：" >&2
    cat "$tmp/install.out" >&2
    return 1
  }
  local bak
  bak="$(ls "$tmp"/.git/hooks/pre-push.bak.* 2>/dev/null | head -1)"
  [[ -n "$bak" ]] || {
    echo "FAIL: 安裝器冇備份原有 hook（會靜靜哋覆蓋用戶自己嘅 hook）" >&2
    cat "$tmp/install.out" >&2
    return 1
  }
  grep -qF 'echo mine' "$bak" || {
    echo "FAIL: 備份內容唔係原本嗰個 hook" >&2; return 1; }
  grep -qF 'tree_monstor-local-ci-gate-v1' "$existing" || {
    echo "FAIL: 裝完 .git/hooks/pre-push 唔係本 repo 嘅 hook" >&2; return 1; }
}
