"""
M7 — gh_pr_comment.py
構造 PR comment（4 段）並推到當前 PR。

設計：
- 4 段：journey 標題 / 信心度 gating / fix proposal 摘要 / sandbox 建議
- 用 `gh pr comment` CLI 推（需 GITHUB_TOKEN）
- comment 失敗不中斷 pipeline（best-effort）
- 沒有 PR 編號 → 只 print comment 不推

用法：
    .venv/bin/python gh_pr_comment.py \
        --batch-report /tmp/US-M62-batch.json \
        --fix-proposal /tmp/US-M62-fix-proposal-v2.md \
        --pr-number 42
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path


THIS_DIR = Path(__file__).parent


def render_comment(
    *,
    batch_report_path: Path,
    fix_proposal_path: Path | None,
) -> str:
    """構造 4 段 PR comment。"""
    if not batch_report_path.exists():
        return "⚠️ batch report not found"

    batch = json.loads(batch_report_path.read_text(encoding="utf-8"))
    br = batch.get("batch_report", {})
    journey_id = batch.get("journey_id", "?")
    journey_title = batch.get("journey_title", "?")

    # 1. journey 標題
    health_emoji = {"green": "🟢", "yellow": "🟡", "red": "🔴"}.get(
        br.get("overall_health", ""), "?"
    )
    fp_emoji = "🟢" if br.get("fix_priority", 0) < 1.5 else "🟡" if br.get("fix_priority", 0) < 2.5 else "🔴"
    flaky_val = br.get("flaky_measured", {}).get("likelihood") if br.get("flaky_measured") else br.get("flaky_likelihood", 0.0)
    flaky_emoji = "🟢" if flaky_val < 0.05 else "🟡" if flaky_val < 0.20 else "🔴"

    section1 = (
        f"## 🧪 regression-guard Report — `{journey_id}`\n\n"
        f"**{journey_title}**\n\n"
        f"| 維度 | 值 |\n"
        f"|------|----|\n"
        f"| Overall Health | {health_emoji} **{br.get('overall_health', '?').upper()}** |\n"
        f"| Fix Priority | {fp_emoji} {br.get('fix_priority', 0):.2f} |\n"
        f"| Flaky Likelihood | {flaky_emoji} {flaky_val:.2f} |\n"
        f"| Regression Type | `{br.get('regression_type', '?')}` |\n"
    )

    # 2. 信心度 gating
    fp_proposed = (fix_proposal_path and fix_proposal_path.exists())
    if fp_proposed:
        fp_text = fix_proposal_path.read_text(encoding="utf-8")
        # 找「整體信心度」數字
        import re
        m = re.search(r"整體.{0,10}?(\d+\.\d+)", fp_text)
        conf = float(m.group(1)) if m else 0.0
        if conf >= 0.5:
            section2 = f"## 🎯 Fix Proposal\n\n🟢 **信心度 {conf:.2f} ≥ 0.5** → LLM relay 召喚\n\n> 請 review fix_proposal_v2.md 並決定是否 apply"
        else:
            section2 = f"## 🎯 Fix Proposal\n\n🟡 **信心度 {conf:.2f} < 0.5** → reviewer 接手\n\n> 信心度不足，需人工 review 走跡"
    else:
        section2 = "## 🎯 Fix Proposal\n\n_（未產出 fix proposal；設 `JEV_FIX_PROPOSAL=1` 啟用）_"

    # 3. fix proposal 摘要（若有）
    if fp_proposed and fp_text:
        # 抓「## 問題分析」前 200 字
        m = re.search(r"## 問題分析\s*\n+(.+?)(?=\n##|\Z)", fp_text, re.DOTALL)
        if m:
            summary = m.group(1).strip()[:300]
            section3 = f"## 📋 問題分析摘要\n\n{summary}\n"
        else:
            section3 = ""
    else:
        section3 = ""

    # 4. sandbox 建議
    section4 = (
        "## 🛠️ Sandbox 建議\n\n"
        "若想驗證 fix：\n"
        "```bash\n"
        "JEV_FIX_PROPOSAL=1 JEV_FIX_PROPOSAL_V2=1 \\\n"
        "  JEV_PATCH_AND_REVALIDATE=1 JEV_SANDBOX_RUN=1 \\\n"
        "  ./run_pipeline.sh " + journey_id + "\n"
        "```\n"
        "→ 自動跑 M6 → M6.1 → M6.2 → M6.3 完整閉環\n"
    )

    parts = [section1, section2]
    if section3:
        parts.append(section3)
    parts.append(section4)
    parts.append("\n---\n_由 regression-guard skill 自動產生_")
    return "\n\n".join(parts) + "\n"


def post_comment(pr_number: int, body: str, *, dry_run: bool = False) -> tuple[int, str, str]:
    """用 gh pr comment 推 PR。回傳 (rc, stdout, stderr)。"""
    if dry_run:
        print("👀 [dry-run] PR comment body:\n" + body)
        return 0, "", ""

    cmd = ["gh", "pr", "comment", str(pr_number), "--body", body]
    p = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return p.returncode, p.stdout, p.stderr


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="M7 gh pr comment 推 PR")
    parser.add_argument("--batch-report", type=Path, required=True)
    parser.add_argument("--fix-proposal", type=Path)
    parser.add_argument("--pr-number", type=int, help="PR 編號；不提供則 dry-run")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--output", "-o", type=Path, help="把 comment body 寫到檔案")
    args = parser.parse_args(argv[1:])

    if not args.batch_report.exists():
        print(f"❌ batch_report 不存在: {args.batch_report}")
        return 1

    body = render_comment(
        batch_report_path=args.batch_report,
        fix_proposal_path=args.fix_proposal,
    )

    if args.output:
        args.output.write_text(body, encoding="utf-8")
        print(f"📝 Wrote {args.output}  ({args.output.stat().st_size} bytes)")

    if args.dry_run or not args.pr_number:
        print(body)
        return 0

    rc, stdout, stderr = post_comment(args.pr_number, body, dry_run=False)
    if rc != 0:
        print(f"⚠️ gh pr comment 失敗 (rc={rc}): {stderr[:200]}")
        return 0  # 不中斷 pipeline
    print(f"✅ PR #{args.pr_number} comment 已推")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
