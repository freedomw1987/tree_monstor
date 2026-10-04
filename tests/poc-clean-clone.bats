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
  local hit
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
  refs=$({
    grep -o 'fixtures/[A-Za-z0-9._-]*' tests/v2.1-jev-poc.bats
    grep -o 'journeys/[A-Za-z0-9._-]*' tests/v2.1-jev-poc.bats
  } | sort -u)
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