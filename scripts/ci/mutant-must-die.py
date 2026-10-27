#!/usr/bin/env python3
"""mutant-must-die：把「探針真的咬得住突變」從一次性人工動作變成 CI 會跑的檢查。

為什麼需要它（TMO-065）：
  pptx-slim 的 26 支 mutant 是**手動**種出來的 —— 當下確實證明了探針咬得住，
  但下次有人把某個 gate 改成恒真、把護欄拿掉、把精確比對改成子字串，
  沒有任何探針會紅、也沒有人會記得重跑。這支腳本就是那張「重跑」的清單。

（TMO-066）表後來從 26 支擴到 39 支：同一套 harness 再收了 dav-wiki（缺工具不得降級 6 支）、
  探針機密遮罩（3 支）與 dav-developer（TTY fail-fast 四檔一致 4 支）的護欄 ——
  它們在此之前同樣只是「人工驗過一次」，驗完就沒有任何檢查記得。
  二審（verdict `request-changes`）後再 +1 → **48 支**（TMO-071/072/073 再 +5：DD-M1 / DD-M2 / DD-M3 / DR-M1 / DR-M2）：SM-M1 重寫（舊版掉續行反斜線，
  死因是 rc=127 parse error 而非遮罩失效）、DW-M5 由「文字契約鎖」升級為真行為鎖
  （收緊 `tests/wiki-ocr.bats` AC-O4／AC-O6 去驗 2／1）、新增 LK-M1（掃描器 `git ls-files -co` 改回 `-c`）。
  二審 F3 也把「等價突變／重複列／空欄／欄數」變成載入期就會 FAIL 的契約。
  **第 2 輪二審（verdict `request-changes`）後**：上面那支 LK-M1 本身被抓到是「假死因」——
  錨點是行中片段，『換成』尾的 `# MUTANT: …` 把該行後面還有的 `*GLOBS],` 吞掉 →
  `SyntaxError: '[' was never closed`（紅是紅，但紅在 parse error，對「掃描範圍要含未追蹤檔」
  零證據力）；同一型態的 round-1 F2（SM-M1 rc=127）也是。所以除了修那一列，還加了**語法哨兵**
  （見下），把這整類假死因變成載入期 FAIL。

為什麼突變在 **temp copy** 上做（不是 working tree）：
  突變＝故意把碼改壞；若直接改 working tree，一旦中途中斷就會留下壞碼，
  而且「還原先後 md5 一致」只能靠事後自證。改成「複製一份 → 在副本上動手術」，
  working tree 從頭到尾沒被碰過，且本腳本仍會比對 md5 自證（雙重保險）。

契約：
  * 突變表每列的「原文」必須在目標檔內**恰好出現一次**（找不到或出現兩次＝FAIL，不是 skip）：
    程式碼一改，錨點就失效，這張表會大聲壞掉而不是靜默空過。
  * 突變表的結構錯誤在**載入期**就擋下（不是等 55 秒後的 survivor 報告）：欄數不為 6、
    必要欄位為空、原文＝換成（等價突變＝灌水列）、id 重複、同一（目標檔,原文,換成）重複列、
    整張表空 —— 任一項都直接 FAIL（二審 F3）。
  * 每個 mutant 都先跑一次**未突變的 baseline**（每個 (探針檔, 探針名) 組合只跑一次）：
    baseline 必須綠，否則「紅」不代表突變被咬住，只代表探針本身壞了＝假信心。
  * 「靠語法壞掉才紅」也 FAIL（**語法哨兵**，`SYNTAX_LANGS`×`check_mutated_syntax`）：載入期先靜態
    套用『換成』，再對 `.py` 跑 `compile()`、`.sh`／`.bash` 跑 `bash -n`、`.json` 跑 `json.loads`，
    語法壞掉直接 die。原因：突變若把目標檔弄成 parse error，它會「紅」但死因與要證的語意無關
    （round-1 F2 配 rc=127、第 2 輪 #1 配 SyntaxError）→ 這種列等於沒有證據力。
    ⚠️ 實務提醒：**行中錨點**（該行後面還有內容）的『換成』不可加尾端 `#` 註解。
  * 探針「找不到測試」也算失敗（`ERROR: Found no tests`）——否則打錯名字會被誤讀成 mutant 死亡。
  * 探針**逾時（rc=124）不算 mutant 死亡**：逾時可能是環境問題，把它當「咬住了」
    就是假綠，所以另立狀態並 FAIL。

用法：
  python3 scripts/ci/mutant-must-die.py                 # 跑全表（CI 用）
  python3 scripts/ci/mutant-must-die.py --only V-M1,IMG-M3
  python3 scripts/ci/mutant-must-die.py --list           # 只列表（不跑，供探針做靜態檢查）
  python3 scripts/ci/mutant-must-die.py --no-baseline    # 略過 baseline（快，但失去自證）
  python3 scripts/ci/mutant-must-die.py --keep           # 保留 temp copy 供除錯

退出碼：0 全部 mutant 都死且 working tree 未被動到；1 有任何一列空過／baseline 紅／錨點失效；
        2 參數或環境問題（不是 repo、找不到 bats、表格壞掉）。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

NO_TESTS_MARK = "ERROR: Found no tests"
# 「換成」欄若把目標檔弄成語法錯誤，突變雖然會紅，但死因是 parse error 而不是我們要證的語意
# ——這種「假死因」等於這一列沒有證據力。兩個實例：round-1 F2（SM-M1 掉續行反斜線 →
# `-e: command not found`）與本輪 #1（LK-M1 在**行中**錨點尾加 `#` → 註解吞掉後半行的
# `*GLOBS],` → `SyntaxError: '[' was never closed`）。一律在載入期就擋掉。
SYNTAX_LANGS = {".py": "python", ".sh": "shell", ".bash": "shell", ".json": "json"}
PROBE_TIMEOUT = 300                 # 實測單支探針 1-2 秒；300s 已經是「環境壞了」的量級
PROBE_TIMEOUT_RC = 124              # subprocess timeout 的回傳碼

# 被巢狀呼叫時（本腳本自己也是從 bats 探針裡被叫起來的），外層 bats 的「單次測試」環境變數
# 會污染內層：內層會找不到自己的 test name／tmpdir。只清掉這些，**不能清掉 BATS_ROOT /
# BATS_LIBEXEC** —— 那會讓內層 bats 找不到自己的 libexec
# （實測：`//bats-core/validator.bash: No such file or directory` → baseline 全紅）。
STRIP_ENV_EXACT = {
    "BATS_TMPDIR", "BATS_RUN_TMPDIR", "BATS_SUITE_TMPDIR", "BATS_FILE_TMPDIR",
    "BATS_TEST_TIMEOUT", "BATS_TEST_RETRIES",
}


def die(msg: str, code: int = 2) -> None:
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(code)


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="mutant-must-die：突變測試驅動器")
    p.add_argument("--table", type=Path, help="突變表（預設 <repo>/scripts/ci/mutants.tsv）")
    p.add_argument("--only", default="", help="只跑這些 id（逗號分隔；不打就是全表）")
    p.add_argument("--list", action="store_true", dest="list_only", help="只列表，不跑探針")
    p.add_argument("--no-baseline", action="store_true", help="略過未突變的 baseline 驗證")
    p.add_argument("--keep", action="store_true", help="保留臨時副本（除錯用）")
    return p.parse_args(argv)


def repo_root() -> Path:
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, check=False)
    if out.returncode != 0:
        die(f"這裡不是 git repo（{out.stderr.strip()}）")
    return Path(out.stdout.strip())


class Mutant:
    __slots__ = ("mid", "target", "find", "replace", "probe_file", "probe")

    def __init__(self, row: list[str], lineno: int) -> None:
        if len(row) != 6:
            die(f"突變表第 {lineno} 列有 {len(row)} 欄（應為 6 欄，用 tab 分隔）")
        self.mid, self.target, self.find, self.replace, self.probe_file, self.probe = row
        # `replace` 允許是空字串（＝合法的「刪掉這一行」突變），其餘五欄不可空 —— 空欄會讓
        # `--list` 的行與 MMD-1 的統計對不上（4 欄減測）靜默失真。
        for label, value in (("id", self.mid), ("目標檔", self.target), ("原文", self.find),
                             ("探針檔", self.probe_file), ("探針名", self.probe)):
            if not value:
                die(f"突變表第 {lineno} 列的「{label}」是空的（六欄只有「換成」可空）")
        # TMO-066 二審 F3：防「灌水列」——原文＝換成等於什麼都沒改（等價突變）。實跑時它會被當成
        # survivor 而紅，但那是 55 秒之後的事；在載入期就擋掉，順便把死因講清楚。
        if self.find == self.replace:
            die(f"突變表第 {lineno} 列（{self.mid}）的『原文』與『換成』相同 → 等價突變（什麼都沒改）")


def syntax_problem(rel: str, text: str) -> str:
    """檢查「突變後」的檔案內容語法；回傳錯誤訊息（空字串＝通過或不必檢查）。"""
    lang = SYNTAX_LANGS.get(Path(rel).suffix)
    if lang == "python":
        try:
            compile(text, rel, "exec")
        except SyntaxError as exc:
            return f"SyntaxError: {exc.msg}（第 {exc.lineno} 行）"
    elif lang == "shell":
        with tempfile.NamedTemporaryFile("w", suffix=Path(rel).suffix, delete=False,
                                         encoding="utf-8") as fh:
            fh.write(text)
            tmp = fh.name
        try:
            done = subprocess.run(["bash", "-n", tmp], capture_output=True, text=True, check=False)
            if done.returncode != 0:
                tail = [ln for ln in done.stderr.strip().splitlines() if ln.strip()]
                return tail[-1] if tail else "bash -n 失敗"
        finally:
            os.unlink(tmp)
    elif lang == "json":
        try:
            json.loads(text)
        except json.JSONDecodeError as exc:
            return f"JSONDecodeError: {exc.msg}（第 {exc.lineno} 行）"
    return ""


def check_mutated_syntax(m: Mutant, root: Path, lineno: int) -> None:
    """載入期就把「語法壞掉型」的假死因擋掉（見 SYNTAX_LANGS 註解）。

    只檢查語法可機械判定的目標檔（.py／.sh／.bash／.json）；`.md`／`.tsv` 等文字／資料檔
    沒有語法概念，其「文字契約鎖」性質另在 CONTRIBUTING 分類說明。
    """
    if Path(m.target).suffix not in SYNTAX_LANGS:
        return
    src = root / m.target
    if not src.is_file():
        return                      # 目標檔不存在由 main 的 missing 檢查負責
    text = src.read_text(encoding="utf-8")
    if m.find not in text:
        return                      # 錨點失效由 MMD-4／執行期負責，這裡只判語法
    problem = syntax_problem(m.target, text.replace(m.find, m.replace))
    if problem:
        die(f"突變表第 {lineno} 列（{m.mid}）的『換成』會讓目標檔語法壞掉 → 假死因"
            f"（就算紅了也不算咬住）：{problem}")


def load_table(path: Path, root: Path) -> list[Mutant]:
    if not path.is_file():
        die(f"找不到突變表：{path}")
    rows: list[Mutant] = []
    seen: set[str] = set()
    seen_mutations: set[tuple[str, str, str]] = set()
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        mutant = Mutant(line.split("\t"), lineno)
        if mutant.mid in seen:
            die(f"突變表 id 重複：{mutant.mid}（第 {lineno} 列）")
        seen.add(mutant.mid)
        # 同一個（目標檔、原文、換成）出現兩次＝同一支 mutant 換個 id 再填一次，
        # 那就只是把「48 支」這個數字灌大（二審 F3：同探針名可重用墊數）。
        # 注意：不同突變共用同一支探針是**合法的**（一個測試本來就可以咬多支 mutant）。
        key = (mutant.target, mutant.find, mutant.replace)
        if key in seen_mutations:
            die(f"突變表重複列：{mutant.mid} 與前面的列同（目標檔、原文、換成）（第 {lineno} 列）")
        seen_mutations.add(key)
        check_mutated_syntax(mutant, root, lineno)
        rows.append(mutant)
    if not rows:
        die(f"突變表是空的（{path}）→ 這支檢查會變成空過")
    return rows


def md5(path: Path) -> str:
    return hashlib.md5(path.read_bytes()).hexdigest()


def make_copy(root: Path, dest: Path) -> int:
    """把 working tree 的「tracked + 未忽略的未追蹤」檔案複製成一份可丟棄的副本。

    用 `git ls-files -co --exclude-standard`（不是 HEAD 的內容）：CI 跑的是 PR 的
    working tree，本機跑的是當下未 commit 的修改 —— 兩者一致才不會「本機綠、CI 紅」。
    """
    listing = subprocess.run(["git", "ls-files", "-co", "--exclude-standard"],
                             cwd=root, capture_output=True, text=True, check=False)
    if listing.returncode != 0:
        die(f"git ls-files 失敗：{listing.stderr.strip()}")
    files = [f for f in listing.stdout.splitlines() if f]
    if not files:
        die("列舉不到任何檔案（列舉器壞了）")
    copied = 0
    for rel in files:
        src = root / rel
        if not src.is_file():          # 已刪除但仍在索引裡的檔案
            continue
        dst = dest / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        copied += 1
    # 讓副本自己有 .git：部分探針用 `git rev-parse --show-toplevel` 找 repo root
    subprocess.run(["git", "init", "-q"], cwd=dest, check=False)
    # PoC 專用 venv 是 gitignored → 上面那輪複製不會帶進來。但需要 venv 的探針
    # （M6.3 系列走 need_poc_venv）會在副本裡直接紅 → baseline 紅 → 整個突變套件死。
    # 把原 venv 以 symlink 掛進副本：venv 是自解相對的（bin/python → base python，
    # site-packages 由 pyvenv.cfg 定位），從任何路徑掛過去都可用。
    venv_rel = "skills/dav-developer/PoC/.venv"
    venv_src = root / venv_rel
    venv_dst = dest / venv_rel
    if venv_src.is_dir() and not venv_dst.exists():
        venv_dst.parent.mkdir(parents=True, exist_ok=True)
        venv_dst.symlink_to(venv_src.resolve(), target_is_directory=True)
    return copied


def run_probe(copy_dir: Path, probe_file: str, probe: str) -> tuple[int, str]:
    env = {k: v for k, v in os.environ.items()
           if k not in STRIP_ENV_EXACT and not k.startswith("BATS_TEST_")}
    try:
        # 為什麼用 errors="replace" 而不是 text=True（嚴格解碼）：
        #   突變的本質就是「把檔案改成壞的」——若被截斷的字串切在**多位元組字元中間**
        #   （例如中文、emoji），探針輸出就會含**不合法**的 UTF-8 位元組序列。
        #   嚴格解碼會在此時丟 UnicodeDecodeError → 整個 harness **崩潰**，
        #   讓「mutant 該死的紅」變成「harness 自己壞掉」→ 整張表中止（其餘 mutant 從未被驗）。
        #   這不是放寬判定：rc 才是判定依據，輸出只是拿來印出「mutant 死了」的證據；
        #   把無法解碼的位元組換成 U+FFFD 不影響 rc，也不影響 baseline/mutant 的對照邏輯。
        done = subprocess.run(["bats", probe_file, "-f", probe], cwd=copy_dir,
                              capture_output=True, encoding="utf-8", errors="replace",
                              env=env, timeout=PROBE_TIMEOUT)
    except FileNotFoundError:
        die("找不到 bats（請先安裝並放進 PATH）")
    except subprocess.TimeoutExpired:
        return PROBE_TIMEOUT_RC, f"timeout > {PROBE_TIMEOUT}s"
    return done.returncode, (done.stdout + done.stderr)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = repo_root()
    table = args.table or (root / "scripts/ci/mutants.tsv")
    mutants = load_table(table, root)
    if args.only:
        wanted = [w.strip() for w in args.only.split(",") if w.strip()]
        mutants = [m for m in mutants if m.mid in wanted]
        if not mutants:
            die(f"--only 沒有命中任何 mutant：{args.only}")
    if args.list_only:
        for m in mutants:
            print(f"{m.mid}\t{m.target}\t{m.probe_file}\t{m.probe}")
        print(f"共 {len(mutants)} 支 mutant", file=sys.stderr)
        return 0

    missing = [m.target for m in mutants if not (root / m.target).is_file()]
    if missing:
        die(f"突變表指到不存在的檔案：{missing}")
    before = {m.target: md5(root / m.target) for m in mutants}

    workdir = Path(tempfile.mkdtemp(prefix="mutant-must-die."))
    pristine = workdir / "pristine"
    copy_dir = workdir / "copy"
    copy_dir.mkdir()
    pristine.mkdir()
    try:
        n = make_copy(root, copy_dir)
        print(f"副本：{copy_dir}（{n} 檔，含未 commit 的修改）\n")
        for m in mutants:
            dst = pristine / m.target
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(copy_dir / m.target, dst)
            if m.find not in (copy_dir / m.target).read_text(encoding="utf-8"):
                print(f"  {m.mid:<8} 錨點在副本裡找不到 → FAIL")
                return 1

        if not args.no_baseline:
            keys = sorted({(m.probe_file, m.probe) for m in mutants})
            print(f"baseline（未突變，必須綠）：{len(keys)} 組")
            for probe_file, probe in keys:
                rc, out = run_probe(copy_dir, probe_file, probe)
                tag = "綠" if rc == 0 else "紅"
                print(f"  {probe_file} -f {probe} → {tag}")
                if NO_TESTS_MARK in out:
                    die(f"探針名打錯：{probe_file} -f {probe} 找不到測試")
                if rc != 0:
                    print(out[-2000:], file=sys.stderr)
                    die(f"baseline 紅：{probe_file} -f {probe}（探針本身壞了 → 後面的紅沒有意義）")
            print()

        print(f"突變（每支都必須紅）：{len(mutants)} 支")
        survivors: list[str] = []
        for m in mutants:
            target = copy_dir / m.target
            text = target.read_text(encoding="utf-8")
            hits = text.count(m.find)
            if hits != 1:
                print(f"  {m.mid:<8} 錨點出現 {hits} 次（應為 1）→ 這一列已失效，請更新突變表")
                survivors.append(f"{m.mid}（錨點失效）")
                continue
            target.write_text(text.replace(m.find, m.replace), encoding="utf-8")
            rc, out = run_probe(copy_dir, m.probe_file, m.probe)
            shutil.copy2(pristine / m.target, target)      # 還原副本，下一個 mutant 從乾淨狀態開始
            if NO_TESTS_MARK in out:
                print(f"  {m.mid:<8} 探針找不到測試（名字/x 掉了）→ FAIL")
                survivors.append(f"{m.mid}（探針名失效）")
                continue
            if rc == PROBE_TIMEOUT_RC:
                print(f"  {m.mid:<8} 探針逾時（> {PROBE_TIMEOUT}s）→ 不算咬住（視為環境問題）")
                survivors.append(f"{m.mid}（探針逾時）")
                continue
            killed = rc != 0
            print(f"  {m.mid:<8} {m.probe_file} -f {m.probe} → rc={rc} "
                  f"{'紅（mutant 死了）' if killed else '綠（mutant 活著！探針咬不住）'}")
            if not killed:
                survivors.append(m.mid)
    finally:
        if args.keep:
            print(f"\n（--keep）臨時副本保留在：{workdir}")
        else:
            shutil.rmtree(workdir, ignore_errors=True)

    print()
    changed = [t for t, want in before.items() if md5(root / t) != want]
    if changed:
        print(f"FAIL: working tree 被動到了（不該發生）：{changed}", file=sys.stderr)
        return 1
    print(f"working tree 自證：{len(before)} 個目標檔 md5 全數未變"
          f"（突變只發生在副本 {workdir.name if args.keep else '（已刪）'}）")

    if survivors:
        print(f"FAIL: {len(survivors)} 支 mutant 還活著：{', '.join(survivors)}")
        print("→ 補一支會紅的探針，或確認這個突變真的無害後把它從表裡拿掉（並說明理由）")
        return 1
    print(f"OK: {len(mutants)} 支 mutant 全部死亡（每支都有綠 baseline 對照）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
