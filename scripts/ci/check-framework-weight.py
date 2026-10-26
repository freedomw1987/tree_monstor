#!/usr/bin/env python3
"""scripts/ci/check-framework-weight.py

框架體重守門 + 儀表板（TMO-082「第二刀：A+D」）。

**做咩**：
  1. 量度每個 skill 的 **context 成本**（SKILL.md + 支援 .md 嘅行數）——
     呢個係 agent 每次觸發 skill 真金白銀要讀落 context 嘅量。
  2. 守住 context 預算（per-skill cap + 總量 cap）：防止支援檔再膨脹。
  3. 守住 **指標完整性**：SKILL.md 點名嘅子檔必須存在且非空
     （空過 = agent 順指標讀到空檔 = 假覆蓋）。
  4. 守住「框架／產品」行數比 **不得明顯上升**（baseline + tolerance）。
  5. 印出儀表板（per-skill context 排行、產物線檔案數）。

**點解 ratio 唔可以直接當硬上限**：tests/ 係安全網，加探針會推高 ratio。
所以用 **baseline + tolerance**（ratchet）：明顯上升先紅，正常加測試唔會誤紅；
真係要加，就顯式改 baseline（改 baseline 係一件「有記錄、可 review」嘅事）。

用法：
    python3 scripts/ci/check-framework-weight.py [--root DIR] [--json]

退出碼：
    0 = 全部通過；1 = 有違規（列印每項）；2 = 用法 / 環境錯誤（例如掃唔到 skills）
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from pathlib import Path

# 目錄 / 檔案排除清單：量度嘅係「會被讀 / 會被改」嘅內容，唔係執行期產物
SKIP_DIRS = {
    ".git", ".venv", "venv", "node_modules", "__pycache__", ".ruff_cache",
    ".pytest_cache", ".mypy_cache", "tmp", ".idea", ".vscode", ".DS_Store",
    "dist", "build", ".next", "site-packages",
    # PoC 執行期產物（Jev 自動 cache / 報告輸出）：唔係內容，唔應該量
    "cache", "report", "reports", "out",
}

# 檔案類型：量度行數嘅對象（純資源檔唔算「行數膨脹」）
COUNTED_SUFFIXES = {
    ".md", ".py", ".sh", ".bats", ".yml", ".yaml", ".json", ".txt", ".js",
    ".ts", ".tsx", ".jsx", ".html", ".css",
}

# 支援 md 嘅定義：skill 目錄內、但唔係主檔亦唔係 CHANGELOG（歷史唔算 context 成本）
CONTEXT_SUPPORT_EXCLUDE = {"SKILL.md", "CHANGELOG.md"}


def git_tracked(root: pathlib.Path) -> list[str] | None:
    """如果 root 本身係 git repo 根，回傳 tracked 檔案清單；否則 None。

    為什麼優先用 tracked 清單：量度嘅係「會被 review / 會被安裝」嘅內容；
    本機生成物（PoC cache、venv、報告）唔應該影響數字（否則本機同 CI 量到唔同結果）。
    """
    import subprocess

    try:
        top = subprocess.run(
            ["git", "-C", str(root), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=15,
        )
        if top.returncode != 0:
            return None
        if pathlib.Path(top.stdout.strip()).resolve() != root:
            return None  # root 係某個 repo 嘅子目錄（例如 probe 用嘅 fixture）→ 行檔案系統
        ls = subprocess.run(
            ["git", "-C", str(root), "ls-files"],
            capture_output=True, text=True, timeout=30,
        )
        if ls.returncode != 0:
            return None
        return ls.stdout.split()
    except (OSError, subprocess.SubprocessError):
        return None


def counted_files(root: pathlib.Path, subdir: str) -> list[pathlib.Path]:
    """回傳 root/<subdir> 內所有需要量度行數嘅檔案（已排序）。"""
    tracked = git_tracked(root)
    if tracked is not None:
        prefix = f"{subdir}/"
        out = []
        for rel in tracked:
            if rel.startswith(prefix):
                p = root / rel
                if p.is_file() and p.suffix in COUNTED_SUFFIXES:
                    out.append(p)
        return sorted(out)

    base = root / subdir
    if not base.exists():
        return []
    out: list[pathlib.Path] = []
    for p in sorted(base.rglob("*")):
        # ⚠️ 只睇**相對於 base** 嘅部分：若連 root 路徑都睇，
        #    將 repo 放喺叫 `tmp/` 或 `cache/` 嘅目錄下（例如 /tmp/foo）會令全部檔案被跳過
        #    → 量度結果變 0 → 守門靜靜哋失去意義（2026-10-26 實測踩到並修正）。
        if any(part in SKIP_DIRS for part in p.relative_to(base).parts):
            continue
        if not p.is_file() or p.suffix not in COUNTED_SUFFIXES:
            continue
        out.append(p)
    return out


def line_count(path: pathlib.Path) -> int:
    try:
        return len(path.read_text(encoding="utf-8", errors="replace").splitlines())
    except OSError:
        return 0


def nonblank_lines(path: pathlib.Path) -> int:
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return 0
    return sum(1 for line in text.splitlines() if line.strip())


def skill_context_cost(skill_dir: pathlib.Path) -> tuple[int, list[tuple[str, int]]]:
    """回傳 (context 行數, [(子檔名, 行數)])。context = SKILL.md + 支援 .md。"""
    main = skill_dir / "SKILL.md"
    total = line_count(main) if main.exists() else 0
    parts: list[tuple[str, int]] = []
    for p in sorted(skill_dir.rglob("*.md")):
        if p.name in CONTEXT_SUPPORT_EXCLUDE:
            continue
        # 同上：只睇相對於 skill 目錄嘅部分（root 路徑含 `tmp/`／`cache/` 唔應該令全檔被跳過）
        if any(part in SKIP_DIRS for part in p.relative_to(skill_dir).parts):
            continue
        n = line_count(p)
        total += n
        parts.append((p.relative_to(skill_dir).as_posix(), n))
    return total, parts


def referenced_subfiles(skill_md: pathlib.Path) -> list[str]:
    """抽檔案內對**同 dir** 子檔嘅明確指標（`./xxx.md`）。

    刻意只捉 `./xxx.md`：
    - 裸名（`workflow.md`、`backlog.md`、`system-design.md`…）喺 repo 裡面**唔一定**係同 dir 子檔
      （好多係 docs/ 嘅產出物名，例如 `DESIGN.md`、`system-design.md`、`backlog.md`）
      → 一律當指標會大量誤紅。
    - `../xxx.md` 係**上一層**（跨目錄）引用，唔算同 dir 指標（regex 用負向 lookbehind 排除）。
    - 裸名引用嘅子檔「被掏空／被刪除」由**庫存檢查**（見 `skill_md_files`）接手：
      唔使解釋邊個名指邊個檔，只要 skill 目錄內任何 `.md` 被掏空或被刪就報。
    """
    import re

    if not skill_md.exists():
        return []
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    explicit = set(re.findall(r"(?<![.\w-])\./([A-Za-z0-9._-]+\.md)", text))
    explicit.discard("SKILL.md")
    explicit.discard("CHANGELOG.md")
    return sorted(explicit)


def skill_md_files(skill_dir: pathlib.Path) -> list[pathlib.Path]:
    """skill 目錄內所有 .md（排除 CHANGELOG）。"""
    out = []
    for p in sorted(skill_dir.rglob("*.md")):
        if p.name == "CHANGELOG.md":
            continue
        if any(part in SKIP_DIRS for part in p.relative_to(skill_dir).parts):
            continue
        out.append(p)
    return out


def tracked_missing_md(skill_dir: pathlib.Path) -> list[str]:
    """git 有記錄、但磁碟上唔見咗嘅 .md（= 被刪除）。"""
    root = skill_dir.parent.parent
    tracked = git_tracked(root)
    if not tracked:
        return []
    prefix = f"{skill_dir.parent.name}/{skill_dir.name}/"
    out = []
    for rel in tracked:
        if rel.startswith(prefix) and rel.endswith(".md"):
            if not (root / rel).is_file():
                out.append(rel[len(prefix):])
    return sorted(out)


def artifact_counts(root: pathlib.Path) -> dict[str, int]:
    """產物線檔案數（每個 US 衍生了幾多份檔案 → 衍生膨脹指標）。"""
    out = {}
    for sub in ("req", "ac", "reconcile", "deliverable", "prd"):
        d = root / "docs" / sub
        out[sub] = len([p for p in d.glob("*") if p.is_file()]) if d.is_dir() else 0
    return out


def measure(root: pathlib.Path) -> dict:
    skills_dir = root / "skills"
    skill_dirs = sorted(p for p in skills_dir.iterdir() if p.is_dir() and (p / "SKILL.md").exists()) \
        if skills_dir.is_dir() else []

    skills = []
    for d in skill_dirs:
        cost, parts = skill_context_cost(d)
        skills.append({
            "name": d.name,
            "context_lines": cost,
            "subfiles": parts,
            "subfile_count": len(parts),
        })

    # 產品層 = skills/ 內嘅可執行內容（唔係 .md）；context 層 = skills/ 內所有 .md
    product_lines = 0
    context_lines = 0
    for p in counted_files(root, "skills"):
        if p.suffix == ".md":
            context_lines += line_count(p)
        else:
            product_lines += line_count(p)

    framework_lines = 0
    for sub in ("tests", "docs", "scripts", "lib", ".github"):
        for p in counted_files(root, sub):
            framework_lines += line_count(p)
    install = root / "install.sh"
    if install.is_file():
        framework_lines += line_count(install)

    ratio = (framework_lines + context_lines) / product_lines if product_lines else 0.0
    return {
        "skills": skills,
        "total_context_lines": sum(s["context_lines"] for s in skills),
        "product_lines": product_lines,
        "context_lines": context_lines,
        "framework_lines": framework_lines,
        "ratio": round(ratio, 4),
        "artifacts": artifact_counts(root),
    }


def check(root: pathlib.Path, cfg: dict, m: dict) -> list[str]:
    """回傳違規清單（空 list = 全部通過）。"""
    problems: list[str] = []

    min_skills = int(cfg.get("min_skills", 1))
    if len(m["skills"]) < min_skills:
        problems.append(
            f"只列舉到 {len(m['skills'])} 個 skill（< {min_skills}）→ 枚舉可能壞了（防空過），root={root}"
        )
        return problems  # 枚舉壞咗，後續檢查無意義（fail-closed）

    caps = cfg.get("skill_caps", {})
    default_cap = int(cfg.get("default_skill_cap", 0))
    total_cap = int(cfg.get("total_context_cap", 0))

    # ⚠️ 設定值 fail-closed：值被設成 0 / 缺欄 → 守門會「靜靜哋唔檢查」（假綠方向）。
    #    呢個係 Reviewer 二審 P2-1 指出的洞：原本 `if cap and ...` 會令 cap=0 變成無檢查。
    if default_cap <= 0:
        problems.append("設定檔 `default_skill_cap` 必須 > 0（0 ＝ 守門靜靜哋失效）")
    if total_cap <= 0:
        problems.append("設定檔 `total_context_cap` 必須 > 0（0 ＝ 守門靜靜哋失效）")
    for name in (s["name"] for s in m["skills"]):
        if int(caps.get(name, default_cap)) <= 0:
            problems.append(f"設定檔 `skill_caps.{name}` 必須 > 0（0 ＝ 守門靜靜哋失效）")
    r_cfg = cfg.get("ratio", {})
    baseline = float(r_cfg.get("baseline", 0))
    tolerance = float(r_cfg.get("tolerance", 0))
    if baseline <= 0:
        problems.append("設定檔 `ratio.baseline` 必須 > 0（0 ＝ ratio 守門靜靜哋失效）")
    if not (0 < tolerance <= 0.5):
        problems.append("設定檔 `ratio.tolerance` 必須喺 (0, 0.5] 之內（太大 ＝ 守門形同虛設）")
    if m["product_lines"] <= 0:
        problems.append(
            f"產品層量到 0 行 → ratio 冇分母、ratio 守門會靜靜哋失效（fail-closed），root={root}"
        )

    for s in m["skills"]:
        cap = int(caps.get(s["name"], default_cap))
        if cap and s["context_lines"] > cap:
            problems.append(
                f"skill `{s['name']}` context {s['context_lines']} 行 > 上限 {cap} 行"
                f"（SKILL.md + {s['subfile_count']} 個支援 .md）"
            )
        # 指標完整性：
        #   ① 明確指標（`./xxx.md`）→ 必須存在且非空
        #   ② 庫存檢查 → skill 目錄內任何 .md 被掏空／被刪除都要報（唔使解釋裸名引用）
        skill_dir = root / "skills" / s["name"]
        for md in [skill_dir / "SKILL.md"] + skill_md_files(skill_dir):
            if not md.is_file():
                continue
            where = md.relative_to(root).as_posix()
            for ref in referenced_subfiles(md):
                target = md.parent / ref
                if not target.is_file():
                    problems.append(f"`{where}` 指標 `{ref}` 指向唔存在嘅檔案")
                elif nonblank_lines(target) < 8:
                    problems.append(f"`{where}` 指標嘅子檔 `{ref}` 有效行 < 8（＝被掏空）")
        for md in skill_md_files(skill_dir):
            if nonblank_lines(md) < 8:
                problems.append(
                    f"`{md.relative_to(root).as_posix()}` 有效行 < 8（＝被掏空）")
        for rel in tracked_missing_md(skill_dir):
            problems.append(
                f"`skills/{s['name']}/{rel}` 已被刪除（git 有記錄、磁碟上冇）")

    if total_cap and m["total_context_lines"] > total_cap:
        problems.append(
            f"全部 skill 嘅 context 總量 {m['total_context_lines']} 行 > 上限 {total_cap} 行"
        )

    if baseline and m["ratio"] > baseline + tolerance:
        problems.append(
            f"框架／產品行數比 {m['ratio']} > baseline {baseline} + tolerance {tolerance}"
            f"（框架 {m['framework_lines']} 行、context {m['context_lines']} 行、產品 {m['product_lines']} 行）"
            f"→ 框架膨脹過快；請先做減法，或顯式更新 docs/ci/framework-weight.json 嘅 baseline"
        )

    return problems


def print_dashboard(m: dict, cfg: dict) -> None:
    caps = cfg.get("skill_caps", {})
    default_cap = int(cfg.get("default_skill_cap", 0))
    print("── context 成本（SKILL.md + 支援 .md；= agent 觸發 skill 嘅讀入量）──")
    print(f"{'skill':<22} {'context':>8} {'子檔':>5} {'上限':>7}")
    for s in sorted(m["skills"], key=lambda x: -x["context_lines"]):
        cap = int(caps.get(s["name"], default_cap)) or "-"
        print(f"{s['name']:<22} {s['context_lines']:>8} {s['subfile_count']:>5} {str(cap):>7}")
    print(f"{'合計':<22} {m['total_context_lines']:>8}")
    print()
    print("── 框架體重 ──")
    print(f"產品層（skills 可執行）: {m['product_lines']} 行")
    print(f"context 層（skills .md）: {m['context_lines']} 行")
    print(f"框架層（tests+docs+scripts+lib+ci+install.sh）: {m['framework_lines']} 行")
    print(f"框架／產品比: {m['ratio']}")
    print()
    print("── 產物線檔案數（衍生膨脹指標）──")
    for k, v in m["artifacts"].items():
        print(f"docs/{k}: {v}")


def main() -> int:
    ap = argparse.ArgumentParser(description="框架體重守門 + 儀表板")
    ap.add_argument("--root", default=None, help="repo 根目錄（預設：本腳本所在 repo）")
    ap.add_argument("--json", action="store_true", help="輸出 JSON（唔印儀表板）")
    ap.add_argument("--config", default=None, help="設定檔路徑（預設 <root>/docs/ci/framework-weight.json）")
    args = ap.parse_args()

    here = pathlib.Path(__file__).resolve().parent
    root = pathlib.Path(args.root).resolve() if args.root else here.parent.parent
    cfg_path = pathlib.Path(args.config) if args.config else root / "docs" / "ci" / "framework-weight.json"

    if not (root / "skills").is_dir():
        print(f"FAIL: {root} 下搵唔到 skills/ → 檢查唔適用於該專案", file=sys.stderr)
        return 2
    if not cfg_path.is_file():
        print(f"FAIL: 搵唔到設定檔 {cfg_path}", file=sys.stderr)
        return 2

    try:
        cfg = json.loads(cfg_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FAIL: 設定檔讀唔到 / 解析失敗：{exc}", file=sys.stderr)
        return 2

    m = measure(root)
    problems = check(root, cfg, m)

    if args.json:
        print(json.dumps({"measurement": m, "problems": problems}, ensure_ascii=False, indent=2))
    else:
        print_dashboard(m, cfg)
        print()
        if problems:
            print(f"FAIL: {len(problems)} 項框架體重違規：")
            for p in problems:
                print(f"  - {p}")
        else:
            print("OK: context 預算、指標完整性、框架／產品比全部通過")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
