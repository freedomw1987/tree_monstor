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

掃描範圍＝`git ls-files -co --exclude-standard`（已追蹤＋未追蹤但未被 gitignore 的 *.sh／*.bash／
*.bats／*.yml／*.yaml）。刻意含未追蹤檔：新檔在 commit 前只有本機能檢查，只掃已追蹤就等於「本機全綠、
CI 才紅」（這正是本鎖 2026-10-05 補上的盲點）。
"""

import os
import pathlib
import re
import subprocess
import sys
import tempfile

# `$name` / `$1` / `$10` / `$?` / `$@` … 緊接一個非 ASCII 位元組。
# 排除 `\$var（`（轉義＝不展開，reviewer round L P3-1）。已知界限：不辨識引號語境
# （單引號內 `'$var（'` 不會被展開，但這裡仍會標記）——行級靜態鎖的刻意取捨，寧嚴不漏。
# 另一已知界限（輕量確認輪 P3-4）：`\\$var（`（偶數反斜線＝真反斜線 + 真展開）也會被 lookbehind 跳過，
# 屬理論偽陰；現況全 repo 0 命中（若要根治需改成奇偶反斜線判定）。
PAT = re.compile(r"(?<!\\)\$(?:[A-Za-z_][A-Za-z0-9_]*|[0-9]+|[?@*#!$-])(?=[^\x00-\x7F])")
GLOBS = ["*.sh", "*.bash", "*.bats", "*.yml", "*.yaml"]
MIN_FILES = 40


def targets(root):
    root = pathlib.Path(root)
    # `-co --exclude-standard`：含**未追蹤但未被 gitignore**的檔。
    # 只用 `ls-files`（只列已追蹤）有盲點：新檔在 commit 前是 untracked → 本機全綠、
    # 一 push 進 CI 才紅。2026-10-05 真實案例：`tests/pptx-slim-images.bats` 的
    # `$after（`／`$name（` 與 `tests/mutant-must-die.bats` 的 `$status）` 就是這樣溜進 commit 的。
    out = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-co", "--exclude-standard", *GLOBS],
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
        pos10 = d / "pos10.sh"
        pos10.write_text('echo "第 $10（位）"\n')
        esc = d / "esc.sh"
        esc.write_text('echo "字面 \\$var（不展開）"\n')
        special = d / "special.sh"
        special.write_text('echo "rc=$?（見上）"\n')
        assert violations([bad]), "自我測試失敗：沒抓到 $var 緊接非 ASCII"
        assert not violations([brace]), "自我測試失敗：誤判已加大括號的寫法"
        assert not violations([ascii_ok]), "自我測試失敗：誤判 ASCII 後綴"
        assert not violations([comment]), "自我測試失敗：把註解行誤判成違規"
        assert violations([pos]), "自我測試失敗：沒抓到位置參數 $1（"
        assert violations([pos10]), "自我測試失敗：沒抓到多位數位置參數 $10（"
        assert not violations([esc]), "自我測試失敗：把轉義 \\$var（ 誤判成展開"
        assert violations([special]), "自我測試失敗：沒抓到特殊參數 $?（"

        # 掃描範圍契約（2026-10-05 二審 F4）：`targets()` 必須**含未追蹤但未被 gitignore** 的檔。
        # 只掃已追蹤 ⇒ 新檔在 commit 前本機看不到（本鎖 2026-10-05 補的盲點）；這一節把它鎖起來，
        # 以後誰把 `-co` 改回 `-c` 或拿掉 `--exclude-standard`，`ENV-EQ-17` 會直接紅。
        repo = d / "repo"
        repo.mkdir()
        (repo / "tracked.sh").write_text('echo "$v（已追蹤）"\n')
        (repo / "untracked.sh").write_text('echo "$v（未追蹤）"\n')
        (repo / "ignored.sh").write_text('echo "$v（被 gitignore）"\n')
        (repo / ".gitignore").write_text("ignored.sh\n")
        ident = {
            "GIT_AUTHOR_NAME": "ci",
            "GIT_AUTHOR_EMAIL": "ci@example.com",
            "GIT_COMMITTER_NAME": "ci",
            "GIT_COMMITTER_EMAIL": "ci@example.com",
        }
        env = {**os.environ, **ident}
        subprocess.run(["git", "init", "-q"], cwd=repo, check=True, env=env)
        subprocess.run(["git", "add", "tracked.sh", ".gitignore"], cwd=repo, check=True, env=env)
        subprocess.run(
            ["git", "commit", "-q", "-m", "init", "--no-gpg-sign"], cwd=repo, check=True, env=env
        )
        scanned = {p.name for p in targets(repo)}
        assert "tracked.sh" in scanned, "自我測試失敗：targets() 漏掉已追蹤檔"
        assert "untracked.sh" in scanned, "自我測試失敗：targets() 漏掉未追蹤檔（= 2026-10-05 修掉的盲點）"
        assert "ignored.sh" not in scanned, "自我測試失敗：targets() 把 gitignore 的檔也算了進來"

    print("OK: 鎖自我測試通過（正反兩向＋位置／多位數位置／特殊參數＋轉義豁免＋註解豁免＋未追蹤檔納入）")


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
