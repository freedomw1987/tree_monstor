#!/usr/bin/env python3
"""鎖 1（TMO-041）：探針檔不得寫入固定 `/tmp/<name>` 路徑。

為什麼：固定檔名跨 run 會殘留舊檔，「檔案有沒有被寫出來」的斷言就會假綠
（TMO-039 那類 CI／本機不一致）。要寫檔請寫 `$BATS_TEST_TMPDIR`。
純「資料引用」（例如壞值清單、故意不存在的路徑）可標 `TMP-OK` 就地豁免，
反向鎖要求 `TMP-OK` 只能出現在真的有 `/tmp/` 的那一行（不能拿來當萬用豁免）。

用法：
  python3 scripts/ci/lint-probe-tmp-paths.py <repo_root>
  python3 scripts/ci/lint-probe-tmp-paths.py --self-test
"""

import pathlib
import re
import sys
import tempfile

MARK = "TMP-OK"
# 孤立 /tmp/ 字面：前一字元不是檔名字元（避免誤判 $REPO_ROOT/tmp/）
PAT = re.compile(r"(?<![A-Za-z0-9_.\-/$])/tmp/")
MIN_FILES = 20
MIN_MARKS = 2


def targets(root):
    root = pathlib.Path(root)
    files = sorted(root.glob("tests/*.bats")) + sorted(root.glob("tests/helpers/*.bash"))
    return files


def violations(files):
    out = []
    for p in files:
        for i, line in enumerate(p.read_text().split("\n"), 1):
            if line.strip().startswith("#"):
                continue  # 註解不會執行（含被註解掉的示範碼）
            has_path = bool(PAT.search(line))
            has_mark = MARK in line
            if has_path and not has_mark:
                out.append(
                    f"{p}:{i}: 固定 /tmp/ 路徑（改用 $BATS_TEST_TMPDIR，或標 {MARK} 說明為何是純資料）"
                    f"：{line.strip()}"
                )
            if has_mark and not has_path:
                out.append(f"{p}:{i}: {MARK} 標記濫用（該行沒有 /tmp/ 路徑）：{line.strip()}")
    return out


def self_test():
    with tempfile.TemporaryDirectory() as d:
        d = pathlib.Path(d)
        bad = d / "bad.bats"
        bad.write_text('@test "x" {\n  cp a /tmp/zz-residue.json\n}\n')
        good = d / "good.bats"
        good.write_text('@test "x" {\n  cp a /tmp/zz-ok.json  # TMP-OK: 純測試資料，不會真的寫檔\n}\n')
        misuse = d / "misuse.bats"
        misuse.write_text('@test "x" {\n  echo hi  # TMP-OK\n}\n')
        comment = d / "comment.bats"
        comment.write_text('# 這裡提到 /tmp/ 只是註解\n@test "x" {\n  echo hi\n}\n')
        assert violations([bad]), "自我測試失敗：沒抓到固定 /tmp/ 寫入"
        assert not violations([good]), "自我測試失敗：誤判有標記的行"
        assert violations([misuse]), "自我測試失敗：沒抓到 TMP-OK 標記濫用"
        assert not violations([comment]), "自我測試失敗：把註解誤判成寫入"
    print("OK: 鎖 1 自我測試通過（正反兩向＋標記濫用＋註解豁免）")


def main(argv):
    if "--self-test" in argv:
        self_test()
        return 0
    if len(argv) != 2:
        print("用法：lint-probe-tmp-paths.py <repo_root> | --self-test", file=sys.stderr)
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
    marked = sum(1 for p in files for line in p.read_text().split("\n") if MARK in line)
    if marked < MIN_MARKS:
        print(f"FAIL: 只有 {marked} 行帶 {MARK}（防空過；預期 >= {MIN_MARKS}）")
        return 1
    print(f"OK: {len(files)} 個探針檔皆無固定 /tmp/ 寫入（{marked} 行帶 {MARK}，純資料引用）")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))