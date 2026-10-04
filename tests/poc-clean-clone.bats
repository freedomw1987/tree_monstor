#!/usr/bin/env bats
#
# tests/poc-clean-clone.bats
#
# TMO-039：CI 首次真實執行（clean clone）紅了 34 條，但本機全綠。
# 根因不是程式邏輯，而是「只有作者機器才成立的假設」。本檔把三類假設各鎖一條，
# 外加兩條 CI 環境契約，讓「本機綠、CI 紅」不可能再無聲發生。
#
#   1. CLEAN-POC-a — journeys/*.yaml 的 `source:` 必須能從 PoC/ 相對解析，且不得是絕對路徑
#   2. CLEAN-POC-b — PoC journeys/fixtures 內不得出現 /Users/ 、/home/ 等機器特定路徑
#   3. CLEAN-POC-c — 測試引用到的 fixtures/journeys 必須被 git 追蹤（clean clone 才拿得到）
#   4. CLEAN-POC-d — CI 兩個平台都必須安裝 ffmpeg（26 條媒體探針依賴）
#   5. CLEAN-POC-e — CI python-version 必須釘版（不得為浮動 3.x）
#   6. CLEAN-POC-f — 所有 oracle 相關探針檔都要能在 CI 等價環境（無 key／無暖快取／.env 已封）整檔跑綠
#   7. CLEAN-POC-g — CI 的 bash -n 必須用 glob 覆蓋全部 dav-wiki 腳本
#   8. CLEAN-POC-h — PoC/.env 與 PoC/cache/ 不得被 git 追蹤（真密鑰/本機快取外洩）
#   9. CLEAN-POC-i — JEV_ENV_FILE seam 真的能封掉本機 .env（否則 f 是假隔離）
#
# 為什麼需要 a/c：`journeys/US-101.yaml` 曾寫死
# `/Users/<作者>/…/docs/ac/US-101.md`，於是 5 條探針只在作者機器上過；
# `journeys/US-M62.yaml`、`fixtures/US-M63-*.py` 則被 gitignore 又沒有任何人產生它們
# → clean clone 必紅 5 條。

load 'helpers/test-env'

POC_DIR="$REPO_ROOT/skills/regression-guard/PoC"

# FAIL 訊息不得外洩密鑰（reviewer round-A P1：CLEAN-POC-i 的失敗訊息曾把本機真 key 印進 log）。
# 任何要 echo 出去的「被測程式輸出」都先過這一層。
mask_secrets() {
  sed -E 's/sk-[A-Za-z0-9_-]+/sk-***MASKED***/g'
}

@test "CLEAN-POC-a: every journey source resolves relative to PoC (no absolute path)" {
  cd "$REPO_ROOT"
  local journeys count bad=0 j src
  journeys=$(git ls-files 'skills/regression-guard/PoC/journeys/*.yaml')
  count=$(printf '%s\n' "$journeys" | grep -c . || true)
  # 防止探針空過：至少要看到 3 個 journey（US-101 / US-M62 / US-M63）
  [ "$count" -ge 3 ] || {
    echo "FAIL: 只找到 $count 個 journey，探針失效" >&2
    return 1
  }
  while IFS= read -r j; do
    [ -n "$j" ] || continue
    src=$(grep -m1 '^source:' "$j" | sed 's/^source:[[:space:]]*//')
    if [ -z "$src" ]; then
      echo "FAIL: $(basename "$j") 沒有 source: 欄位" >&2
      bad=1
    elif [[ "$src" == /* ]]; then
      echo "FAIL: $(basename "$j") 的 source 是絕對路徑（clean clone 必紅）：$src" >&2
      bad=1
    elif [ ! -f "$POC_DIR/$src" ]; then
      echo "FAIL: $(basename "$j") 的 source 解析不到：$POC_DIR/$src" >&2
      bad=1
    fi
  done <<< "$journeys"
  [ "$bad" -eq 0 ]
}

@test "CLEAN-POC-b: PoC journeys/fixtures contain no machine-specific absolute path" {
  cd "$REPO_ROOT"
  local hit files
  # 防空過（二審 P2-2）：素材目錄若被搬走/清空，grep 回非零會被 `|| true` 吞 → 靜默通過
  files=$(find skills/regression-guard/PoC/journeys skills/regression-guard/PoC/fixtures \
            -type f 2>/dev/null | wc -l | tr -d ' ')
  [ "$files" -ge 5 ] || {
    echo "FAIL: journeys/fixtures 只找到 $files 個檔（<5）→ 探針可能空過" >&2
    return 1
  }
  hit=$(grep -rlE '/Users/|/home/[a-z]' \
    skills/regression-guard/PoC/journeys \
    skills/regression-guard/PoC/fixtures 2>/dev/null || true)
  [ -z "$hit" ] || {
    echo "FAIL: 發現機器特定路徑，clean clone 會失效：" >&2
    echo "$hit" >&2
    return 1
  }
}

@test "CLEAN-POC-c: PoC fixtures/journeys referenced by tests are git-tracked" {
  cd "$REPO_ROOT"
  local refs missing=0 f
  # 抓「真正的路徑引用」：需有邊界（前面不是檔名字元）且檔名非空。
  # 舊版用 substring 正規表達式，會被 `cache-fixtures/README.md` 與 `$POC_DIR/fixtures/`
  # 這類字串誤抓成 `fixtures/README.md`、`fixtures/`（假陽性 → 探針誤紅）。
  refs=$(awk '
    {
      line = $0
      while (match(line, /(^|[^A-Za-z0-9._-])(fixtures|journeys)\/[A-Za-z0-9._-]+/)) {
        m = substr(line, RSTART, RLENGTH)
        sub(/^[^A-Za-z0-9._-]/, "", m)     # 去掉邊界字元（行首則不動）
        print m
        line = substr(line, RSTART + RLENGTH)
      }
    }' tests/v2.1-jev-poc.bats | sort -u)
  # 防止探針空過
  [ -n "$refs" ] || {
    echo "FAIL: 抓不到任何 fixture/journey 引用，探針失效" >&2
    return 1
  }
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if ! git ls-files --error-unmatch "skills/regression-guard/PoC/$f" >/dev/null 2>&1; then
      echo "FAIL: $f 未被 git 追蹤 → clean clone 缺檔，探針必紅" >&2
      missing=1
    fi
  done <<< "$refs"
  [ "$missing" -eq 0 ]
}

@test "CLEAN-POC-d: CI installs ffmpeg on both platforms (media probes)" {
  cd "$REPO_ROOT"
  local f=".github/workflows/ci.yml" linux_block mac_block
  linux_block=$(awk '/Install test dependencies \(Linux\)/,/^$/' "$f")
  mac_block=$(awk '/Install test dependencies \(macOS\)/,/^$/' "$f")
  [[ "$linux_block" == *ffmpeg* ]] || {
    echo "FAIL: Linux 安裝步驟沒有 ffmpeg（AC-A*/W*/V* 共 26 條會紅）" >&2
    return 1
  }
  [[ "$mac_block" == *ffmpeg* ]] || {
    echo "FAIL: macOS 安裝步驟沒有 ffmpeg" >&2
    return 1
  }
}

@test "CLEAN-POC-e: CI python-version is pinned (not floating 3.x)" {
  cd "$REPO_ROOT"
  local v
  v=$(grep -m1 'python-version:' .github/workflows/ci.yml \
    | sed "s/.*python-version:[[:space:]]*//; s/['\"]//g" | tr -d '[:space:]')
  [ -n "$v" ] || {
    echo "FAIL: ci.yml 找不到 python-version" >&2
    return 1
  }
  if [ "$v" = "3.x" ] || [ "$v" = "3" ]; then
    echo "FAIL: python-version floating: $v (pin an exact minor, e.g. 3.12)" >&2
    return 1
  fi
}

@test "CLEAN-POC-f: every oracle-dependent probe file runs offline (no key, no warm cache)" {
  # TMO-039 第二輪：M5-runtime-b / M6-g / M6.1-c 原本會呼叫真 Jev oracle，
  # 本機有 OPENROUTER_API_KEY + PoC/cache（8206 檔，未版控）所以全綠；
  # CI 兩者皆無 → oracle 抛錯 → 3 條紅。
  #
  # TMO-045（reviewer P2-B/P2-D）把這道鎖從「點名 3 條」改成一般化：
  #   ① 動態挑出所有提到 oracle 的測試檔（新檔自動納入，不是寫死名單）
  #   ② 每檔「整檔」在 CI 等價環境下重跑（不再用 --filter 點名）
  #   ③ 加 JEV_ENV_FILE=/dev/null → 連本機 PoC/.env 與 ~/.claude/.../.env 也擋掉，
  #      否則本機 key 會把 fixture 缺口掩蓋成假綠
  cd "$REPO_ROOT"
  local run_json cache_dir n empty_cache
  run_json="skills/regression-guard/PoC/fixtures/US-101-run.json"
  cache_dir="skills/regression-guard/PoC/cache-fixtures"
  # 離線 fixture 必須版控（clean clone 才拿得到）
  git ls-files --error-unmatch "$run_json" >/dev/null 2>&1 || {
    echo "FAIL: $run_json 未被 git 追蹤 → clean clone 沒這個檔" >&2
    return 1
  }
  n=$(git ls-files "$cache_dir" | grep -c '\.json$' || true)
  [ "$n" -ge 1 ] || {
    echo "FAIL: $cache_dir 內沒有被版控的 *.json → 離線快取 fixture 失效" >&2
    return 1
  }

  # 動態挑檔：排除本檔（護欄自身也含這些關鍵字）與 env-equivalence.bats
  # （TMO-041：env-equivalence.bats 是「跑別人」的 harness，本身就會用 CI 等價環境
  #   重跑 oracle 子集；巢狀重跑只會讓時間翻倍，其正確性由 ENV-EQ-7 直接驗。）
  local files=() f
  for f in tests/*.bats; do
    case "$f" in tests/poc-clean-clone.bats|tests/env-equivalence.bats) continue ;; esac
    grep -qE 'jev_oracle|fix_proposal|JEV_CACHE_DIR|JEV_ENV_FILE' "$f" || continue
    files+=("$f")
  done
  # 防空過：至少要挑到 1 檔
  [ "${#files[@]}" -ge 1 ] || {
    echo "FAIL: 沒挑到任何 oracle 相關測試檔 → 挑檔邏輯失效" >&2
    return 1
  }

  empty_cache="$BATS_TEST_TMPDIR/empty-cache"
  mkdir -p "$empty_cache"
  local total_ok=0 total_notok=0 out rc
  for f in ${files[@]+"${files[@]}"}; do
    out=$(env -u OPENROUTER_API_KEY HOME="$BATS_TEST_TMPDIR/nohome" \
          JEV_CACHE_DIR="$empty_cache" JEV_ENV_FILE=/dev/null \
          bats "$f" 2>&1)
    rc=$?
    local ok_n notok_n
    ok_n=$(printf '%s\n' "$out" | grep -c '^ok ' || true)
    notok_n=$(printf '%s\n' "$out" | grep -c '^not ok ' || true)
    total_ok=$((total_ok + ok_n))
    total_notok=$((total_notok + notok_n))
    # rc 也要 0（reviewer P2-2）：bats 硬崩（非逐條 fail）時可能一個 `not ok` 都沒有，
    # 只看 notok 計數會讓「整檔沒跑完」也變綠。
    if [ "$rc" -ne 0 ] || [ "$notok_n" -gt 0 ]; then
      echo "FAIL: $f 在 CI 等價環境（無 key／無暖快取／.env 已封）紅了（bats rc=$rc, not ok=$notok_n）：" >&2
      printf '%s\n' "$out" | grep -A5 '^not ok ' | mask_secrets >&2
      return 1
    fi
  done

  # 防空過：真的跑過足夠的探針
  [ "$total_ok" -ge 50 ] || {
    echo "FAIL: 只在離線環境跑了 $total_ok 條（<50）→ 探針可能空過" >&2
    return 1
  }
  [ "$total_notok" -eq 0 ] || return 1
}

@test "CLEAN-POC-h: no tracked secrets or cache under PoC (.env / cache/)" {
  # TMO-045（reviewer P2-C）：沒有任何探針阻止有人 `git add -f PoC/.env`（真密鑰）
  # 或 `git add -f PoC/cache/`（8206 個本機快取檔）——一旦進版控就是永久洩漏/帳單暴增。
  # 本條把「不得被追蹤」寫成鎖。
  cd "$REPO_ROOT"

  # 正對照：確認檢查機制本身能用（避免「什麼都掃不到 → 空過」）
  local tracked_total poc_tracked
  tracked_total=$(git ls-files | wc -l | tr -d ' ')
  [ "$tracked_total" -ge 200 ] || {
    echo "FAIL: git ls-files 只有 $tracked_total 個檔 → 檢查機制失效" >&2
    return 1
  }
  poc_tracked=$(git ls-files skills/regression-guard/PoC | wc -l | tr -d ' ')
  [ "$poc_tracked" -ge 10 ] || {
    echo "FAIL: PoC 只有 $poc_tracked 個檔案被追蹤（<10）→ 檢查機制失效" >&2
    return 1
  }
  # 正錨點：.env.example 必須在版控
  git ls-files --error-unmatch "skills/regression-guard/PoC/.env.example" >/dev/null 2>&1 || {
    echo "FAIL: PoC/.env.example 未被追蹤（範本應該進版控）" >&2
    return 1
  }

  local hit
  hit=$(git ls-files | grep -E '^skills/regression-guard/PoC/(\.env|\.env\.local)$|^skills/regression-guard/PoC/cache/' || true)
  if [ -n "$hit" ]; then
    echo "FAIL: 以下機敏/本機檔案被 git 追蹤（必須 git rm --cached + 保留 .gitignore）：" >&2
    printf '%s\n' "$hit" >&2
    return 1
  fi

  # 第二道：.gitignore 必須真的擋著（免得下次被 `git add -A` 掃進去）
  local gi="skills/regression-guard/PoC/.gitignore"
  grep -qxF '.env' "$gi" || { echo "FAIL: $gi 少了 .env 規則" >&2; return 1; }
  grep -qxF 'cache/' "$gi" || { echo "FAIL: $gi 少了 cache/ 規則" >&2; return 1; }
}

@test "CLEAN-POC-i: JEV_ENV_FILE seam actually neutralizes local .env" {
  # TMO-045（reviewer P2-B）：CLEAN-POC-f 原有的清環境手段對 `.env` 無效——
  # `_load_api_key()` 讀的是「檔案系統上固定位置」的 .env，不受 HOME/env -u 影響。
  # 本條驗證新加的 JEV_ENV_FILE seam 真的有效：假 .env 預設讀得到、覆寫 /dev/null 就讀不到。
  local py="$POC_DIR/.venv/bin/python"
  if [ ! -x "$py" ]; then
    echo "FAIL: 缺 PoC venv（$py）" >&2
    echo "  修法：bash skills/regression-guard/PoC/setup-venv.sh" >&2
    return 1
  fi
  local fake_env="$BATS_TEST_TMPDIR/fake.env"
  printf 'OPENROUTER_API_KEY=sk-fake-for-seam-test\n' > "$fake_env"
  cd "$POC_DIR"

  run env -u OPENROUTER_API_KEY JEV_ENV_FILE="$fake_env" \
      "$py" -c "import jev_oracle; print(jev_oracle._load_api_key())"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sk-fake-for-seam-test"* ]] || {
    echo "FAIL: JEV_ENV_FILE 指向假 .env 卻讀不到 key（seam 沒生效）" >&2
    return 1
  }

  run env -u OPENROUTER_API_KEY JEV_ENV_FILE=/dev/null \
      "$py" -c "import jev_oracle; print(repr(jev_oracle._load_api_key()))"
  [ "$status" -eq 0 ]
  [[ "$output" == *"''"* ]] || {
    echo "FAIL: JEV_ENV_FILE=/dev/null 仍讀到非空 key（值已遮罩：$(printf '%s' "$output" | mask_secrets)）→ 本機 .env 會造成假綠" >&2
    return 1
  }

  # 第二個來源（~/.claude/...）也要一起被蓋掉：seam 必須是「取代整份清單」，
  # 不是只擋 PoC/.env（否則修改只做半套，本機仍可能拿到 key）
  local fake_home="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$fake_home/.claude/skills/regression-guard/PoC"
  printf 'OPENROUTER_API_KEY=sk-fake-home\n' \
    > "$fake_home/.claude/skills/regression-guard/PoC/.env"
  run env -u OPENROUTER_API_KEY HOME="$fake_home" JEV_ENV_FILE=/dev/null \
      "$py" -c "import jev_oracle; print(repr(jev_oracle._load_api_key()))"
  [ "$status" -eq 0 ]
  [[ "$output" == *"''"* ]] || {
    echo "FAIL: ~/.claude/... 來源未被 seam 蓋掉（值已遮罩：$(printf '%s' "$output" | mask_secrets)）" >&2
    return 1
  }
}

@test "CLEAN-POC-g: CI syntax-checks every dav-wiki shell script (glob)" {
  # TMO-039：CI 原本只 `bash -n` 3 支寫死的腳本，其他 6 支（含本輪改到的
  # wiki-extract-video.sh）改了不會被擋。用 glob 才能隨新增腳本自動覆蓋。
  cd "$REPO_ROOT"
  local f=".github/workflows/ci.yml" n
  n=$(ls skills/dav-wiki/scripts/*.sh 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -ge 8 ] || {
    echo "FAIL: 只有 $n 支 dav-wiki 腳本（<8）→ 探針可能空過" >&2
    return 1
  }
  grep -qF 'skills/dav-wiki/scripts/*.sh' "$f" || {
    echo "FAIL: $f 的 bash -n 步驟沒有用 glob 覆蓋全部腳本（現有 $n 支）" >&2
    return 1
  }
}