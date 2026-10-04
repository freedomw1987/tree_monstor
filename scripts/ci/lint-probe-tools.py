#!/usr/bin/env python3
"""鎖 2（TMO-041）：探針不得直接執行 `gh` / `brew`（工具狀態依賴）。

為什麼：本機裝了 `gh`/`brew` 就會「剛好過」，CI 沒裝（或沒登入）就紅——
測試必須只驗「程式碼裡有這段字串」，真的要打外部工具就得 stub。
判定方式是啟發式（命令位置比對），不是完美語法分析：抓的是行首縮排後、
運算子（`;` `|` `&&` `(` `$(`）之後、或 shell 關鍵字（`then` `do` `run` …）之後的 `gh`/`brew`。
引號內的字串（`assert_file_contains "$f" "gh pr comment"`）與註解不算違規。

用法：
  python3 scripts/ci/lint-probe-tools.py <repo_root>
  python3 scripts/ci/lint-probe-tools.py --self-test
"""

import pathlib
import re
import sys
import tempfile

# 命令位置：行首/運算子後（可含空白），或 shell 關鍵字後（關鍵字需有空白）
PAT = re.compile(
    r"(?:(?:^|[;&|(]|\$\()\s*|\b(?:then|do|else|elif|if|run|command|exec|env|sudo|time|xargs|!)\s+)"
    r"(gh|brew)(?=\s|$)"
)
MIN_FILES = 20


def targets(root):
    root = pathlib.Path(root)
    # 覆蓋缺口（round E P2-3）：skill 自己的測試檔同樣是探針，不能漏掃
    return (
        sorted(root.glob("tests/*.bats"))
        + sorted(root.glob("tests/helpers/*.bash"))
        + sorted(root.glob("skills/*/tests/*.bats"))
    )


def violations(files):
    out = []
    for p in files:
        for i, line in enumerate(p.read_text().split("\n"), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            m = PAT.search(line)
            if m:
                out.append(f"{p}:{i}: 直接執行 {m.group(1)}（本機有裝就會剛好過）：{stripped}")
    return out


def self_test():
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        cases = {
            "plain.bats": ('@test "x" {\n  gh auth status\n}\n', 1),
            "keyword.bats": ('@test "x" {\n  if true; then brew install jq; fi\n}\n', 1),
            "prefix.bats": ('@test "x" {\n  run gh pr comment --body hi\n}\n', 1),
            "pipe.bats": ('@test "x" {\n  echo x | brew list >/dev/null\n}\n', 1),
            "string.bats": ('@test "x" {\n  assert_file_contains "$f" "gh pr comment"\n}\n', 0),
            "comment.bats": ('# gh 只是字串\n@test "x" {\n  echo x\n}\n', 0),
            "other.bats": ('@test "x" {\n  ghpr_comment() { echo hi; }\n}\n', 0),
        }
        for name, (body, want) in cases.items():
            f = d / name
            f.write_text(body)
            got = len(violations([f]))
            assert got == want, f"自我測試失敗：{name} 期望 {want} 個違規，得到 {got}"
    print("OK: 鎖 2 自我測試通過（行首／關鍵字／run 前綴／管線／字串／註解／同前綴函式）")


def main(argv):
    if "--self-test" in argv:
        self_test()
        return 0
    if len(argv) != 2:
        print("用法：lint-probe-tools.py <repo_root> | --self-test", file=sys.stderr)
        return 2
    files = targets(argv[1])
    if len(files) < MIN_FILES:
        print(f"FAIL: 只掃到 {len(files)} 個探針檔（防空過；預期 >= {MIN_FILES}）")
        return 1
    found = violations(files)
    if found:
        for line in found:
            print("FAIL: " + line)
        return 1
    print(f"OK: {len(files)} 個探針檔皆未直接執行 gh / brew")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))