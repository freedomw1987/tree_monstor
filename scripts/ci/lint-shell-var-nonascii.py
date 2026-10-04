#!/usr/bin/env python3
"""鎖（2026-10-05 CI 首跑）：shell 檔不得出現「`$var` 緊接非 ASCII 字元」。

為什麼：**bash 3.2 + UTF-8 locale**（＝GitHub macOS runner 的預設組合）會把緊接在
`$var` 後面的非 ASCII 字元的**第一個位元組吞進變數名**，於是 `echo "$f（"` 變成在展開
`$f\xef` → `set -u` 下直接 `unbound variable` 而紅、沒 `set -u` 時靜默印出空值。

真實案例（本鎖的來源）：`scripts/ci/check-skill-size.sh:51` 的 `$worst_file）` 讓
`skill-size-guard.bats SSG-3` 只在 macOS leg 紅（本機 bash 5 完全看不到），
以及同類寫法共 39 處（bats 探針、PoC 腳本、CI 內嵌 shell）。

修法一律是**加大括號**：`${f}（`——語意完全相同，但變數名有明確邊界。

用法：
  python3 scripts/ci/lint-shell-var-nonascii.py <repo_root>
  python3 scripts/ci/lint-shell-var-nonascii.py --self-test
"""

import pathlib
import re
import subprocess
import sys
import tempfile

# `$name` / `$1` / `$?` / `$@` … 緊接一個非 ASCII 位元組
PAT = re.compile(r"\$(?:[A-Za-z_][A-Za-z0-9_]*|[0-9?@*#!$-])(?=[^\x00-\x7F])")
GLOBS = ["*.sh", "*.bash", "*.bats", "*.yml", "*.yaml"]
MIN_FILES = 40


def targets(root):
    root = pathlib.Path(root)
    out = subprocess.run(
        ["git", "-C", str(root), "ls-files", *GLOBS],
        capture_output=True,
        text=True,
        check=False,
    )
    if out.returncode != 0:
        raise RuntimeError(f"git ls-files 失敗（{root} 是 git repo 嗎？）：{out.stderr.strip()}")
    return [root / line for line in out.stdout.split("\n") if line]


def violations(files):
    out = []
    for p in files:
        for i, line in enumerate(p.read_text(encoding="utf-8", errors="replace").split("\n"), 1):
            if line.lstrip().startswith("#"):
                continue  # 註解不會被展開（含刻意示範壞寫法的說明行）
            m = PAT.search(line)
            if m:
                out.append(
                    f"{p}:{i}: `{m.group(0)}` 後面緊接非 ASCII 字元"
                    f"（bash 3.2 + UTF-8 locale 會吞掉首位元組）→ 改成 `${{{m.group(0)[1:]}}}`："
                    f"{line.strip()[:100]}"
                )
    return out


def self_test():
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        bad = d / "bad.sh"
        bad.write_text('echo "最長 $worst_file）"\n')
        brace = d / "brace.sh"
        brace.write_text('echo "最長 ${worst_file}）"\n')
        ascii_ok = d / "ascii.sh"
        ascii_ok.write_text('echo "值 $var (ascii)"\n')
        comment = d / "comment.sh"
        comment.write_text('# 壞寫法示範：$var）\n')
        pos = d / "pos.sh"
        pos.write_text('echo "路徑 $1（必填）"\n')
        special = d / "special.sh"
        special.write_text('echo "rc=$?（見上）"\n')
        assert violations([bad]), "自我測試失敗：沒抓到 $var 緊接非 ASCII"
        assert not violations([brace]), "自我測試失敗：誤判已加大括號的寫法"
        assert not violations([ascii_ok]), "自我測試失敗：誤判 ASCII 後綴"
        assert not violations([comment]), "自我測試失敗：把註解行誤判成違規"
        assert violations([pos]), "自我測試失敗：沒抓到位置參數 $1（"
        assert violations([special]), "自我測試失敗：沒抓到特殊參數 $?（"
    print("OK: 鎖自我測試通過（正反兩向＋位置／特殊參數＋註解豁免）")


def main(argv):
    if "--self-test" in argv:
        self_test()
        return 0
    if len(argv) != 2:
        print("用法：lint-shell-var-nonascii.py <repo_root> | --self-test", file=sys.stderr)
        return 2
    files = targets(argv[1])
    if len(files) < MIN_FILES:
        print(f"FAIL: 只掃到 {len(files)} 個 shell 相關檔（防空過；預期 >= {MIN_FILES}）")
        return 1
    found = violations(files)
    if found:
        for line in found:
            print("FAIL: " + line)
        return 1
    print(f"OK: {len(files)} 個 shell／CI 檔皆無「$var 緊接非 ASCII」")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
