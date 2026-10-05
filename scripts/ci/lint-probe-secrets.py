#!/usr/bin/env python3
"""鎖 4（TMO-053 / NYH-2）：探針 FAIL 訊息不得外洩密鑰。

為什麼：2026-10-05 做 TMO-045 反向驗證時，探針的 FAIL 訊息把本機**真實**
`OPENROUTER_API_KEY` 印進了 session log（NYH-1）。當時的遮罩函式
`mask_secrets()` 只定義在單一探針檔內，其他探針沒有任何防線，
也沒有任何靜態鎖擋得住「下次忘記遮罩」。

規則（掃 `tests/*.bats`、`tests/helpers/*.bash`、`skills/*/tests/*.bats`）：
  R1 真 key 前綴：不得出現 `sk-or-v1-`（OpenRouter 真 key 前綴）。
     假值（例如 `sk-fake-…`）請用別的樣式；真的需要該字面（斷言樣式／合成案例）
     就標 `SECRET-OK: <理由>`。
  R2 檔級：任何提到 `_load_api_key` 的檔，整檔**程式碼**（去掉註解後）必須出現
     `mask_secrets` 的呼叫形態（`mask_secrets(`／`)`／`|`／`>` 重導向／`<<<`），
     光在註解裡提到名字不算。
  R3 行級：同類檔案中，`echo` / `printf` 的 FAIL 訊息若展開 `$output` /
     `${output}` / `$out` / `$result` / `$OUTPUT`，必須在**同一行**出現呼叫形態
     （印出去前先遮罩）。合成案例（例如「造一個會洩漏的假探針」）可標記豁免。
     **另加一層（不看檔內有沒有提 `_load_api_key`）**：FAIL 訊息直印
     `$OPENROUTER_API_KEY`（NYH-1 實際外洩的那個）一律違規。
  R4 單一真相：`mask_secrets()` 只准定義在 `tests/helpers/test-env.bash`；
     其他檔案（含其他 helper、`.bats`）不得自己再定義一份。
  R5 標記紀律：`SECRET-OK` **必須附理由**（`SECRET-OK: 假值`），且只能標在
     真的是「洩漏樣本」的行（含真前綴字面，或 R3 的行內形態）。

標記的真實語意（別過度承諾）：`SECRET-OK` 是**顯式、可 grep 的人工豁免**——
它只擋「標在無關行」這種濫用；只要一行長得像洩漏樣本，貼上標記就會被放行，
所以審查時請以「標記總數」當錨點（本鎖會把總數印出來）。

已知限制（刻意不擋，不是漏了）：
  * 跨行搬移：`local m="$output"` 之後 `echo "FAIL: $m"`——靜態行掃描本質擋不住。
  * 其他變數名（`$msg` / `$got` / `$KEY`）、`cat <<<"$output"`、`sed`/python
    等間接列印、`Bearer <值>` 等非 `sk-or-v1-` 形態。
  * 標記總數**沒**釘在測試裡：新增一個合格豁免只需加一行 `SECRET-OK: <理由>`，
    不會強迫改測試；故它的防線是人工複核掃描器印出的那個數字（數變了就看 diff）。
  * 只掃深度 1（`tests/*.bats`、`skills/*/tests/*.bats`）；未來若新增
    `tests/unit/*.bats`，本鎖與 `SM-1` 會一起漏——新增子目錄時要同步改兩處。

防空過：掃到的探針檔數 >= 40，且至少 1 個檔真的碰 `_load_api_key`。

用法：
  python3 scripts/ci/lint-probe-secrets.py <repo_root>
  python3 scripts/ci/lint-probe-secrets.py --self-test
"""

import pathlib
import re
import sys
import tempfile

MARK = "SECRET-OK"
MARK_RE = re.compile(r"SECRET-OK:[ \t]*\S")  # 標記必須附理由
REAL_PREFIX = re.compile(r"sk-or-v1-")
OUT_LINE = re.compile(r"\b(?:echo|printf)\b")
FAIL_LINE = re.compile(r"FAIL")
LEAKY_VAR = re.compile(r"\$\{?(?:output|out|result|OUTPUT)\}?")
# 真正外洩過的那個環境變數（NYH-1）：直印它就違規，不需檔內提到 _load_api_key
ENV_KEY = re.compile(r"\$\{?OPENROUTER_API_KEY\}?")
MASK_CALL = "mask_secrets"
MASK_CALL_FORM = re.compile(r"mask_secrets\s*[()|<>]")  # 真的呼叫，不是只提名字
MASK_DEF = re.compile(r"^\s*(?:function\s+)?mask_secrets\s*\(\s*\)")
KEY_API = "_load_api_key"
CANONICAL = ("tests", "helpers", "test-env.bash")
COMMENT_SPLIT = re.compile(r"^[ \t]*#|(?<=[ \t])#")
MIN_FILES = 40
MIN_KEY_FILES = 1


def strip_comment(line):
    """保守去行內註解：只認「行首 #」與「空白後的 #」。"""
    m = COMMENT_SPLIT.search(line)
    return line[: m.start()] if m else line


def targets(root):
    root = pathlib.Path(root)
    return (
        sorted(root.glob("tests/*.bats"))
        + sorted(root.glob("tests/helpers/*.bash"))
        + sorted(root.glob("skills/*/tests/*.bats"))
    )


def scan(files):
    """回傳 (violations, key_files, marks)；violations 為訊息字串清單。"""
    out = []
    key_files = 0
    marks = 0
    for p in files:
        text = p.read_text()
        code = "\n".join(strip_comment(ln) for ln in text.split("\n"))
        if KEY_API in text:
            key_files += 1
            if not MASK_CALL_FORM.search(code):
                out.append(
                    f"{p}: 檔內用到 {KEY_API} 但整檔沒有 {MASK_CALL} 呼叫"
                    "（＝印出去時沒有遮罩能力；註解裡提到名字不算）"
                )
        for i, line in enumerate(text.split("\n"), 1):
            if MARK in line:
                marks += 1  # 計數在「跳過整行註解」之前：錨點不得低估
            if line.strip().startswith("#"):
                continue  # 整行註解不會執行
            cur = strip_comment(line)
            has_real = bool(REAL_PREFIX.search(line))
            has_mark = bool(MARK_RE.search(line))
            # 「故意的洩漏樣本」：R1 的字面，或 R3 的行內形態（合成案例用）
            is_sample = has_real or bool(
                OUT_LINE.search(cur)
                and FAIL_LINE.search(cur)
                and (LEAKY_VAR.search(cur) or ENV_KEY.search(cur))
            )
            if MARK in line and not has_mark:
                out.append(
                    f"{p}:{i}: {MARK} 標記必須附理由（{MARK}: <為什麼可以被豁免>）：{line.strip()}"
                )
            if has_real and not has_mark:
                out.append(
                    f"{p}:{i}: 出現真 key 前綴 sk-or-v1-（假值請改樣式，"
                    f"真需要該字面請標 {MARK}: <理由>）：{line.strip()}"
                )
            if has_mark and not is_sample:
                out.append(f"{p}:{i}: {MARK} 標記濫用（該行不是洩漏樣本）：{line.strip()}")
            fails_msg = bool(
                OUT_LINE.search(cur) and FAIL_LINE.search(cur) and not MASK_CALL_FORM.search(cur)
            )
            if fails_msg and not has_mark and ENV_KEY.search(cur):
                out.append(
                    f"{p}:{i}: FAIL 訊息直接展開 {ENV_KEY.pattern} 而未過 {MASK_CALL}"
                    f"（NYH-1 實際外洩的那個變數）：{line.strip()}"
                )
            if (
                KEY_API in text
                and fails_msg
                and LEAKY_VAR.search(cur)
                and not has_mark
            ):
                out.append(
                    f"{p}:{i}: FAIL 訊息直接展開 {LEAKY_VAR.pattern} 而未過 {MASK_CALL}"
                    f"（NYH-1 的外洩形態）：{line.strip()}"
                )
            if tuple(p.parts[-3:]) != CANONICAL and MASK_DEF.match(cur):
                out.append(
                    f"{p}:{i}: 在 {'/'.join(CANONICAL)} 以外重新定義 {MASK_CALL}"
                    "（應改用共用版，免得只遮一半）"
                )
    return out, key_files, marks


def self_test():
    with tempfile.TemporaryDirectory() as d:
        root = pathlib.Path(d)
        (root / "tests/helpers").mkdir(parents=True)
        (root / "tests/fake").mkdir(parents=True)

        def w(name, body):
            p = root / "tests" / name
            p.write_text(body)
            return p

        w(
            "helpers/test-env.bash",
            "# 共用 helper 是唯一允許定義的地方\nmask_secrets() {\n  sed -E 's/x/y/'\n}\n",
        )
        bad_prefix = w("prefix.bats", '@test "x" {\n  k="sk-or-v1-REALLOOKING"\n}\n')
        ok_prefix = w("prefix-ok.bats", '@test "x" {\n  k="sk-or-v1-FAKE"  # SECRET-OK: 假值\n}\n')
        abuse = w("abuse.bats", '@test "x" {\n  echo hi  # SECRET-OK\n}\n')
        sample = w(
            "sample.bats",
            '@test "x" {\n  run python3 -c "print(_load_api_key())"\n'
            '  echo "FAIL: got $output" >&2  # SECRET-OK: 合成洩漏樣本\n'
            '  echo "$output" | mask_secrets >/dev/null\n}\n',
        )
        commented = w("commented.bats", '# 這裡提到 sk-or-v1- 只是註解\n@test "x" {\n  echo hi\n}\n')
        r2 = w("r2.bats", '@test "x" {\n  run python3 -c "print(_load_api_key())"\n  [ "$status" -eq 0 ]\n}\n')
        # P1-2 迴歸：只在**註解**裡提到 mask_secrets，不得算有遮罩能力
        r2_comment = w(
            "r2-comment.bats",
            '@test "x" {\n  run python3 -c "print(_load_api_key())"\n'
            '  [ "$status" -eq 0 ]  # 要記得 mask_secrets\n}\n',
        )
        r3 = w(
            "r3.bats",
            '@test "x" {\n  run python3 -c "print(_load_api_key())"\n'
            '  echo "FAIL: got $output" >&2\n}\n',
        )
        r3_brace = w(
            "r3-brace.bats",
            '@test "x" {\n  run python3 -c "print(_load_api_key())"\n'
            '  echo "FAIL: got ${output}" >&2\n}\n',
        )
        # P1-2 迴歸：真遮罩拿掉、只留註解 → 必須咬
        r3_comment = w(
            "r3-comment.bats",
            '@test "x" {\n  run python3 -c "print(_load_api_key())"\n'
            '  echo "FAIL: got $output" >&2  # 要記得 mask_secrets\n'
            '  echo "$output" | mask_secrets >/dev/null\n}\n',
        )
        r3_ok = w(
            "r3-ok.bats",
            '@test "x" {\n  run python3 -c "print(_load_api_key())"\n'
            '  echo "FAIL: got $(printf \'%s\' "$output" | mask_secrets)" >&2\n}\n',
        )
        r3_ok_brace = w(
            "r3-ok-brace.bats",
            '@test "x" {\n  run python3 -c "print(_load_api_key())"\n'
            '  echo "FAIL: got ${output}" | mask_secrets >&2\n}\n',
        )
        r4 = w("r4.bats", '@test "x" {\n  mask_secrets() {\n    sed -E "s/x/y/"\n  }\n}\n')
        r4_space = w("r4-space.bats", '@test "x" {\n  function mask_secrets () {\n    sed -E "s/x/y/"\n  }\n}\n')
        r4_helper = root / "tests/helpers/other.bash"
        r4_helper.write_text("mask_secrets() {\n  cat\n}\n")
        # P3-6：檔內**沒**提 _load_api_key，卻在 FAIL 訊息直印真正外洩過的環境變數
        r3_envkey = w(
            "r3-envkey.bats",
            '@test "x" {\n  run env-check\n  echo "FAIL: OPENROUTER_API_KEY=$OPENROUTER_API_KEY" >&2\n}\n',
        )
        r3_envkey_ok = w(
            "r3-envkey-ok.bats",
            '@test "x" {\n  run env-check\n'
            '  echo "FAIL: got $(printf \'%s\' "$OPENROUTER_API_KEY" | mask_secrets)" >&2\n}\n',
        )

        def expect_ok(paths, why):
            v, _, _ = scan(paths)
            assert not v, f"自我測試失敗：{why}：{v}"

        def expect_bad(paths, why):
            v, _, _ = scan(paths)
            assert v, f"自我測試失敗：{why}"

        expect_bad([bad_prefix], "沒抓到 sk-or-v1- 真前綴")
        expect_ok([ok_prefix], "誤判有 SECRET-OK 的行")
        expect_bad([abuse], "沒抓到 SECRET-OK 標記濫用（且未附理由）")
        expect_ok([sample], "誤判標了 SECRET-OK 的合成洩漏樣本")
        expect_ok([commented], "把註解誤判成洩漏")
        expect_bad([r2], "沒抓到『碰 key 卻整檔沒遮罩』")
        expect_bad([r2_comment], "把『只在註解提到 mask_secrets』當成有遮罩能力")
        expect_bad([r3], "沒抓到漏遮罩的 FAIL 訊息")
        expect_bad([r3_brace], "沒抓到 `${output}` 大括號形態")
        expect_bad([r3_comment], "把『刪掉真遮罩只留註解』當成有遮罩")
        expect_ok([r3_ok], "誤判已遮罩的 FAIL 訊息")
        expect_ok([r3_ok_brace], "誤判已遮罩的 `${output}` FAIL 訊息")
        expect_bad([r4], "沒抓到探針檔內重複定義 mask_secrets")
        expect_bad([r4_space], "沒抓到 `function mask_secrets ()` 形態")
        expect_bad([r4_helper], "沒抓到其他 helper 再定義一份")
        expect_bad([r3_envkey], "沒抓到 FAIL 訊息直印 $OPENROUTER_API_KEY（檔內沒提 _load_api_key）")
        expect_ok([r3_envkey_ok], "誤判已遮罩的 $OPENROUTER_API_KEY FAIL 訊息")
        expect_ok([root / "tests/helpers/test-env.bash"], "誤判共用 helper 的定義")
    print(
        "OK: 鎖 4 自我測試通過（真前綴／標記豁免與濫用／標記附理由／註解／檔級／行級／"
        "大括號／環境變數直印／合成樣本／單一真相與變體）"
    )


def main(argv):
    if "--self-test" in argv:
        self_test()
        return 0
    if len(argv) != 2:
        print("用法：lint-probe-secrets.py <repo_root> | --self-test", file=sys.stderr)
        return 2
    files = targets(argv[1])
    found, key_files, marks = scan(files)
    if found:
        for line in found:
            print("FAIL: " + line)
        return 1
    if len(files) < MIN_FILES:
        print(f"FAIL: 只掃到 {len(files)} 個探針檔（防空過；預期 >= {MIN_FILES}）")
        return 1
    if key_files < MIN_KEY_FILES:
        print(
            f"FAIL: 只有 {key_files} 個檔碰 {KEY_API}（防空過；預期 >= {MIN_KEY_FILES}）"
            "→ 抽取器可能壞了，R2/R3 等於沒在跑"
        )
        return 1
    print(
        f"OK: 掃描 {len(files)} 個探針檔（其中 {key_files} 個直接碰 {KEY_API}）；"
        f"0 violation；{marks} 個 {MARK} 標記（審查錨點，請人工確認每個都合理）"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
