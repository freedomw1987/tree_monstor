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
#
# 為什麼需要 a/c：`journeys/US-101.yaml` 曾寫死
# `/Users/<作者>/…/docs/ac/US-101.md`，於是 5 條探針只在作者機器上過；
# `journeys/US-M62.yaml`、`fixtures/US-M63-*.py` 則被 gitignore 又沒有任何人產生它們
# → clean clone 必紅 5 條。

load 'helpers/test-env'

POC_DIR="$REPO_ROOT/skills/regression-guard/PoC"

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

@test "CLEAN-POC-f: oracle-dependent probes run offline (no API key, no warm cache)" {
  # TMO-039 第二輪：M5-runtime-b / M6-g / M6.1-c 原本會呼叫真 Jev oracle，
  # 本機有 OPENROUTER_API_KEY + PoC/cache（8206 檔，未版控）所以全綠；
  # CI 兩者皆無 → oracle 抛錯 → 3 條紅。這條探針是「本機也能抓到」的鎖：
  # 把 env 清成 CI 一樣（no key、HOME 換掉、JEV_CACHE_DIR 指向空目錄），重跑那 3 條。
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
  empty_cache="$BATS_TEST_TMPDIR/empty-cache"
  mkdir -p "$empty_cache"
  run env -u OPENROUTER_API_KEY HOME="$BATS_TEST_TMPDIR/nohome" \
      JEV_CACHE_DIR="$empty_cache" \
      bats "$REPO_ROOT/tests/v2.1-jev-poc.bats" --filter "M5-runtime-b|M6-g:|M6.1-c"
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    echo "FAIL: oracle 相關探針在 CI 等價環境（無 key/無暖快取）紅了" >&2
    return 1
  }
  # 防空過：bats 必須真的跑到 3 條
  echo "$output" | grep -qE '^ok 3 ' || {
    echo "FAIL: 只跑了不是 3 條，探針失效" >&2
    echo "$output" >&2
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