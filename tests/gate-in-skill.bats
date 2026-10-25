#!/usr/bin/env bats
#
# tests/gate-in-skill.bats
#
# 為什麼有這支：
#   2026-10-26 起 AGENTS.md 不再內嵌 SOP / Gate 表（只留「你是誰 + 萬事原則」）。
#   Gate 的定義改由**各自的 skill** 承載，讓 skill 自足 —— 被觸發時就看得到
#   「通過標準 / 要貼什麼證據 / 不通過會怎樣 / 進 Gate 時要說的 mandatory_phrase」。
#   `docs/sop/gates.json` 保留為機器可讀副本（install.sh 會裝到 ~/.pi/sop/）
#   → 本探針鎖「兩份不可以飄」。
#
# 反假綠（三道）：
#   ① 每道 Gate 都必須被驗到（`len(gates) >= 4`；掃不到就紅，不得空過）
#   ② 逐條比對 name / pass_criteria / required_evidence / fail_action / mandatory_phrase
#   ③ GATE-SKILL-3 用壞 fixture 證明比對器真的會咬，且**好 fixture 必綠**
#      （否則比對器變成「一律紅」的假咬，同樣沒有驗證力）
#
# 註：gate-2（lint / syntax）沒有專屬 skill（gates.json 的 `trigger_skill: null`），
#     由 `tdd-test-writer` 承載（它在 Gate 1 之後、同一支 skill 的相鄰步驟）。

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  GATES_JSON="$REPO_ROOT/docs/sop/gates.json"
  export REPO_ROOT GATES_JSON
}

# gate-id → "<skill 目錄>\t<gate 名>"（與 gates.json 的 trigger_skill 同源；gate-2 例外）
_gate_skills() {
  python3 - "$GATES_JSON" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1], encoding="utf-8"))
for g in doc["gates"]:
    print(f"{g['id']}\t{g.get('trigger_skill') or 'tdd-test-writer'}\t{g['name']}")
PY
}

# 共用比對器：把 gates.json 的每個欄位逐條拿去 skill 裡找。
# 用法：_gate_check <root> [<gates.json 路徑>]
_gate_check() {
  python3 - "$1" "${2:-$1/docs/sop/gates.json}" <<'PY'
import json, pathlib, sys

root = pathlib.Path(sys.argv[1])
gates_path = pathlib.Path(sys.argv[2])
doc = json.loads(gates_path.read_text(encoding="utf-8"))
gates = doc["gates"]

if len(gates) < 4:
    print(f"FAIL: gates.json 只有 {len(gates)} 道 Gate（< 4）→ 列舉壞了或 Gate 被刪")
    sys.exit(1)

# 先驗 gates.json 自己的欄位非空 —— 空值會讓比對器「無可比對 → 空過」
empty = []
for g in gates:
    for field in ("name", "fail_action", "mandatory_phrase"):
        if not g.get(field):
            empty.append(f"{g['id']} {field}: gates.json 的值是空的（比對器無從比對 → 空過）")
    for field in ("pass_criteria", "required_evidence"):
        if not g.get(field):
            empty.append(f"{g['id']} {field}: gates.json 的陣列是空的（比對器無從比對 → 空過）")
if empty:
    print(f"FAIL: gates.json 有 {len(empty)} 個空欄位：")
    for e in empty:
        print("  - ", e)
    sys.exit(1)

missing = []
for g in gates:
    skill = g.get("trigger_skill") or "tdd-test-writer"
    p = root / "skills" / skill / "SKILL.md"
    if not p.is_file():
        missing.append(f"{g['id']}: 缺 skills/{skill}/SKILL.md")
        continue
    text = p.read_text(encoding="utf-8")
    if g["name"] not in text:
        missing.append(f"{g['id']} name: skills/{skill}/SKILL.md 缺「{g['name']}」")
    for field in ("pass_criteria", "required_evidence"):
        for item in g[field]:
            if item not in text:
                missing.append(f"{g['id']} {field}: skills/{skill}/SKILL.md 缺「{item}」")
    for field in ("fail_action", "mandatory_phrase"):
        if g[field] not in text:
            missing.append(f"{g['id']} {field}: skills/{skill}/SKILL.md 缺「{g[field]}」")

if missing:
    print(f"FAIL: {len(missing)} 項 Gate 定義沒有落在各自的 skill 裡：")
    for m in missing:
        print("  -", m)
    sys.exit(1)

print(f"OK: {len(gates)} 道 Gate 的定義都逐條落在各自的 skill 裡")
PY
}

@test "GATE-SKILL-1: every gate's definition is present verbatim in its owning skill" {
  run _gate_check "$REPO_ROOT"
  [ "$status" -eq 0 ] || {
    echo "$output" >&2
    return 1
  }
  [[ "$output" == *"OK:"* ]] || {
    echo "FAIL: 預期 OK 訊息，實際：$output" >&2
    return 1
  }
}

@test "GATE-SKILL-2: each gate skill has a Gate section that names its gate and points at gates.json" {
  local n=0 id skill gname section
  while IFS=$'\t' read -r id skill gname; do
    [ -n "$id" ] || continue
    n=$((n + 1))
    section=$(awk '/^## .*Gate/{flag=1} /^## /&&!/Gate/{flag=0} flag' \
      "$REPO_ROOT/skills/$skill/SKILL.md")
    [ -n "$section" ] || {
      echo "FAIL: skills/$skill/SKILL.md 沒有以 Gate 為題的定義 section（只有順帶提及不算）" >&2
      return 1
    }
    printf '%s' "$section" | grep -qF "$gname" || {
      echo "FAIL: skills/$skill/SKILL.md 的 Gate section 沒點名「${gname}」（${id}）" >&2
      return 1
    }
    # 去掉區段標題那一行再驗 —— 否則「標題剛好寫了 gates.json」就會滿足本條（等於沒驗）
    # 再濾掉 `mandatory_phrase` 那一行 —— 那個字串已由 GATE-SKILL-1 逐字強制，
    # 留著會讓本條被 incidental 滿足（等於沒驗）。
    local body
    body=$(printf '%s\n' "$section" | tail -n +2 | grep -v 'mandatory_phrase' || true)
    printf '%s' "$body" | grep -qF "gates.json" || {
      echo "FAIL: skills/$skill/SKILL.md 的 Gate section **內文**（標題與 mandatory_phrase 行皆不算）沒指出機器可讀副本 gates.json" >&2
      return 1
    }
    printf '%s' "$body" | grep -qF "$gname" || {
      echo "FAIL: skills/$skill/SKILL.md 的 Gate section 內文沒點名「${gname}」（${id}）" >&2
      return 1
    }
  done < <(_gate_skills)
  [ "$n" -ge 4 ] || {
    echo "FAIL: 只驗到 $n 道 Gate（< 4）→ 列舉壞了" >&2
    return 1
  }
}

@test "GATE-SKILL-4: Gate 4.5 definition is in dav-reconciler, mandatory_phrase identical to handbook 2.3" {
  # Gate 4.5 是 §2.3 內嵌子關卡，**不進 gates.json**（schema 的 gate id 只允許整數編號；PRD-05 ADR-D1）
  # → 它的 single source 是 handbook 2.3。本條鎖「skill 與 handbook 的 mandatory_phrase 一字不差」。
  local skill="$REPO_ROOT/skills/dav-reconciler/SKILL.md"
  local hb="$REPO_ROOT/docs/sop/handbook/2.3-execution.md"
  [ -f "$skill" ] || { echo "FAIL: 缺 $skill" >&2; return 1; }
  [ -f "$hb" ] || { echo "FAIL: 缺 $hb" >&2; return 1; }
  local phrase
  phrase=$(grep -oE '「依 §2\.3 規範，Gate 4\.5 .*」' "$hb" | head -1 | sed 's/^「//; s/」$//')
  [ -n "$phrase" ] || {
    echo "FAIL: 無法從 handbook 2.3 取得 Gate 4.5 的 mandatory_phrase（格式變了？）" >&2
    return 1
  }
  grep -qF -- "$phrase" "$skill" || {
    echo "FAIL: dav-reconciler SKILL.md 的 Gate 4.5 mandatory_phrase 與 handbook 2.3 不一致" >&2
    echo "  期望（來自 handbook）：$phrase" >&2
    return 1
  }
  local anchor
  for anchor in "Gate 4.5" "需求對帳" "未參與實作" "不可進入 §2.4 反省"; do
    grep -qF -- "$anchor" "$skill" || {
      echo "FAIL: dav-reconciler SKILL.md 缺 Gate 4.5 的關鍵元素「${anchor}」" >&2
      return 1
    }
  done
}

@test "GATE-SKILL-3: the comparator itself bites (broken fixture must be rejected, good one must pass)" {
  local tmp="$BATS_TEST_TMPDIR/fixture"
  mkdir -p "$tmp/docs/sop" "$tmp/skills/tdd-test-writer"
  cat > "$tmp/docs/sop/gates.json" <<'JSON'
{"gates": [
  {"id": "gate-1", "name": "G1NAME", "trigger_skill": "tdd-test-writer",
   "pass_criteria": ["C1"], "required_evidence": ["E1"],
   "fail_action": "F1", "mandatory_phrase": "PHRASE-1-98765"},
  {"id": "gate-2", "name": "G2NAME", "trigger_skill": null,
   "pass_criteria": ["C2"], "required_evidence": ["E2"], "fail_action": "F2", "mandatory_phrase": "PHRASE-2-98765"},
  {"id": "gate-3", "name": "G3NAME", "trigger_skill": "tdd-test-writer",
   "pass_criteria": ["C3"], "required_evidence": ["E3"], "fail_action": "F3", "mandatory_phrase": "PHRASE-3-98765"},
  {"id": "gate-4", "name": "G4NAME", "trigger_skill": "tdd-test-writer",
   "pass_criteria": ["C4"], "required_evidence": ["E4"], "fail_action": "F4", "mandatory_phrase": "PHRASE-4-98765"},
  {"id": "gate-5", "name": "G5NAME", "trigger_skill": "tdd-test-writer",
   "pass_criteria": ["C5"], "required_evidence": ["E5"], "fail_action": "F5", "mandatory_phrase": "PHRASE-5-98765"}
]}
JSON
  # 每個被鎖欄位各跑一輪「只掉它」：5 個分支都要被自證（只掉一個就必須紅），
  # 完整版必須綠（否則比對器是一律紅的假咬）。
  local full='C1 C2 C3 C4 C5 E1 E2 E3 E4 E5 F1 F2 F3 F4 F5 PHRASE-1-98765 PHRASE-2-98765 PHRASE-3-98765 PHRASE-4-98765 PHRASE-5-98765 G1NAME G2NAME G3NAME G4NAME G5NAME'
  local variant
  for variant in "$full" \
    "${full/G1NAME/}" \
    "${full/C1 /}" \
    "${full/E1 /}" \
    "${full/F1 /}" \
    "${full/PHRASE-1-98765/}" \
    "${full/PHRASE-5-98765/}"; do
    printf -- '---\nname: tdd-test-writer\ndescription: d\n---\n\n## Gate 定義\n\n%s\n' "$variant" \
      > "$tmp/skills/tdd-test-writer/SKILL.md"
    run _gate_check "$tmp" "$tmp/docs/sop/gates.json"
    if [ "$variant" = "$full" ]; then
      [ "$status" -eq 0 ] || {
        echo "FAIL: 完整 fixture 竟紅（比對器一律紅＝假咬）：$output" >&2
        return 1
      }
    else
      [ "$status" -ne 0 ] || {
        echo "FAIL: 只掉一個欄位的 fixture 竟通過（該分支未被自證 → 可能空過）" >&2
        echo "  variant: $variant" >&2
        return 1
      }
    fi
  done

  # 反向二：gates.json 自己的欄位被清空 → 必須紅（否則比對器無可比對＝空過）
  python3 - "$tmp/docs/sop/gates.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p, encoding="utf-8"))
d["gates"][0]["mandatory_phrase"] = ""
json.dump(d, open(p, "w", encoding="utf-8"), ensure_ascii=False)
PY
  run _gate_check "$tmp" "$tmp/docs/sop/gates.json"
  [ "$status" -ne 0 ] || {
    echo "FAIL: gates.json 欄位被清空竟通過（比對器空過）" >&2
    return 1
  }
}
