"""
M6.2 AC01 — Patch Parser
從 LLM Relay 產出的 fix_proposal_v2.md 抽出 (file, old, new) 三元組。

設計：
- 從「## 建議修正」段抽 code block（支援 ```python / ```diff / ```bash 等）
- 解析 unified diff header：--- a/path / +++ b/path / @@ -X,Y +A,B @@
- 若該段沒 diff，則從「**建議修正**」描述抽檔名 + 「改的內容」段落當 new_text
- 缺欄位 / 格式錯誤回傳明確錯誤（不拋 exception）

用法：
    .venv/bin/python patch_parser.py <path/to/fix_proposal_v2.md>
    .venv/bin/python patch_parser.py <path/to/fix_proposal_v2.md> --json
    或 import：
        from patch_parser import parse_fix_proposal
        result = parse_fix_proposal(md_text)
        # → {"patches": [{"file": "...", "old": "...", "new": "..."}], "errors": [...]}
"""

from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional


# ─── 結果資料結構 ─────────────────────────────────────────────────────────

@dataclass
class PatchOp:
    """一個 patch 操作：(file, old, new) 三元組。"""
    file: str
    old: str
    new: str
    format: str = "unified_diff"   # unified_diff | describe_only
    confidence: float = 0.0        # parser 對自己抽取結果的信心度
    notes: list[str] = field(default_factory=list)


@dataclass
class ParseResult:
    patches: list[PatchOp] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    source_ac: Optional[str] = None
    journey_id: Optional[str] = None
    confidence_overall: float = 0.0

    def to_dict(self) -> dict:
        return {
            "patches": [asdict(p) for p in self.patches],
            "errors": self.errors,
            "source_ac": self.source_ac,
            "journey_id": self.journey_id,
            "confidence_overall": self.confidence_overall,
        }


# ─── 解析邏輯 ────────────────────────────────────────────────────────────

# 找「## 建議修正」段的正則（可能包在 LLM Relay Fix Proposal 區塊內）
SECTION_RECOMMENDED_RE = re.compile(
    r"^##\s*建議修正[^\n]*\n(.*?)(?=^##\s|\Z)",
    re.DOTALL | re.MULTILINE,
)
# 找「## LLM Relay Fix Proposal」段（給整篇掃描）
SECTION_LLM_RELAY_RE = re.compile(
    r"^##\s*LLM Relay Fix Proposal[^\n]*\n(.*?)(?=^##\s|\Z)",
    re.DOTALL | re.MULTILINE,
)
# 找 code block
CODE_BLOCK_RE = re.compile(r"```(\w*)\n(.*?)\n```", re.DOTALL)
# unified diff 解析
DIFF_HEADER_RE = re.compile(r"^---\s+a/(.+?)$", re.MULTILINE)
DIFF_NEW_HEADER_RE = re.compile(r"^\+\+\+\s+b/(.+?)$", re.MULTILINE)
DIFF_HUNK_RE = re.compile(r"^@@.*?@@", re.MULTILINE)


def _parse_unified_diff(code: str) -> list[PatchOp]:
    """從 unified diff code block 抽 (file, old, new) 三元組。"""
    patches = []
    # 找所有 diff header
    headers_a = list(DIFF_HEADER_RE.finditer(code))
    headers_b = list(DIFF_NEW_HEADER_RE.finditer(code))
    if not headers_a or not headers_b:
        return patches

    for ha, hb in zip(headers_a, headers_b):
        file_a = ha.group(1).strip()
        file_b = hb.group(1).strip()
        # file 取 / 後的 basename
        target = file_b.split("/")[-1] if "/" in file_b else file_b

        # 抽該檔的 hunk 區段（從 ha 到下一個 diff header）
        start = ha.start()
        next_a = next((m.start() for m in headers_a if m.start() > ha.start()), len(code))
        hunk_section = code[start:next_a]

        # 收集 old (-) / new (+) 行（不含 --- / +++ header）
        old_lines = []
        new_lines = []
        for line in hunk_section.split("\n"):
            if line.startswith("---") or line.startswith("+++"):
                continue
            if line.startswith("@@"):
                continue
            if line.startswith("-") and not line.startswith("--"):
                old_lines.append(line[1:])
            elif line.startswith("+") and not line.startswith("++"):
                new_lines.append(line[1:])

        if old_lines or new_lines:
            patches.append(PatchOp(
                file=target,
                old="\n".join(old_lines),
                new="\n".join(new_lines),
                format="unified_diff",
                confidence=0.9 if (old_lines and new_lines) else 0.5,
                notes=[f"從 unified diff 抽出（{file_a} → {file_b}）"],
            ))
    return patches


def _parse_describe_only(section_text: str) -> list[PatchOp]:
    """從「**建議修正**：xxx 改 yyy」描述抽 patch。
    啟發式：找 code fence 或反引號包圍的檔名 + 「改的內容」段落。"""
    patches = []

    # 1. 找描述中的檔名（反引號包圍或 `path/to/file.ext` 形式）
    file_refs = re.findall(r"`([\w./\-]+\.(?:py|md|sh|yml|yaml|json|js|ts|html|css))`", section_text)
    if not file_refs:
        # 2. 找「推測」字樣旁邊的檔名
        guess_match = re.search(r"\u63a8\u6e2c[\uff1a:](.+)", section_text)
        if guess_match:
            file_refs = [guess_match.group(1).strip()]

    # 3. 抽「改的內容」段落（在「**建議修正**」後到「**驗證步驟**」前）
    body_match = re.search(
        r"\*\*\u5efa\u8b70\u4fee\u6b63\*\*\uff1a?(.+?)(?=\*\*\u9a57\u8b49\u6b65\u9a5f|\Z)",
        section_text, re.DOTALL,
    )
    body = body_match.group(1).strip() if body_match else section_text[:500]

    if file_refs:
        for f in file_refs:
            patches.append(PatchOp(
                file=f,
                old="",  # 描述型無 old
                new=body,
                format="describe_only",
                confidence=0.4,  # 描述型 parser 信心度低
                notes=["從描述抽（無 unified diff）", "建議人工 review 確認 (file, old, new)"],
            ))
    return patches


def parse_fix_proposal(md_text: str) -> ParseResult:
    """主入口：解析 fix_proposal_v2.md 內容。"""
    result = ParseResult()

    # 抽 source AC / journey
    ac_match = re.search(r"^\*\*AC \u7bc4\u672c\*\*\uff1a?(.+)$", md_text, re.MULTILINE)
    if ac_match:
        result.source_ac = ac_match.group(1).strip()
    journey_match = re.search(r"^# Fix Proposal \u2014 (.+)$", md_text, re.MULTILINE)
    if journey_match:
        result.journey_id = journey_match.group(1).strip()

    # 找「## 建議修正」段
    sec_match = SECTION_RECOMMENDED_RE.search(md_text)
    if not sec_match:
        # fallback: LLM Relay Fix Proposal 整段
        sec_match = SECTION_LLM_RELAY_RE.search(md_text)
    if not sec_match:
        result.errors.append("找不到「## 建議修正」或「## LLM Relay Fix Proposal」段")
        return result

    section_text = sec_match.group(1)

    # 嘗試從 code block 抽 unified diff
    code_blocks = CODE_BLOCK_RE.findall(section_text)
    diff_patches = []
    for lang, code in code_blocks:
        diff_patches.extend(_parse_unified_diff(code))

    if diff_patches:
        result.patches.extend(diff_patches)
    else:
        # fallback: 從描述抽
        describe_patches = _parse_describe_only(section_text)
        if describe_patches:
            result.patches.extend(describe_patches)
            result.errors.append("無 unified diff code block，改用 describe_only（信心度較低）")
        else:
            result.errors.append("「## 建議修正」段內找不到 code block 也找不到檔名引用")

    # 計算整體信心度
    if result.patches:
        result.confidence_overall = sum(p.confidence for p in result.patches) / len(result.patches)
    return result


# ─── CLI ──────────────────────────────────────────────────────────────────

def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("用法: patch_parser.py <path/to/fix_proposal_v2.md> [--json]")
        return 1

    src = Path(argv[1])
    if not src.exists():
        print(f"❌ 檔案不存在：{src}")
        return 1

    md_text = src.read_text(encoding="utf-8")
    result = parse_fix_proposal(md_text)

    if "--json" in argv:
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(f"📖 {src}")
        print(f"   journey_id:        {result.journey_id}")
        print(f"   source_ac:         {result.source_ac}")
        print(f"   patches found:     {len(result.patches)}")
        print(f"   overall_confidence: {result.confidence_overall:.2f}")
        if result.errors:
            print(f"   errors:            {len(result.errors)}")
            for e in result.errors:
                print(f"     - {e}")
        print()
        for i, p in enumerate(result.patches, 1):
            print(f"   [{i}] {p.file}  (format={p.format}, conf={p.confidence:.2f})")
            if p.notes:
                for n in p.notes:
                    print(f"       note: {n}")

    return 0 if result.patches else 2  # 0=有 patches, 2=空


if __name__ == "__main__":
    sys.exit(main(sys.argv))
