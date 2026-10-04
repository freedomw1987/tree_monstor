#!/usr/bin/env bats
#
# tests/poc-bootstrap.bats
#
# TMO-029：regression-guard PoC 的「可重建性」守門。
#
# 背景：clean clone（沒有 skills/regression-guard/PoC/.venv）時
# `tests/v2.1-jev-poc.bats` 裡 venv-dependent 的 **38 / 98 條**會以 `No such file or directory`
# (127) 失敗（其餘 60 條是純靜態檔案檢查、不需 venv），
# repo 內卻沒有任何 requirements / setup 腳本，CI 也從未安裝 httpx / PyYAML
# → 「怎麼把環境建起來」只存在于某人腦中。
#
# 本檔守七件事（全部可證偽）：
#   1. requirements.txt 涵蓋 PoC 腳本所有非 stdlib import（防未來新增依賴又沒寫進檔案）
#   2. setup-venv.sh 存在、可執行、語法正確、且從 requirements.txt 安裝
#   3. setup-venv.sh 不硬依賴 uv（uv 沒有時退回 python3 -m venv）
#   4. 缺 venv 時 `v2.1-jev-poc.bats` 必須「大聲紅 + 給出修復指令」，且不得 skip
#   5. CI 必須在 master 觸發、且用 setup-venv.sh 建 PoC venv
#   6. `.venv` 必須被 gitignore（否則 fallback 建的 venv 會漏進版控）
#   7. setup-venv.sh 對可疑的 `POC_VENV_DIR` 必須拒絕（含 `/`、`/tmp/`、`//`、`..` 等須等價寫法）
#
# 註: @test 名稱純英文（homebrew bats 1.14 對 CJK 測試名會靜默丟棄）

setup() {
  load 'helpers/test-env'
  POC_DIR="$REPO_ROOT/skills/regression-guard/PoC"
  CI_YML="$REPO_ROOT/.github/workflows/ci.yml"
}

# 假的 python3（供 ③/⑥ 真跑 fallback 分支，不碰真 venv、不需網路）：
# 記錄每個呼叫到 $SHIM_LOG；被要求 `-m venv <dir>` 時偽造出 <dir>/bin/python（同樣會記錄）。
# 用法：make_python3_shim <shim 目錄>
make_python3_shim() {
  local shim="$1"
  mkdir -p "$shim"
  cat > "$shim/python3" <<'SHIM'
#!/usr/bin/env bash
printf 'python3 %s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = "-m" ] && [ "$2" = "venv" ]; then
  mkdir -p "$3/bin"
  cat > "$3/bin/python" <<'INNER'
#!/usr/bin/env bash
printf 'venv-python %s\n' "$*" >> "$SHIM_LOG"
exit 0
INNER
  chmod +x "$3/bin/python"
fi
exit 0
SHIM
  chmod +x "$shim/python3"
}

@test "POC-BOOTSTRAP: requirements.txt covers column-0 non-stdlib imports in PoC scripts" {
  # 範圍聲明（reviewer P2-1）：本探針只掃「第 0 欄」的 import/from。
  # 縮排（函式內 optional import）與子目錄 .py 不在範圍 → TMO-038 處理。
  local req="$POC_DIR/requirements.txt"
  [ -f "$req" ] || {
    echo "FAIL: 缺 ${req}（clean clone 無法重建 venv）" >&2
    return 1
  }

  local stdlib
  stdlib=$(python3 -c "import sys; print(' '.join(getattr(sys, 'stdlib_module_names', ())))" 2>/dev/null || true)
  [ -n "$stdlib" ] || {
    echo "FAIL: 取不到 python3 stdlib 模組清單（需要 python >= 3.10）" >&2
    return 1
  }

  local mods
  mods=$(grep -hoE '^(import|from)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' "$POC_DIR"/*.py \
    | awk '{print $2}' | sort -u)
  [ -n "$mods" ] || {
    echo "FAIL: 抽不到任何 import（防空過）" >&2
    return 1
  }

  # 同目錄的本地模組（import ac_schema 之類）不是第三方依賴 → 排除
  local locals
  locals=$(cd "$POC_DIR" && ls ./*.py 2>/dev/null | sed 's|\./\(.*\)\.py|\1|' | tr '\n' ' ')

  local m dist found=0
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    case " $stdlib " in *" $m "*) continue ;; esac
    case " $locals " in *" $m "*) continue ;; esac
    case "$m" in
      yaml) dist="PyYAML" ;;
      PIL)  dist="Pillow" ;;
      *)    dist="$m" ;;
    esac
    if grep -qiE "^${dist}([[:space:]]|[=<>~]|$)" "$req"; then
      found=$((found + 1))
    else
      echo "FAIL: PoC 匯入 ${m}（套件名 ${dist}）但 requirements.txt 未列" >&2
      return 1
    fi
  done <<<"$mods"

  [ "$found" -ge 2 ] || {
    echo "FAIL: 只驗到 $found 個第三方依賴（防空過；預期 httpx + PyYAML）" >&2
    return 1
  }
  echo "OK: $found 個第三方依賴皆列於 requirements.txt" >&2
}

@test "POC-BOOTSTRAP: setup-venv.sh exists, is executable and installs from requirements.txt" {
  local sh="$POC_DIR/setup-venv.sh"
  [ -f "$sh" ] || {
    echo "FAIL: 缺 $sh" >&2
    return 1
  }
  [ -x "$sh" ] || {
    echo "FAIL: $sh 沒有可執行權限" >&2
    return 1
  }
  bash -n "$sh" || {
    echo "FAIL: $sh 語法錯誤" >&2
    return 1
  }
  grep -qE "requirements\.txt" "$sh" || {
    echo "FAIL: $sh 未從 requirements.txt 安裝（依賴會漂移）" >&2
    return 1
  }
}

@test "POC-BOOTSTRAP: setup-venv.sh falls back to python3 -m venv when uv is absent" {
  local sh="$POC_DIR/setup-venv.sh"
  [ -f "$sh" ] || {
    echo "FAIL: 缺 $sh" >&2
    return 1
  }
  grep -qE 'command -v uv' "$sh" || {
    echo "FAIL: $sh 未偵測 uv（會硬依賴 uv）" >&2
    return 1
  }
  grep -qE '\-m venv' "$sh" || {
    echo "FAIL: $sh 沒有 python3 -m venv 的退路" >&2
    return 1
  }

  # 真跑一次 fallback 分支（reviewer P2-5）：PATH 只放 shim，uv 一定找不到。
  # 不需網路、不碰真 venv（靠 POC_VENV_DIR 導向暫存目錄）。
  local shim="$BATS_TEST_TMPDIR/shim" vdir="$BATS_TEST_TMPDIR/venv" log="$BATS_TEST_TMPDIR/calls.log"
  make_python3_shim "$shim"
  # 明示斷言本探針的環境假設（Round-3 P2-d）：/usr/bin:/bin 沒有 uv，否則 PATH 隔離失效
  if PATH="/usr/bin:/bin" command -v uv >/dev/null 2>&1; then
    echo "FAIL: 假設 /usr/bin:/bin 無 uv，實測卻有 → 本探針的 PATH 隔離失效" >&2
    return 1
  fi
  run env SHIM_LOG="$log" POC_VENV_DIR="$vdir" PATH="$shim:/usr/bin:/bin" bash "$sh"
  [ "$status" -eq 0 ] || {
    echo "FAIL: uv 缺席時 setup-venv.sh 應成功（rc=${status}）" >&2
    echo "$output" >&2
    return 1
  }
  grep -q -- '-m venv' "$log" || {
    echo "FAIL: 未實際呼叫 python3 -m venv（fallback 分支沒被走到）" >&2
    cat "$log" >&2
    return 1
  }
  grep -qE -- '-m pip install|-m ensurepip' "$log" || {
    echo "FAIL: fallback 分支未安裝依賴（pip/ensurepip 都沒被呼叫）" >&2
    cat "$log" >&2
    return 1
  }
}

@test "POC-BOOTSTRAP: every venv-dependent test carries the fail-loud guard" {
  local probe="$REPO_ROOT/tests/v2.1-jev-poc.bats"
  grep -qE 'need_poc_venv' "$probe" || {
    echo "FAIL: $probe 未使用 need_poc_venv（缺 venv 只會 127 噪音）" >&2
    return 1
  }

  # 覆蓋不變式（reviewer P2-2）：用到 $PY（含經 fixture helper 間接使用）的測試數 == 有守門的測試數。
  # 靜態掃描（不重跑整個檔，省 78s）：新增 venv-dependent 測試忘記守門就會咬。
  local counts with_py with_guard
  counts=$(awk '
    /^@test /{
      if (seen) { if (b_py) n_py++; if (b_g) n_g++ }
      seen=1; b_py=0; b_g=0
    }
    {
      if (index($0, "$PY") || index($0, "${PY}") || index($0, "make_us_m63_before") \
          || index($0, "make_m62_batch_report") || index($0, "make_us101_run")) b_py=1
      if (index($0, "need_poc_venv")) b_g=1
    }
    END { if (seen) { if (b_py) n_py++; if (b_g) n_g++ } ; print n_py, n_g }
  ' "$probe")
  with_py=$(echo "$counts" | awk '{print $1}')
  with_guard=$(echo "$counts" | awk '{print $2}')
  [ "$with_py" -ge 30 ] || {
    echo "FAIL: 只用 $with_py 條測試被判為 venv-dependent（防空過）" >&2
    return 1
  }
  [ "$with_py" -eq "$with_guard" ] || {
    echo "FAIL: venv-dependent 測試 $with_py 條、有守門 $with_guard 條（忘記守門 → 127 噪音會回來）" >&2
    return 1
  }

  # 假綠鎖（reviewer P2-4）：本檔不得再有 skip（修 TMO-029 前有 2 條永遠 skip）
  local skips
  skips=$(grep -cE '^[[:space:]]*skip ' "$probe" || true)
  [ "$skips" -eq 0 ] || {
    echo "FAIL: $probe 仍有 $skips 處 skip（永遠 skip = 假綠）" >&2
    return 1
  }

  # 方向 1（用 venv 的測試）：必須紅、必須講原因、必須給修復指令、不得 skip
  run env POC_PY="$BATS_TEST_TMPDIR/absent/bin/python" \
    bats "$probe" --filter "flaky-b:"
  [ "$status" -ne 0 ] || {
    echo "FAIL: 缺 venv 時竟回報成功（假綠）" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"缺 PoC venv"* ]] || {
    echo "FAIL: 缺 venv 的訊息未說明原因" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"setup-venv.sh"* ]] || {
    echo "FAIL: 缺 venv 的訊息未給出修復指令" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" != *"# skip"* ]] || {
    echo "FAIL: 缺 venv 被 skip（掩蓋問題）" >&2
    echo "$output" >&2
    return 1
  }

  # 方向 2（不需要 venv 的純靜態測試）：缺 venv 不得誤紅
  run env POC_PY="$BATS_TEST_TMPDIR/absent/bin/python" \
    bats "$probe" --filter "CI-a:"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 不需 venv 的靜態測試被連坐誤紅（假紅）" >&2
    echo "$output" >&2
    return 1
  }
}

@test "POC-BOOTSTRAP: .venv is gitignored so the non-uv fallback cannot leak files" {
  local gi="$POC_DIR/.gitignore"
  [ -f "$gi" ] || {
    echo "FAIL: 缺 ${gi}" >&2
    return 1
  }
  grep -qE '^\.venv/?$' "$gi" || {
    echo "FAIL: ${gi} 未列 .venv/（uv 建的 venv 自帶 .gitignore(*)，python3 -m venv 的沒有）" >&2
    return 1
  }
  run git -C "$REPO_ROOT" check-ignore -q "skills/regression-guard/PoC/.venv/bin/python"
  [ "$status" -eq 0 ] || {
    echo "FAIL: git 實際未忽略 PoC/.venv（git add -A 會誤收數千檔）" >&2
    return 1
  }
}

@test "POC-BOOTSTRAP: setup-venv.sh refuses dangerous POC_VENV_DIR values" {
  local sh="$POC_DIR/setup-venv.sh"
  # 故意不帶 --force：即使護欄壞掉，也只是一般建置失敗，不會真的 rm -rf
  # 壞值含「等價寫法」：`/tmp/` 與 `/tmp` 同義（Round-3 P1 的繞道）、`//` 與 `/` 同義、
  # `/tmp/..` 就是 `/`。
  local bad
  for bad in "/" "/tmp/" "//" "/tmp" "/tmp/.." "/tmp/../x" "/tmp/./venv" "/tmp/." "relative/path"; do
    run env POC_VENV_DIR="$bad" bash "$sh"
    [ "$status" -eq 1 ] || {
      echo "FAIL: POC_VENV_DIR=${bad} 未被擋（rc=${status}）" >&2
      echo "$output" >&2
      return 1
    }
    [[ "$output" == *"護欄"* ]] || {
      echo "FAIL: POC_VENV_DIR=${bad} 被拒但訊息未提護欄" >&2
      echo "$output" >&2
      return 1
    }
  done
  # 正向對照：深層路徑不得被誤擋 → 真的走到 fallback 建置（shim）而非護欄
  local shim="$BATS_TEST_TMPDIR/shim6" log="$BATS_TEST_TMPDIR/calls6.log"
  make_python3_shim "$shim"
  if PATH="/usr/bin:/bin" command -v uv >/dev/null 2>&1; then
    echo "FAIL: 假設 /usr/bin:/bin 無 uv，實測卻有 → 正向對照會走到 uv 而非 shim" >&2
    return 1
  fi
  run env SHIM_LOG="$log" POC_VENV_DIR="$BATS_TEST_TMPDIR/deep/venv" PATH="$shim:/usr/bin:/bin" \
    bash "$sh"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 深層路徑不應被拒（rc=${status}）" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" != *"護欄"* ]] || {
    echo "FAIL: 深層路徑被護欄誤擋（護欄過寬）" >&2
    echo "$output" >&2
    return 1
  }
}

@test "POC-BOOTSTRAP: setup-venv.sh runs the VENV_DIR guard before any destructive rm" {
  # Round-4 reviewer：護欄與 `rm -rf` 的先後次序目前只有人眼保證，加一條零風險靜態鎖。
  local sh="$POC_DIR/setup-venv.sh"
  local guard rm_line
  # 錨定行首：註解裡也出現過同樣字串（護欄說明引用了 `rm -rf "$VENV_DIR"`），用 ^ + 空白開頭排除註解
  guard="$(grep -nE '^[^#]*_reject_venv_dir "\$VENV_DIR"' "$sh" | head -1 | cut -d: -f1)"
  rm_line="$(grep -nE '^[[:space:]]*rm -rf "\$VENV_DIR"' "$sh" | head -1 | cut -d: -f1)"
  [ -n "$guard" ] && [ -n "$rm_line" ] || {
    echo "FAIL: 找不到護欄（line=${guard}）或 rm -rf（line=${rm_line}）→ 腳本結構已變，靜態鎖要跟著改" >&2
    return 1
  }
  [ "$guard" -lt "$rm_line" ] || {
    echo "FAIL: 護欄在第 ${guard} 行、rm -rf 在第 ${rm_line} 行 → 破壞性操作先於護欄" >&2
    return 1
  }
}

@test "POC-BOOTSTRAP: CI triggers on master and builds the PoC venv" {
  [ -f "$CI_YML" ] || {
    echo "FAIL: 缺 $CI_YML" >&2
    return 1
  }
  grep -qE 'branches: \[main, master\]' "$CI_YML" || {
    echo "FAIL: CI 未在 master 觸發（repo 預設分支是 master → CI 從不執行）" >&2
    return 1
  }
  grep -qE 'setup-venv\.sh' "$CI_YML" || {
    echo "FAIL: CI 未用 setup-venv.sh 建 PoC venv（v2.1-jev-poc 會全紅）" >&2
    return 1
  }
  if grep -qE 'dav-wiki-cleanup\.md' "$CI_YML"; then
    echo "FAIL: CI 仍指向已刪除的 docs/sop/handbook/dav-wiki-cleanup.md（沉默空過）" >&2
    return 1
  fi
}
