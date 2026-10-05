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
#   1. requirements.txt 涵蓋 PoC 腳本所有非 stdlib import（TMO-038 起：AST 遞迴掃描——
#      含縮排的函式內 import 與子目錄 .py；optional 依賴靠原始碼行內 `PoC-OPTIONAL-DEP` 標記）
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
# 記錄每個呼叫到 ${SHIM_LOG}；被要求 `-m venv <dir>` 時偽造出 <dir>/bin/python（同樣會記錄）。
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

@test "POC-BOOTSTRAP: requirements.txt covers non-stdlib imports (recursive AST scan, TMO-038)" {
  # TMO-038 ①：改用 AST 遞迴掃描（舊版 grep `^(import|from)` 只看第 0 欄、只看同目錄；
  # 函式內 optional import 與子目錄 .py 會漏抓）。optional 依賴靠原始碼行內標記
  # `PoC-OPTIONAL-DEP` 自我說明，並有反向鎖（標記只能落在 import/from 行）。
  local req="$POC_DIR/requirements.txt"
  [ -f "$req" ] || {
    echo "FAIL: 缺 ${req}（clean clone 無法重建 venv）" >&2
    return 1
  }

  cat > "$BATS_TEST_TMPDIR/scan-imports.py" <<'PY'
import ast, pathlib, re, sys

root = pathlib.Path(sys.argv[1])
req_text = pathlib.Path(sys.argv[2]).read_text()
OPTIONAL = "PoC-OPTIONAL-DEP"

# module → 發行套件名（import 名與 PyPI 名不同者）
DIST = {
    "yaml": "PyYAML", "PIL": "Pillow", "cv2": "opencv-python", "bs4": "beautifulsoup4",
    "docx": "python-docx", "pptx": "python-pptx", "sklearn": "scikit-learn",
    "dateutil": "python-dateutil", "fitz": "PyMuPDF", "dotenv": "python-dotenv",
    "jwt": "PyJWT", "OpenSSL": "pyOpenSSL", "serial": "pyserial", "magic": "python-magic",
}
# 映射表自我測試（防空過／防被掏空）
assert DIST["yaml"] == "PyYAML" and DIST["PIL"] == "Pillow" and DIST["cv2"] == "opencv-python", "DIST 映射表壞掉"
assert len(DIST) >= 8, f"DIST 映射表太薄（{len(DIST)}）"

files = [p for p in sorted(root.rglob("*.py"))
         if not {".venv", "__pycache__"}.intersection(p.parts)]
if len(files) < 15:
    sys.exit(f"FAIL: 只掃到 {len(files)} 個 .py（遞迴掃描壞掉？防空過）")

local_mods = {p.stem for p in files}
stdlib = set(sys.stdlib_module_names)

sites, marker_lines = [], []
for f in files:
    text = f.read_text()
    for i, line in enumerate(text.split("\n"), 1):
        if OPTIONAL in line:
            marker_lines.append((f, i, line))
    for node in ast.walk(ast.parse(text, filename=str(f))):
        if isinstance(node, ast.Import):
            names = [a.name.split(".")[0] for a in node.names]
        elif isinstance(node, ast.ImportFrom):
            names = [node.module.split(".")[0]] if (node.level == 0 and node.module) else []
        else:
            continue
        src_line = text.split("\n")[node.lineno - 1]
        for m in names:
            sites.append((m, f, node.lineno, src_line))

if len(sites) < 20:
    sys.exit(f"FAIL: 只解析到 {len(sites)} 個 import 陳述（防空過）")

bad = [f"{f}:{i}" for f, i, line in marker_lines if not re.match(r"^\s*(import|from)\s", line)]
if bad:
    sys.exit(f"FAIL: {OPTIONAL} 標記只能在 import/from 行上（濫用）：{bad}")
if OPTIONAL not in req_text:
    sys.exit(f"FAIL: requirements.txt 未說明 {OPTIONAL} 機制（標記制必須可被發現，不得變成隱藏例外清單）")

reqs = {re.split(r"[\[=<>!~;\s]", l.split("#")[0].strip())[0].lower()
        for l in req_text.split("\n") if l.split("#")[0].strip()}

optional, required, missing = [], [], []
for m, f, n, line in sites:
    if m in stdlib or m in local_mods:
        continue
    if OPTIONAL in line:
        optional.append((m, str(f.relative_to(root))))
        continue
    dist = DIST.get(m, m)
    (required if dist.lower() in reqs else missing).append((m, dist, str(f.relative_to(root)), n))

if missing:
    for m, dist, rel, n in missing:
        print(f"FAIL: {rel}:{n} 匯入 {m}（套件 {dist}）但 requirements.txt 未列")
    sys.exit(1)
if len(required) < 2:
    sys.exit(f"FAIL: 只驗到 {len(required)} 個第三方依賴（防空過；預期 httpx + PyYAML）")
if not optional:
    sys.exit(f"FAIL: 掃到 0 個 {OPTIONAL} 標記 → playwright 的 lazy import 消失了？")

print(f"OK: 掃 {len(files)} 檔 / {len(sites)} 個 import；必要依賴 {sorted({d for _, d, _, _ in required})}；"
      f"optional {sorted({m for m, _ in optional})}（涵蓋縮排與子目錄）")
PY
  run python3 "$BATS_TEST_TMPDIR/scan-imports.py" "$POC_DIR" "$req"
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }
  echo "$output" >&2
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

  # 覆蓋不變式（reviewer P2-2）：用到 ${PY}（含經 fixture helper 間接使用）的測試數 == 有守門的測試數。
  # 靜態掃描（不重跑整個檔，省 78s）：新增 venv-dependent 測試忘記守門就會咬。
  # TMO-038 ④：helper 名稱不再硬編（原硬編 2 個 → 新增 helper 會漏抓）→
  # 先自動列舉「本檔內 body 用到 $PY 的 helper」，再把名單餵進偵測 awk。
  local helpers
  helpers=$(awk '
    /^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*\{/ { name=$1; sub(/\(\).*/, "", name); inb=1; used=0 }
    inb { if (index($0, "$PY") || index($0, "${PY}")) used=1 }
    inb && /^\}/ { if (used) print name; inb=0 }
  ' "$probe" | sort -u | paste -sd'|' -)
  [ -n "$helpers" ] || {
    echo "FAIL: 抽不到任何使用 \$PY 的 helper（防空過／抽取器壞掉）" >&2
    return 1
  }
  # 抽取器自我測試：need_poc_venv 必然在名單內（它用 [ -x "$PY" ] 判斷）
  case "$helpers" in
    *need_poc_venv*) ;;
    *) echo "FAIL: helper 抽取器沒抓到 need_poc_venv → 抽取邏輯壞了（helpers=${helpers}）" >&2
       return 1 ;;
  esac

  local counts with_py with_guard
  counts=$(HELPERS="$helpers" awk '
    BEGIN { n = split(ENVIRON["HELPERS"], H, "|") }
    /^@test /{
      if (seen) { if (b_py) n_py++; if (b_g) n_g++ }
      seen=1; b_py=0; b_g=0
    }
    {
      if (index($0, "$PY") || index($0, "${PY}")) b_py=1
      for (i = 1; i <= n; i++) if (index($0, H[i])) b_py=1
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
  # 以下全是「純字串壞值」資料（不會真的寫檔）→ 就地在該行標 TMP-OK 豁免鎖 1
  for bad in "/" "/tmp/" "//" "/tmp" "/tmp/.." "/tmp/../x" "/tmp/./venv" "/tmp/." "relative/path"; do  # TMP-OK
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

@test "POC-BOOTSTRAP: CI contract asserted semantically via PyYAML (TMO-038)" {
  [ -f "$CI_YML" ] || {
    echo "FAIL: 缺 $CI_YML" >&2
    return 1
  }
  # TMO-038 ⑤：字串斷言只看得到「有沒有出現該字串」，看不到結構與次序。
  # 這裡用 PyYAML 解成物件再斷言（trigger / 矩陣 / 步驟先後 / 不得吞錯）。
  # PyYAML 列在 requirements.txt，且 CI 的 `bats tests/` 排在 setup-venv.sh 之後 → CI 必有；
  # 本機找不到含 PyYAML 的 python 就**大聲紅＋給指令**（不 skip，避免假綠）。
  local py="" cand
  for cand in "$POC_DIR/.venv/bin/python" python3; do
    if command -v "$cand" >/dev/null 2>&1 && "$cand" -c 'import yaml' >/dev/null 2>&1; then
      py="$cand"
      break
    fi
  done
  [ -n "$py" ] || {
    echo "FAIL: 找不到含 PyYAML 的 python（本探針不做字串替代；請先跑 bash skills/regression-guard/PoC/setup-venv.sh）" >&2
    return 1
  }

  cat > "$BATS_TEST_TMPDIR/ci-contract.py" <<'PY'
import sys, yaml

d = yaml.safe_load(open(sys.argv[1]))
assert isinstance(d, dict), "workflow 不是 mapping"

# PyYAML 依 YAML 1.1：裸 `on` 會被解成 boolean True → 兩種鍵都認，但必須恰好一種
keys = [k for k in d if k is True or k == "on"]
assert len(keys) == 1, f"`on:` 鍵解析異常：{keys}"
trig = d[keys[0]]
assert isinstance(trig, dict), "`on:` 不是 mapping"
for k in ("workflow_dispatch", "push", "pull_request"):
    assert k in trig, f"trigger 缺 {k}（手動觸發 / push / PR 任一被拿掉都算契約破裂）"
for k in ("push", "pull_request"):
    br = trig[k].get("branches")
    assert isinstance(br, list), f"{k}.branches 不是清單：{br!r}"
    assert {"main", "master"} <= set(br), f"{k}.branches 少了 main/master：{br}"

jobs = d.get("jobs")
assert isinstance(jobs, dict) and len(jobs) >= 2, f"jobs 結構異常：{jobs!r}"
test_job = jobs.get("test")
assert isinstance(test_job, dict), "找不到 test job"
os = (test_job.get("strategy") or {}).get("matrix", {}).get("os")
assert os == ["ubuntu-latest", "macos-latest"], f"matrix.os 被改動（雙平台覆蓋失守）：{os!r}"

steps = test_job.get("steps")
assert isinstance(steps, list) and steps, "test job 沒有 steps"

def find(pat, exact=False):
    for i, s in enumerate(steps):
        run = (s or {}).get("run") or ""
        if (run.strip() == pat) if exact else (pat in run):
            return i, s
    return None, None

venv_i, venv_s = find("setup-venv.sh")
bats_i, bats_s = find("bats tests/", exact=True)
assert venv_i is not None, "找不到用 setup-venv.sh 建 venv 的步驟"
assert bats_i is not None, "找不到 `bats tests/` 步驟（精確比對 run）"
assert venv_i < bats_i, f"順序錯：venv 在第 {venv_i} 步、bats 在第 {bats_i} 步（bats 會全紅）"
for name, i, s in (("venv", venv_i, venv_s), ("bats", bats_i, bats_s)):
    assert not s.get("continue-on-error"), f"{name} 步驟掛了 continue-on-error（失敗不再擋）"
    assert "|| true" not in ((s.get("run") or "")), f"{name} 步驟用 || true 吞掉失敗"
    assert s.get("if") is None, f"{name} 步驟掛了 if: 條件（可被跳過）"
# TMO-041 ②：bats-core 必須兩平台都固定同一個 tag（apt/brew 版本會漂移 →
# 探針行為不保證等價），且 >= v1.14.0（本機版本，CI 對齊）。
def dep_step(os_name):
    for s in steps:
        nm = ((s or {}).get("name") or "")
        cond = ((s or {}).get("if") or "")
        if "dependencies" in nm and os_name in cond:
            return s
    return None

import re as _re

tags = {}
for os_name, key in (("Linux", "linux"), ("macOS", "macos")):
    st = dep_step(os_name)
    assert st is not None, f"找不到 {os_name} 的測試依賴安裝步驟"
    run = st.get("run") or ""
    m = _re.search(r"git clone --branch (\S+) --depth 1 "
                   r"https://github\.com/bats-core/bats-core\.git", run)
    assert m, f"{os_name} 步驟沒有固定版本的 bats-core clone：{run!r}"
    assert "bats-core/install.sh" in run, f"{os_name} 步驟沒真的安裝 clone 下來的 bats-core"
    tags[key] = m.group(1)
    if key == "linux":
        assert not _re.search(r"apt-get install[^\n]*\bbats\b(?!-core)", run), \
            "Linux 步驟仍在 apt 裝 distro bats（版本不受控）"
    else:
        assert "brew install bats-core" not in run, "macOS 仍用未固定的 brew bats-core"
assert tags["linux"] == tags["macos"], f"兩平台 bats 版本不同（等價性破裂）：{tags}"
ver = tuple(int(x) for x in tags["linux"].lstrip("v").split("."))
assert ver >= (1, 14, 0), f"bats 版本 {tags['linux']} 低於 v1.14.0（本機版本）"
print(f"OK: PyYAML 語意斷言——trigger={sorted(trig)}、matrix.os={os}、"
      f"venv(step {venv_i}) 早於 bats(step {bats_i})、皆無 continue-on-error/if/|| true、"
      f"bats-core 兩平台皆 {tags['linux']}")
PY
  run "$py" "$BATS_TEST_TMPDIR/ci-contract.py" "$CI_YML"
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }
  echo "$output" >&2
}

@test "POC-BOOTSTRAP: CI triggers on master and builds the PoC venv (string layer)" {
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
