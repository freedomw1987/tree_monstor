#!/usr/bin/env bats
#
# tests/poc-venv-guard.bats
#
# TMO-040（NYH-5 方案 A）：setup-venv.sh 的破壞性護欄。
#
# 背景：`POC_VENV_DIR` 由外部指定，而 `--force` 會 `rm -rf "$VENV_DIR"`。
# 舊護欄（TMO-029 Round-2/3）只擋「結構性壞值」——空、非絕對、少於兩層、結尾斜線、
# `.` / `..` / `//` 段；指到「結構合法但危險」的目錄（`$HOME` 本體、`/private/tmp`、
# `/usr`、`/etc` …）仍會**真的** `rm -rf`。reviewer 實測：`POC_VENV_DIR=$HOME --force`
# 會把家目錄砍掉。
#
# 本檔守三件事（全部可證偽）：
#   1. 危險清單：命中即拒（rc=1、訊息含「危險清單」），**`--force` 與 `--yes` 都不能繞過**
#   2. 自訂 `POC_VENV_DIR` + `--force`：需輸入目錄名二次確認（fail-closed——讀不到輸入、
#      輸入不符一律「不刪任何東西」就退出）；`--yes` 供非互動腳本豁免
#   3. 順序鎖：危險檢查與二次確認都必須排在 `rm -rf` **之前**
#
# 另有一條「不得過度阻擋」的正向對照（deep path、預設路徑 + `--force` 不需確認）。
#
# 註: @test 名稱純英文（homebrew bats 1.14 對 CJK 測試名會靜默丟棄）
# 註: 全程只用 $BATS_TEST_TMPDIR；不碰真 venv、不需網路、不對系統目錄做任何寫入。

setup() {
  load 'helpers/test-env'
  POC_DIR="$REPO_ROOT/skills/regression-guard/PoC"
  SH="$POC_DIR/setup-venv.sh"
  SHIM="$BATS_TEST_TMPDIR/shim"
  SHIM_LOG="$BATS_TEST_TMPDIR/calls.log"
  make_fake_python3 "$SHIM"
  # 假設測試用的 PATH 裡沒有 uv（否則會走 uv 分支、shim 不被呼叫，正向對照會失真）
  if PATH="/usr/bin:/bin" command -v uv >/dev/null 2>&1; then
    echo "FAIL: 假設 /usr/bin:/bin 無 uv，實測卻有 → 正向對照會走到 uv 而非 shim" >&2
    return 1
  fi
}

# 假的 python3：記錄呼叫；被要求 `-m venv <dir>` 時偽造 <dir>/bin/python。
# （與 tests/poc-bootstrap.bats 的 shim 同構；刻意各自持有，避免動到已綠的檔。）
make_fake_python3() {
  local shim="$1"
  mkdir -p "$shim"
  cat > "$shim/python3" <<'SHIM'
#!/usr/bin/env bash
printf 'python3 %s\n' "$*" >> "$SHIM_LOG"
if [ "$1" = "-m" ] && [ "$2" = "venv" ]; then
  mkdir -p "$3/bin"
  cat > "$3/bin/python" <<'INNER'
#!/usr/bin/env bash
exit 0
INNER
  chmod +x "$3/bin/python"
fi
exit 0
SHIM
  chmod +x "$shim/python3"
}

@test "POC-VENV-GUARD: danger-list paths are refused with a distinct message" {
  # 分兩類，因為兩層護欄的守備範圍不同：
  #  (a) 單層根目錄（`/usr`、`/etc`…）：已被「至少兩層」的結構護欄擋住 → 只斷言「被拒」。
  #  (b) 結構合法但危險（`/private/tmp`…、`$HOME`）：結構護欄放行，**只能**靠危險清單擋。
  #      這類就是 reviewer 實測會真的 rm -rf 的那批；訊息必包含「危險清單」才算真的擋下。
  # 刻意不帶 --force：即使護欄回歸壞掉，也只是走到建置（shim）→ rc=0 → 本條紅，
  # 不會真的 rm 任何系統目錄。
  local bad
  for bad in /usr /etc /var /opt /Library /System /Applications /Users /tmp; do  # TMP-OK: 純字串壞值資料，永不寫入（護欄就是要在寫入前擋掉它）
    run env SHIM_LOG="$SHIM_LOG" POC_VENV_DIR="$bad" PATH="$SHIM:/usr/bin:/bin" bash "$SH"
    [ "$status" -eq 1 ] || {
      echo "FAIL: POC_VENV_DIR=${bad} 未被任何一層護欄擋（rc=${status}）" >&2
      echo "$output" >&2
      return 1
    }
  done

  # (b) 結構合法 + 在危險清單 → 必須是「危險清單」擋的，不能只是別的原因失敗
  for bad in /private/tmp /private/var /private/etc; do  # TMP-OK: 同上，純字串壞值資料
    run env SHIM_LOG="$SHIM_LOG" POC_VENV_DIR="$bad" PATH="$SHIM:/usr/bin:/bin" bash "$SH"
    [ "$status" -eq 1 ] || {
      echo "FAIL: POC_VENV_DIR=${bad} 未被危險清單擋（rc=${status}）" >&2
      echo "$output" >&2
      return 1
    }
    [[ "$output" == *"危險清單"* ]] || {
      echo "FAIL: POC_VENV_DIR=${bad} 被拒但訊息未提「危險清單」（結構護欄不該擋它）" >&2
      echo "$output" >&2
      return 1
    }
  done
}

@test "POC-VENV-GUARD: \$HOME itself survives --force --yes (danger list beats both flags)" {
  # 最關鍵的安全鎖：reviewer 實測的實際事故路徑。
  # 用假 $HOME（在 $BATS_TEST_TMPDIR 內）——若護欄回歸壞掉，受害的只有這個暫存目錄，
  # sentinel 消失 → 本條紅，而真家目錄毫髮無傷。
  local fake="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$fake/Library" "$fake/Documents"
  echo keep > "$fake/sentinel.txt"
  echo keep > "$fake/Documents/sentinel.txt"

  run env HOME="$fake" POC_VENV_DIR="$fake" bash "$SH" --force --yes
  [ "$status" -eq 1 ] || {
    echo "FAIL: \$HOME 本體 + --force --yes 未被擋（rc=${status}）" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"危險清單"* ]] || {
    echo "FAIL: 被拒但訊息未提「危險清單」" >&2
    echo "$output" >&2
    return 1
  }
  [ -f "$fake/sentinel.txt" ] || {
    echo "FAIL: \$HOME 本體被 rm -rf 了（sentinel 消失）" >&2
    return 1
  }

  run env HOME="$fake" POC_VENV_DIR="$fake/Documents" bash "$SH" --force --yes
  [ "$status" -eq 1 ] || {
    echo "FAIL: \$HOME/Documents + --force --yes 未被擋（rc=${status}）" >&2
    echo "$output" >&2
    return 1
  }
  [ -f "$fake/Documents/sentinel.txt" ] || {
    echo "FAIL: \$HOME/Documents 被 rm -rf 了（sentinel 消失）" >&2
    return 1
  }
}

@test "POC-VENV-GUARD: custom dir + --force refuses to delete when stdin is closed (fail-closed)" {
  local dir="$BATS_TEST_TMPDIR/custom/venv"
  mkdir -p "$dir"
  echo keep > "$dir/sentinel.txt"

  # 不給 --yes、stdin 關閉（非互動）→ 必須「不刪就退出」，並教使用者怎麼修
  run env SHIM_LOG="$SHIM_LOG" POC_VENV_DIR="$dir" PATH="$SHIM:/usr/bin:/bin" bash "$SH" --force </dev/null
  [ "$status" -eq 1 ] || {
    echo "FAIL: 讀不到確認輸入時應 rc=1，實得 rc=${status}" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"--yes"* ]] || {
    echo "FAIL: 訊息未提示 --yes 這個非互動豁免（使用者不知道怎麼修）" >&2
    echo "$output" >&2
    return 1
  }
  [ -f "$dir/sentinel.txt" ] || {
    echo "FAIL: 確認失敗卻仍刪了目錄（應 fail-closed）" >&2
    return 1
  }
}

@test "POC-VENV-GUARD: custom dir + --force needs the exact dir name typed" {
  local dir="$BATS_TEST_TMPDIR/named/venv"
  local log="$SHIM_LOG"
  mkdir -p "$dir"
  echo keep > "$dir/sentinel.txt"

  # ① 輸入不符 → 不刪
  run bash -c "printf '%s\n' wrong | POC_VENV_DIR='$dir' PATH='$SHIM:/usr/bin:/bin' SHIM_LOG='$log' bash '$SH' --force"
  [ "$status" -eq 1 ] || {
    echo "FAIL: 目錄名不符時應 rc=1，實得 rc=${status}" >&2
    echo "$output" >&2
    return 1
  }
  [ -f "$dir/sentinel.txt" ] || {
    echo "FAIL: 目錄名不符卻仍刪了目錄" >&2
    return 1
  }

  # ② 輸入正確（目錄名 venv）→ 真的重建
  run bash -c "printf '%s\n' venv | POC_VENV_DIR='$dir' PATH='$SHIM:/usr/bin:/bin' SHIM_LOG='$log' bash '$SH' --force"
  [ "$status" -eq 0 ] || {
    echo "FAIL: 目錄名正確時應 rc=0，實得 rc=${status}" >&2
    echo "$output" >&2
    return 1
  }
  [ ! -f "$dir/sentinel.txt" ] || {
    echo "FAIL: 確認通過卻沒有重建（sentinel 還在）" >&2
    return 1
  }
  [ -x "$dir/bin/python" ] || {
    echo "FAIL: 重建後缺 $dir/bin/python（shim 未被呼叫）" >&2
    echo "$output" >&2
    return 1
  }
}

@test "POC-VENV-GUARD: --force --yes still works for a legitimate custom dir (no over-blocking)" {
  local dir="$BATS_TEST_TMPDIR/legit/venv"
  mkdir -p "$dir"
  echo old > "$dir/sentinel.txt"

  run env SHIM_LOG="$SHIM_LOG" POC_VENV_DIR="$dir" PATH="$SHIM:/usr/bin:/bin" bash "$SH" --force --yes
  [ "$status" -eq 0 ] || {
    echo "FAIL: 合法自訂目錄 + --force --yes 應 rc=0，實得 rc=${status}" >&2
    echo "$output" >&2
    return 1
  }
  [ ! -f "$dir/sentinel.txt" ] || {
    echo "FAIL: --force 沒有真的移除既有目錄（sentinel 還在）" >&2
    return 1
  }
  [ -x "$dir/bin/python" ] || {
    echo "FAIL: 重建後缺 $dir/bin/python" >&2
    return 1
  }
}

@test "POC-VENV-GUARD: default dir + --force needs no confirmation (documented usage unchanged)" {
  # 把腳本與 requirements.txt 複製到暫存 PoC 目錄再跑，venv 才會落在暫存區
  # （絕不對 repo 內的真 .venv 做 rm -rf）。
  local fake="$BATS_TEST_TMPDIR/fakepoc"
  mkdir -p "$fake/.venv"
  cp "$SH" "$fake/setup-venv.sh"
  cp "$POC_DIR/requirements.txt" "$fake/requirements.txt"
  echo old > "$fake/.venv/sentinel.txt"

  # stdin 關閉：若預設路徑也要求二次確認，這裡會 fail-closed 紅
  run env SHIM_LOG="$SHIM_LOG" PATH="$SHIM:/usr/bin:/bin" bash "$fake/setup-venv.sh" --force </dev/null
  [ "$status" -eq 0 ] || {
    echo "FAIL: 預設路徑 + --force 應免確認（rc=${status}）" >&2
    echo "$output" >&2
    return 1
  }
  [ ! -f "$fake/.venv/sentinel.txt" ] || {
    echo "FAIL: 預設路徑 + --force 沒有真的重建" >&2
    return 1
  }
  [ -x "$fake/.venv/bin/python" ] || {
    echo "FAIL: 重建後缺 $fake/.venv/bin/python" >&2
    return 1
  }
}

@test "POC-VENV-GUARD: symlink ancestor cannot smuggle a dangerous target past the list" {
  # 繞道：`ln -s "$HOME" /tmp/alias` 後 `POC_VENV_DIR=/tmp/alias/Documents`——字面字串完全
  # 不在危險清單裡，但 `rm -rf` 會沿著連結刪到真目錄。靠 `pwd -P` 物理路徑比對堵。
  local fake="$BATS_TEST_TMPDIR/symhome"
  mkdir -p "$fake/Documents"
  echo keep > "$fake/Documents/sentinel.txt"
  ln -s "$fake" "$BATS_TEST_TMPDIR/alias"

  run env HOME="$fake" POC_VENV_DIR="$BATS_TEST_TMPDIR/alias/Documents" bash "$SH" --force --yes
  [ "$status" -eq 1 ] || {
    echo "FAIL: symlink 祖先繞道未被擋（rc=${status}）" >&2
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"危險清單"* ]] || {
    echo "FAIL: 被拒但訊息未提「危險清單」" >&2
    echo "$output" >&2
    return 1
  }
  [ -f "$fake/Documents/sentinel.txt" ] || {
    echo "FAIL: 沿著 symlink 把 HOME/Documents 刪了" >&2
    return 1
  }
}

@test "POC-VENV-GUARD: HOME with a trailing slash still matches the danger list" {
  # 繞道：`HOME=/Users/x/` 時 `$HOME` 字串帶尾斜線，`POC_VENV_DIR=/Users/x` 字面不相等
  # → 危險清單漏掉，直接 rm -rf 家目錄。
  local fake="$BATS_TEST_TMPDIR/slashhome"
  mkdir -p "$fake"
  echo keep > "$fake/sentinel.txt"

  run env HOME="$fake/" POC_VENV_DIR="$fake" bash "$SH" --force --yes
  [ "$status" -eq 1 ] || {
    echo "FAIL: HOME 帶尾斜線時危險清單漏掉家目錄（rc=${status}）" >&2
    echo "$output" >&2
    return 1
  }
  [ -f "$fake/sentinel.txt" ] || {
    echo "FAIL: 家目錄（假）被 rm -rf 了" >&2
    return 1
  }
}

@test "POC-VENV-GUARD: danger check and confirmation both run before the destructive rm" {
  # 動態測試證明「行為」，這條靜態鎖證明「次序」——把護欄搬到 rm 之後仍可能靠別的路徑
  # 通過其他測試（例如 --force 未觸發），次序鎖讓那種搬移立刻紅。
  local sh="$SH"
  local danger confirm rm_line
  danger="$(grep -nE '^[^#]*_reject_dangerous_venv_dir "\$VENV_DIR"' "$sh" | head -1 | cut -d: -f1)"
  confirm="$(grep -nE '^[^#]*read -r _answer' "$sh" | head -1 | cut -d: -f1)"
  rm_line="$(grep -nE '^[[:space:]]*rm -rf "\$VENV_DIR"' "$sh" | head -1 | cut -d: -f1)"
  [ -n "$danger" ] && [ -n "$confirm" ] && [ -n "$rm_line" ] || {
    echo "FAIL: 找不到危險檢查（line=${danger}）／二次確認（line=${confirm}）／rm -rf（line=${rm_line}）→ 腳本結構已變，次序鎖要跟著改" >&2
    return 1
  }
  [ "$danger" -lt "$rm_line" ] || {
    echo "FAIL: 危險清單檢查在第 ${danger} 行、rm -rf 在第 ${rm_line} 行 → 破壞性操作先於護欄" >&2
    return 1
  }
  [ "$confirm" -lt "$rm_line" ] || {
    echo "FAIL: 二次確認在第 ${confirm} 行、rm -rf 在第 ${rm_line} 行 → 未確認就刪" >&2
    return 1
  }
}
