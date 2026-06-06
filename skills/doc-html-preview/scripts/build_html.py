"""build_html.py — Convert a single MD file to one or two standalone HTMLs.

Renders:
  1. Engineering version  → <name>.html
  2. Boss version         → <name>-boss.html  (if boss summary JSON exists,
                              or MD has `## 👀 老闆版摘要` override section)

Both HTMLs are self-contained (CSS inlined, no external assets) so they open
via file:// in any browser.

Usage:
    python3 build_html.py engineering <src.md> <out.html> <project> <built_at>
    python3 build_html.py boss       <src.md> <out.html> <project> <built_at> <meta.json>
"""
import sys
import re
import json
import subprocess
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent.resolve()
TEMPLATE_DIR = SCRIPT_DIR.parent / "templates"
CSS_FILE = TEMPLATE_DIR / "github-like.css"
BOSS_TEMPLATE = TEMPLATE_DIR / "boss-template.html"


def load_css() -> str:
    return CSS_FILE.read_text(encoding="utf-8")


def render_pandoc(md_path: str) -> str:
    """Run pandoc on the MD file and return raw HTML."""
    proc = subprocess.run(
        [
            "pandoc",
            "--from=gfm",
            "--to=html5",
            "--standalone",
            "--section-divs",
            str(md_path),
        ],
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout


def render_frag(md_text: str) -> str:
    """Run pandoc on a MD fragment and return HTML (no standalone wrapper)."""
    proc = subprocess.run(
        [
            "pandoc",
            "--from=gfm",
            "--to=html5",
            "--section-divs",
        ],
        input=md_text,
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout


def build_engineering(src: str, out: str, fname: str, project: str, built_at: str) -> None:
    """Render the engineering version (1:1 MD → HTML)."""
    css = load_css()
    raw_html = render_pandoc(src)

    # Strip pandoc's default <style> block — we replace with ours.
    html = re.sub(r"<style>.*?</style>\s*", "", raw_html, flags=re.DOTALL)

    # Wrap body content in .markdown-body div.
    html = re.sub(
        r"<body([^>]*)>",
        r'<body\1>\n<div class="markdown-body">',
        html, count=1,
    )
    banner = (
        f'<div class="preview-banner">'
        f'&#128196; Preview of <code>docs/{fname}.md</code> &mdash; built {built_at} by '
        f'<code>hermes dev doc-build --project {project}</code>. '
        f'MD is source of truth; HTML is a generated artifact (do not commit). '
        f'<a href="../{fname}.md">View MD source</a> &middot; '
        f'<a href="{fname}-boss.html">View boss (decision) version</a>'
        f'</div>'
    )
    html = re.sub(
        r"</body>",
        f'</div>\n{banner}\n</body>',
        html, count=1,
    )

    # Inject our CSS as the only <style> in <head>.
    style_block = f"<style>\n{css}\n</style>"
    html = re.sub(
        r"</head>",
        f"{style_block}\n</head>",
        html, count=1,
    )

    Path(out).write_text(html, encoding="utf-8")


def extract_boss_override(md_path: str) -> str | None:
    """If MD has `## 👀 老闆版摘要` section, return rendered HTML of that section.
    Otherwise return None.
    """
    text = Path(md_path).read_text(encoding="utf-8")
    m = re.search(r"^##\s*👀\s*老闆版摘要\s*$", text, re.MULTILINE)
    if not m:
        return None
    start = m.end()
    rest = text[start:]
    nxt = re.search(r"^##\s+", rest, re.MULTILINE)
    body = rest[: nxt.start()] if nxt else rest
    body = body.strip()
    if not body:
        return None
    inner = render_frag(body)
    return f'<div class="boss-md-override">{inner}</div>'


def build_boss(src: str, out: str, fname: str, project: str, built_at: str, meta_path: str) -> None:
    """Render the boss version (decision-oriented summary)."""
    css = load_css()
    template = BOSS_TEMPLATE.read_text(encoding="utf-8")

    # Resolve content: MD override > meta JSON > placeholder
    override = extract_boss_override(src)
    summary = None
    if Path(meta_path).exists():
        try:
            summary = json.loads(Path(meta_path).read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            summary = None

    one_liner = "（待 developer profile 寫一句話）"
    cards_html = ""
    disclaimer_html = ""
    decisions_html = ""
    risks_html = ""
    generated_at = built_at
    generated_by = "AI (developer profile / CEO subagent)"

    if summary:
        one_liner = summary.get("one_liner", one_liner)
        cards = summary.get("cards", {}) or {}
        card_layout = [
            ("timeline", "⏱️ 幾耐", "timeline"),
            ("cost", "💰 幾錢", "cost"),
            ("mitigation", "🛡️ 避險", "mitigation"),
        ]
        cards_inner = ""
        for key, label, json_key in card_layout:
            value = cards.get(json_key, "—")
            cards_inner += (
                f'<div class="boss-card">'
                f'<span class="icon">{label.split()[0]}</span>'
                f'<div class="label">{label.split(maxsplit=1)[1]}</div>'
                f'<div class="value">{value}</div>'
                f'</div>'
            )
        cards_html = f'<div class="boss-cards">{cards_inner}</div>'

        disclaimer = cards.get("disclaimer", "")
        if disclaimer:
            disclaimer_html = f'<div class="boss-disclaimer">{disclaimer}</div>'

        decisions = summary.get("decisions", []) or []
        if decisions:
            decisions_inner = ""
            for d in decisions:
                blocking = d.get("blocking", False)
                blocking_tag = '<span class="blocking-tag">要你拍板</span>' if blocking else ""
                options_html = ""
                for opt in d.get("options", []):
                    label = opt.get("label", "")
                    pros = opt.get("pros", "")
                    cons = opt.get("cons", "")
                    options_html += (
                        f'<div class="option">'
                        f'<span class="opt-label">{label}</span>'
                        f'<span class="opt-pros">+ {pros}</span> '
                        f'<span class="opt-cons">- {cons}</span>'
                        f'</div>'
                    )
                decisions_inner += (
                    f'<div class="boss-decision">'
                    f'<div class="question">❓ {d.get("question", "")} {blocking_tag}</div>'
                    f'<div class="options">{options_html}</div>'
                    f'</div>'
                )
            decisions_html = f'<div class="boss-decisions"><h2>拍板事項</h2>{decisions_inner}</div>'

        risks = summary.get("risks_boss_speak", []) or []
        if risks:
            risk_items = "".join(f"<li>{r}</li>" for r in risks)
            risks_html = f'<div class="boss-risks"><h2>風險（老闆話）</h2><ul>{risk_items}</ul></div>'

        generated_at = summary.get("generated_at", built_at)
        generated_by = summary.get("generated_by", generated_by)

    if override:
        # MD override wins — use it as the body content, and derive one_liner
        # from the first non-empty paragraph of the override section
        content = override
        # Extract first <p> text as the one-liner
        m = re.search(r"<p>(.*?)</p>", override, re.DOTALL)
        if m:
            one_liner_override = re.sub(r"<[^>]+>", "", m.group(1)).strip()
            if one_liner_override:
                one_liner = one_liner_override
    elif summary:
        content = cards_html + disclaimer_html + decisions_html + risks_html
    else:
        content = (
            '<div class="boss-placeholder">'
            '<h2>👀 老闆版摘要待生成</h2>'
            f'<p>未有 <code>docs/_meta/{fname}.json</code>，亦無 MD 內 <code>## 👀 老闆版摘要</code> 覆寫。</p>'
            f'<p>請由 Developer profile (或 kanban CEO worker) 生成 boss summary JSON，'
            f'或直接喺 <code>docs/{fname}.md</code> 加 <code>## 👀 老闆版摘要</code> section。</p>'
            '</div>'
        )

    html = template.replace("__CSS__", css).replace("__TITLE__", fname) \
                   .replace("__ONE_LINER__", one_liner) \
                   .replace("__CONTENT__", content) \
                   .replace("__HTML_FILENAME__", fname) \
                   .replace("__BASENAME__", fname) \
                   .replace("__GENERATED_AT__", generated_at) \
                   .replace("__GENERATED_BY__", generated_by)

    Path(out).write_text(html, encoding="utf-8")


def main():
    if len(sys.argv) < 3:
        print("Usage: build_html.py {engineering|boss} ...", file=sys.stderr)
        sys.exit(1)

    mode = sys.argv[1]
    if mode == "engineering":
        # build_html.py engineering <src> <out> <fname> <project> <built_at>
        if len(sys.argv) != 7:
            print("engineering mode requires 6 args", file=sys.stderr)
            sys.exit(1)
        _, _mode, src, out, fname, project, built_at = sys.argv
        build_engineering(src, out, fname, project, built_at)
    elif mode == "boss":
        # build_html.py boss <src> <out> <fname> <project> <built_at> <meta.json>
        if len(sys.argv) != 8:
            print("boss mode requires 7 args", file=sys.stderr)
            sys.exit(1)
        _, _mode, src, out, fname, project, built_at, meta_path = sys.argv
        build_boss(src, out, fname, project, built_at, meta_path)
    else:
        print(f"Unknown mode: {mode}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
