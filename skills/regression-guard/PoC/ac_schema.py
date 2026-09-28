"""
AC schema parser — 把 docs/ac/US-XXX.md 解析成結構化 ACContext list。

US-XXX.md 已知結構（從 US-101.md 觀察）：
  # US-XXX ...
  > 對應 Backlog: ...
  > 最後更新: ...
  ## 背景
  ## Given / When / Then
  - **Given** ...
    **When** ...
    **Then** ...
    **And** ...
  - **Given** ...   (下一條 AC)
  ## DoD ...
  ## 變更歷史 ...
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

from jev_oracle import ACContext


# 一條 AC 的 Given / When / Then / And
@dataclass
class ParsedAC:
    ac_id: str
    story_id: str
    given: str
    when: str
    then: str
    additional_and: list[str] = field(default_factory=list)


@dataclass
class ParsedStory:
    story_id: str           # e.g. "US-101"
    title: str              # e.g. "AC 範本"
    file: Path
    acs: list[ParsedAC] = field(default_factory=list)
    raw: str = ""

    def to_contexts(self) -> list[ACContext]:
        return [
            ACContext(
                ac_id=ac.ac_id,
                story_id=self.story_id,
                given=ac.given,
                when=ac.when,
                then=ac.then,
                additional_and=ac.additional_and,
            )
            for ac in self.acs
        ]


# 兩種命中形式都要：(a) bullet 起手 `- **Given** ...` (b) 延續行 `**When** ...`
# 兩者皆靠 `**KW** ` 為錨點。
_KW_RE = re.compile(r"\*\*(Given|When|Then|And)\*\*\s+(.+?)(?=\n|$)", re.MULTILINE)


def _group_ac_blocks(body: str) -> list[dict]:
    """
    把 `## Given / When / Then` 段落裡的多條 AC 拆出來。
    一條 AC = 一個 `**Given**` 開始，到下一個 `**Given**` 為止。
    段內同個 bullet block 的 `**When**/**Then**/**And**` 繼續寫入同一條。
    """
    blocks: list[dict] = []
    current = None
    for m in _KW_RE.finditer(body):
        keyword, text = m.group(1), m.group(2).strip()
        if keyword == "Given":
            if current is not None:
                blocks.append(current)
            current = {"given": text, "when": "", "then": "", "and": []}
        elif current is None:
            continue
        elif keyword == "When":
            current["when"] = (current["when"] + " " + text).strip()
        elif keyword == "Then":
            current["then"] = (current["then"] + " " + text).strip()
        elif keyword == "And":
            current["and"].append(text)
    if current is not None:
        blocks.append(current)
    return blocks


def parse_story_file(path: Path) -> ParsedStory:
    raw = path.read_text(encoding="utf-8")
    story_id_match = re.search(r"#\s+(US-\d+)", raw)
    story_id = story_id_match.group(1) if story_id_match else path.stem

    # 取標題：第二行通常 `> 對應 Backlog: ...`，常見結構下面會有「作為 ... 我想 ...」
    # 簡化：直接抓第一個 H1 後面緊接的非空 content 或 h1 line 本身
    title_match = re.search(rf"^#\s+{re.escape(story_id)}\s+(.+)$", raw, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else ""

    # 抓 Given / When / Then 段
    gwt_section = re.search(
        r"##\s+Given\s*/\s*When\s*/\s*Then\s*\n(.+?)(?=\n##\s+|\Z)",
        raw, re.DOTALL,
    )
    section_body = gwt_section.group(1) if gwt_section else raw
    raw_blocks = _group_ac_blocks(section_body)

    acs = []
    for i, blk in enumerate(raw_blocks, start=1):
        if not blk.get("then"):
            continue  # 沒有 Then 不算完整 AC
        acs.append(ParsedAC(
            ac_id=f"{story_id}-AC{i:02d}",
            story_id=story_id,
            given=blk.get("given", ""),
            when=blk.get("when", ""),
            then=blk.get("then", ""),
            additional_and=blk.get("and", []),
        ))

    return ParsedStory(
        story_id=story_id,
        title=title,
        file=path,
        acs=acs,
        raw=raw,
    )
