#!/usr/bin/env bats
#
# tests/doc-facts.bats
#
# TMO-077：**文件自述數字**沒有守護，會靜默過期。
#
# 為什麼要這支：TMO-076 的 8 輪複審裡，late-round findings 幾乎全是「文件寫的數字與實況不符」——
# 我自己的交付摘要被抓 5 次（`11/11→12/12`、`最長 148→149`、`+4→+7`、`+7→+8`、`89 行→86 行`），
# 還有一支 skill 的自述行數（144→146）。**這些都不是探針能抓的「程式壞掉」，而是文件爛掉。**
#
# 設計（刻意保守，寧可少守也不要假咬）：
#   1. **只掃 live 文件**（README / CONTRIBUTING / skills/*/SKILL.md）。
#      `docs/deliverable/`、`changelog.md`、`*/CHANGELOG.md`、`docs/backlog.md` 是**歷史快照**，
#      它們記的是「當時的值」，本來就不該隨時間更新 → 一律不掃。
#   2. **只守「單位詞無歧義」的少數事實**（見下表）。不做通用「抓所有數字」——
#      那會把 `install-reference.md` 的「你自裝的 69 個 skills」這類**別人的**數字也抓進來。
#   3. `## 變動歷史` 段落內的數字是歷史列 → 跳過。
#
# | key | 掃描對象 | pattern | 真值來源 |
# |-----|---------|---------|---------|
# | 主檔自述行數 | `skills/*/SKILL.md` | `(本主檔目前\|目前主檔)…(\d+) 行` | 該檔 `wc -l` |
# | 子檔自述行數 | `skills/*/SKILL.md`（非變動歷史段）| `（(\d+) 行）…](./<子檔>.md)` | 該子檔 `wc -l` |
# | skill 數 | `README.md` | `(\d+) 個 skill` | `ls -d skills/*/` |
# | mutant 總數 | `CONTRIBUTING.md` | `(\d+) 支 mutant` / 同列含 `mutants.tsv` 的 `(\d+) 支` | `mutants.tsv` 資料列數 |
#
# 反假綠：① 找到的事實數 ≥ 4（掃不到就紅，不得空過）；② 每個 pattern 家族各自非空；
#         ③ `DOC-FACTS-2` 用壞 fixture 證明比對器真的會咬，且**好 fixture 必綠**。

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_ROOT
}

# 用法：_facts_check <root> [<min_facts>]
_facts_check() {
  python3 - "$1" "${2:-4}" <<'PYEOF'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
min_facts = int(sys.argv[2])

facts = []          # (位置, 文件寫的值, 真值, 原文片段)
families = {}       # 家族名 → 命中數


def add(fam, where, claimed, actual, snippet):
    families[fam] = families.get(fam, 0) + 1
    facts.append((where, claimed, actual, snippet))


# ---- 1/2：skills/*/SKILL.md 的自述行數 ----
skill_files = sorted(root.glob("skills/*/SKILL.md"))
for sf in skill_files:
    text = sf.read_text(encoding="utf-8")
    rel = sf.relative_to(root)
    lines = text.split("\n")
    # 主檔自述行數（跳過「## 變動歷史」段：段內是歷史列，寫「主檔 N 行」不算現況）
    # 注意：用 splitlines()（＝ wc -l 語義）；len(split("\n")) 會多算結尾換行後的空元素
    n_main = len(text.splitlines())
    in_hist_main = False
    for ln in lines:
        if ln.startswith("#"):
            in_hist_main = "變動歷史" in ln
            continue
        # 只跳「歷史表格列」（`|` 開頭）—— 整段跳會連段落之後的現況自述一起跳掉
        # （實例：dav-trust/SKILL.md 的「目前主檔 148 行」就落在 `## 變動歷史` 之後）
        if in_hist_main and ln.lstrip().startswith("|"):
            continue
        for m in re.finditer(r"(?:本主檔目前|目前主檔)[^\n]{0,12}?(\d+)\s*行", ln):
            add("skill_main_lines", f"{rel}:main", int(m.group(1)), n_main, m.group(0)[:40])
    # 子檔自述行數（跳過「## 變動歷史」段落）
    in_hist = False
    for i, ln in enumerate(lines, 1):
        if ln.startswith("#"):
            in_hist = "變動歷史" in ln
        if in_hist and ln.lstrip().startswith("|"):
            continue
        # 兩種寫法都吃：「（37 行）」與「共 506 行）」
        for m in re.finditer(r"(\d+) 行）[^\n]*\]\(\./([A-Za-z0-9._-]+\.md)\)", ln):
            sub = sf.parent / m.group(2)
            actual = len(sub.read_text(encoding="utf-8").splitlines()) if sub.is_file() else None
            add("subfile_lines", f"{rel}:{i}→{m.group(2)}", int(m.group(1)), actual, ln.strip()[:40])

# ---- 3：README 的 skill 數 ----
readme = root / "README.md"
if readme.is_file():
    skills_dir = root / "skills"
    count = len([d for d in skills_dir.glob("*/") if d.is_dir()]) if skills_dir.is_dir() else 0
    for m in re.finditer(r"(\d+)\s*個 skill", readme.read_text(encoding="utf-8")):
        add("skill_count", "README.md", int(m.group(1)), count, m.group(0))

# ---- 4：CONTRIBUTING 的 mutant 總數 ----
contrib = root / "CONTRIBUTING.md"
if contrib.is_file():
    mtsv = root / "scripts" / "ci" / "mutants.tsv"
    total = 0
    if mtsv.is_file():
        total = len([l for l in mtsv.read_text(encoding="utf-8").split("\n")
                     if l.strip() and not l.startswith("#")])
    for i, ln in enumerate(contrib.read_text(encoding="utf-8").split("\n"), 1):
        for m in re.finditer(r"(\d+)\s*支\s*mutant", ln):
            add("mutant_total", f"CONTRIBUTING.md:{i}", int(m.group(1)), total, ln.strip()[:40])
        if "mutants.tsv" in ln:
            for m in re.finditer(r"(\d+)\s*支", ln):
                add("mutant_tsv_count", f"CONTRIBUTING.md:{i}", int(m.group(1)), total, ln.strip()[:40])

# ---- 反假綠：事實數與家族覆蓋 ----
if len(facts) < min_facts:
    print(f"FAIL: 只找到 {len(facts)} 個可驗事實（< {min_facts}）→ 掃描退化，不得空過")
    sys.exit(1)

# 每個家族**各自**非空 —— 否則某個家族悄悄歸零（例如 README 改寫法）時，
# 總數仍可能 ≥ min_facts 而全綠，正是本檔自稱要防的退化。
EXPECTED_FAMILIES = ("skill_main_lines", "subfile_lines", "skill_count", "mutant_total")
missing_fam = [f for f in EXPECTED_FAMILIES if not families.get(f)]
if missing_fam:
    print(f"FAIL: 這些家族完全沒命中（掃描退化）：{', '.join(missing_fam)}")
    print(f"      命中統計：{families}")
    sys.exit(1)

bad = [f for f in facts if f[2] is None or f[1] != f[2]]
if bad:
    print(f"FAIL: {len(bad)} 處文件自述數字與實況不符：")
    for where, claimed, actual, snippet in bad:
        got = "檔案不存在" if actual is None else actual
        print(f"  - {where}: 文件寫 {claimed}，實際 {got}｜{snippet}")
    sys.exit(1)

print(f"OK: {len(facts)} 處自述數字全部與實況一致（家族：{', '.join(sorted(families))}）")
PYEOF
}

@test "DOC-FACTS-1: every self-reported number in live docs matches reality" {
  run _facts_check "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"OK:"* ]] || {
    echo "FAIL: 預期 OK 訊息，實際：$output" >&2
    return 1
  }
}

@test "DOC-FACTS-2: the checker itself bites (wrong number must be red, right one green)" {
  # 對照 GATE-SKILL-3／AC-4b／MLG-10b：新守護要有內建自證。
  local tmp="$BATS_TEST_TMPDIR/facts"
  mkdir -p "$tmp/skills/demo" "$tmp/scripts/ci"
  printf '# t\n\n1 個 skill\n' > "$tmp/README.md"
  printf '把 2 支 mutant 種回去\n' > "$tmp/CONTRIBUTING.md"
  printf 'a\nb\nc\n' > "$tmp/skills/demo/sub.md"
  printf -- '---\nname: demo\ndescription: d\n---\n\n## 說明\n\n本主檔目前 10 行。\n\n子檔（3 行）見 [sub](./sub.md)。\n' \
    > "$tmp/skills/demo/SKILL.md"
  printf 'M1\ta\tb\tc\td\nM2\ta\tb\tc\td\n' > "$tmp/scripts/ci/mutants.tsv"

  # ① 全部正確 → 必須綠
  run _facts_check "$tmp" 4
  [ "$status" -eq 0 ] || { echo "FAIL: 全部正確的 fixture 竟紅（假咬）：$output" >&2; return 1; }

  # ② 子檔行數寫錯 → 必須紅並點名
  printf 'a\nb\nc\nd\n' > "$tmp/skills/demo/sub.md"
  run _facts_check "$tmp" 4
  [ "$status" -ne 0 ] || { echo "FAIL: 子檔行數不符竟通過" >&2; return 1; }
  [[ "$output" == *"sub.md"* ]] || { echo "FAIL: 應點名 sub.md：$output" >&2; return 1; }

  # ③ mutant 總數寫錯 → 必須紅
  printf 'a\nb\nc\n' > "$tmp/skills/demo/sub.md"
  printf '把 9 支 mutant 種回去\n' > "$tmp/CONTRIBUTING.md"
  run _facts_check "$tmp" 4
  [ "$status" -ne 0 ] || { echo "FAIL: mutant 總數不符竟通過" >&2; return 1; }

  # ③b 歷史表格列要跳過，但**段落之後的現況自述行不能一起跳**（本次二審抓到的覆蓋縮減）
  # ③b 兩個方向都要驗（fixture SKILL.md 為 16 行）：
  #   ① 歷史表格列寫成**會命中 pattern** 的形態（`目前主檔 999 行`）→ 必須被跳過 ⇒ 綠
  #      （若歷史列不寫成會命中的形態，「不跳過也不會紅」＝ 這條守護無法被破壞，等於沒驗）
  #   ② 段落**之後**的現況自述行寫錯值 → 必須紅 ⇒ 證明它沒被一起跳掉（覆蓋縮減）
  printf '# t\n\n1 個 skill\n' > "$tmp/README.md"
  printf '把 2 支 mutant 種回去\n' > "$tmp/CONTRIBUTING.md"
  local head='---\nname: demo\ndescription: d\n---\n\n## 變動歷史\n\n| v1.0 | 目前主檔 999 行 |\n\n---\n\n'
  printf -- "${head}**⚠️ 主檔行數預警**：目前主檔 16 行\n\n## 說明\n\n子檔（3 行）見 [sub](./sub.md)。\n" \
    > "$tmp/skills/demo/SKILL.md"
  run _facts_check "$tmp" 4
  [ "$status" -eq 0 ] || {
    echo "FAIL: 歷史表格列被誤抓（應跳過）→ 假紅：$output" >&2
    return 1
  }
  printf -- "${head}**⚠️ 主檔行數預警**：目前主檔 999 行\n\n## 說明\n\n子檔（3 行）見 [sub](./sub.md)。\n" \
    > "$tmp/skills/demo/SKILL.md"
  run _facts_check "$tmp" 4
  [ "$status" -ne 0 ] || {
    echo "FAIL: 歷史段之後的現況自述行被一起跳掉（覆蓋縮減）" >&2
    return 1
  }
  [[ "$output" == *"main"* ]] || { echo "FAIL: 應點名主檔自述：$output" >&2; return 1; }

  # ④ 事實數不足 → 必須紅（防空過）
  printf '# t\n\n沒有數字\n' > "$tmp/README.md"
  printf '沒有數字\n' > "$tmp/CONTRIBUTING.md"
  printf -- '---\nname: demo\ndescription: d\n---\n\n## 說明\n\n沒有數字\n' > "$tmp/skills/demo/SKILL.md"
  run _facts_check "$tmp" 4
  [ "$status" -ne 0 ] || { echo "FAIL: 找不到事實竟通過（空過）" >&2; return 1; }
}
