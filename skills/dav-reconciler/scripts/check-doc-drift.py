#!/usr/bin/env python3
"""check-doc-drift.py — 文件漂移檢查（D1..D8）

用途：抓「同一件事在多份文件之間各說各話」的字面漂移，不做語意判斷。

檢查類別（見 docs/prd/05-delivery-fidelity.md FR-03）：
  D1  AC 範本狀態 vs backlog 該 US 狀態
  D2  AC 檔的 AC 編號連續且唯一
  D3  PRD 追溯矩陣的 US ID ⊆ backlog 的 US ID（不引用幽靈 ID）
  D4  交付摘要「變更清單」提到的檔案真的存在
  D5  AC 範本 .md 與 .html 的狀態一致
  D6  AC 範本 ↔ 需求錨點檔 對應關係
  D7  對帳表 R-ID 覆蓋率 / 狀態值合法 / 已交付必對帳
  D8  交付摘要的「需求對帳」段與交付狀態一致

rc 契約：0 = 無違規（含全部被白名單豁免）｜1 = 有違規｜2 = 用法 / 環境錯誤
輸出：DRIFT <類> <鍵>: <說明> / WHITELIST <類> <鍵>: <理由> / OK: <n> 項檢查完成，<m> 項豁免
"""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

STATUS_LINE = re.compile(r"狀態[:：]\s*([A-Za-z_一-鿿]+)")
BACKLOG_REF = re.compile(r"對應\s*Backlog[:：]\s*\[?\s*([A-Za-z0-9_-]+)")
AC_HEADING = re.compile(r"^###\s*AC(\d+)\b", re.MULTILINE)
ID_TOKEN = re.compile(r"\b(US|TMO|DE|TECH|INT)-[A-Za-z0-9-]+\b")
ID_CELL = re.compile(r"^[A-Za-z][A-Za-z0-9]*-[A-Za-z0-9-]+$")
STATUS_VALUE = re.compile(
    r"^(PENDING|todo|doing|done|in_progress|blocked|deferred|cancelled|待決|進行中|待辦)",
    re.IGNORECASE,
)
PATH_LIKE = re.compile(r"`([A-Za-z0-9_./~-]+\.(?:md|sh|py|bats|json|yml|yaml|txt|html|toml))`")
KNOWN_PREFIXES = ("skills/", "docs/", "scripts/", "tests/", "lib/", ".github/", "install.sh", "AGENTS.md")
PLACEHOLDER = ("<", ">", "*", "…", "...")

# D4 的生效起點：需求對帳機制上線日。早於此日期的交付摘要不回溯檢查
# （歷史宣稱所指的檔案可能已刪除 / 改名，回溯只會製造假紅）。
DEFAULT_FROM_DATE = "2026-10-26"

VALID_STATUS = ("✅ 已實作", "⚠️ 部分實作", "❌ 未實作", "🚫 已作廢")
GAP_STATUS = ("⚠️ 部分實作", "❌ 未實作")


def norm_emoji(text):
    """去除 emoji 變體選擇符（U+FE0F）。

    必要：`⚠️` 可能帶 U+FE0F、可能不帶（不同工具、不同輸入法）。若不正規化，
    「照 spec 寫的對帳表」會被 D7 判「狀態值不合法」、內嵌表會與權威表判「矛盾」
    （V03 對帳第 3 輪 ③：位元組級落差）。
    """
    return text.replace("️", "")


def anchor_rids(anchor_path):
    """取出錨點檔「用戶原話（唯讀）」段的 R-ID 列表（保持順序，格式 R1 / R2 …）"""
    text = read(anchor_path)
    section = section_after(text, "用戶原話")
    return [f"R{m.group(1)}" for m in re.finditer(r"^- R(\d+)\b", section, re.MULTILINE)]


def parse_reconcile_rows(text):
    """解析對帳表列 → [(R-ID, 狀態值)]

    狀態值不假定在第 3 欄（各模板欄位順序不同）→ 掃描整列找第一個含狀態標記的欄位。
    """
    rows = []
    for line in text.splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) < 3:
            continue
        m = re.match(r"^(R\d+)$", cells[0])
        if not m:
            continue
        status = ""
        for cell in cells[1:]:
            if any(cell.startswith(prefix) for prefix in ("✅", "⚠", "❌", "🚫")):
                status = cell
                break
        rows.append((m.group(1), status))
    return rows


def sections_with(text, keyword):
    """取出**所有**標題含 keyword 的章節內容（串接）。

    為什麼不是只取第一個：同一份交付摘要可能有多處提到「需求對帳」
    （例如章節標題 + 小節標題），只取第一個會抓到錯的段落。
    """
    lines = text.splitlines()
    out, capturing = [], False
    for line in lines:
        if line.startswith("#"):
            if capturing:
                capturing = False
            if keyword in line:
                capturing = True
            continue
        if capturing:
            out.append(line)
    return "\n".join(out)


def expand_paths(path):
    """把交付摘要裡的路徑簡寫展開成實際候選路徑。

    支援兩種常見簡寫：
      1. `X.md/.html` → 同時指 `X.md` 與 `X.html`
      2. `X-069~071.md` → 展開為 `X-069.md` / `X-070.md` / `X-071.md`（編號區間）
    （V03 對帳第 4 輪：簡寫若不展開，會變成「假紅」或「假綠盲區」）
    """
    candidates = [path]
    if "/." in path:
        base, _, ext = path.rpartition("/.")
        base = base[:-3] if base.endswith(".md") else base
        candidates.append(f"{base}.{ext}")
    if "~" in path:
        m = re.search(r"(\d+)~(\d+)", path)
        if m:
            start, end = int(m.group(1)), int(m.group(2))
            width = len(m.group(1))
            for n in range(start, min(end, start + 20) + 1):
                candidates.append(
                    path[: m.start(1)] + str(n).zfill(width) + path[m.end(2) :]
                )
    return candidates


def deliverable_status(text):
    """取出交付摘要的狀態值。

    欄位名容錯：`**交付狀態**`（dav-submitter 模板）與 `**狀態**`（舊版 handbook 模板）都認，
    避免「檢查器跟它要檢查的模板對不上」→ 門檻形同虛設（V03 對帳第 2 輪 N1）。
    回傳值為完整狀態詞（如「✅ 完成」/「⚠️ 部分完成」/「❌ 未完成」）。
    """
    m = re.search(r"\*\*(?:交付)?狀態\*\*[:：]\s*([✅⚠️❌])\s*([^\n|]*)", text)
    if not m:
        return ""
    return norm_emoji(f"{m.group(1)} {m.group(2).strip()}")


def norm_status(value):
    """把狀態值正規化：取第一個 token、轉小寫（done (2026-10-05) → done）"""
    if not value:
        return ""
    return value.strip().split()[0].strip("`*").lower()


def read(path):
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return ""


def parse_backlog(path):
    """回傳 (rows, columns)

    rows: {id: status}；columns: {'status': idx, 'ac': idx or None}
    以「含 狀態 欄位的表頭」決定欄位索引，兼容不同 backlog 表格格式。
    """
    rows, columns = {}, {"status": None, "ac": None}
    if not path.exists():
        return rows, columns
    for line in read(path).splitlines():
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if "狀態" in cells:
            columns["status"] = cells.index("狀態")
            columns["ac"] = cells.index("AC") if "AC" in cells else None
            continue
        if not cells or not ID_CELL.match(cells[0]):
            continue
        idx = columns["status"]
        if idx is None or idx >= len(cells):
            continue
        # 狀態欄必須看起來像狀態值（排除其他表格裡的同名首欄，如「P2-1 | P2 | 指摘 | …」）
        if not STATUS_VALUE.match(cells[idx]):
            continue
        rows[cells[0]] = cells[idx]
    return rows, columns


def parse_status(text):
    m = STATUS_LINE.search(text)
    return norm_status(m.group(1)) if m else ""


def ac_backlog_id(text, stem):
    m = BACKLOG_REF.search(text)
    return m.group(1) if m else stem


def section_after(text, keyword):
    """取出含 keyword 的標題之後、下一个標題之前的內容"""
    lines = text.splitlines()
    out, capturing = [], False
    for line in lines:
        if line.startswith("#"):
            if capturing:
                break
            if keyword in line:
                capturing = True
            continue
        if capturing:
            out.append(line)
    return "\n".join(out)


class Checker:
    def __init__(self, root, whitelist):
        self.root = Path(root)
        self.whitelist = whitelist
        self.violations = []
        self.exempted = []
        self.checks = 0

    def report(self, kind, key, message):
        entry = f"{kind}#{key}"
        if entry in self.whitelist:
            self.exempted.append((kind, key, self.whitelist[entry]))
            return
        self.violations.append((kind, key, message))

    # --- D1 / D5 / D2 / D6：AC 範本 ---------------------------------------
    def check_ac_files(self, backlog_rows):
        ac_dir = self.root / "docs" / "ac"
        if not ac_dir.is_dir():
            return
        for md in sorted(ac_dir.glob("*.md")):
            if md.name == "README.md":
                continue
            stem = md.stem
            text = read(md)
            bid = ac_backlog_id(text, stem)
            ac_status = parse_status(text)
            self.checks += 1

            # D1：AC 狀態 vs backlog 狀態
            if bid in backlog_rows:
                bl_status = norm_status(backlog_rows[bid])
                if ac_status and bl_status and ac_status != bl_status:
                    self.report(
                        "D1", stem,
                        f"AC 狀態 '{ac_status}' 與 backlog {bid} 狀態 '{bl_status}' 不一致",
                    )
            else:
                self.report("D1", stem, f"backlog 找不到對應 ID '{bid}'（無法比對狀態）")

            # D2：AC 編號連續且唯一
            ids = [int(x) for x in AC_HEADING.findall(text)]
            if ids:
                expected = list(range(1, len(ids) + 1))
                if ids != expected:
                    self.report("D2", stem, f"AC 編號不連續或重複：{ids}（期待 {expected}）")
            elif "## Given / When / Then" not in text:
                # 舊格式（無 ACxx 標題）但有 GWT 段 → 跳過；連 GWT 段都沒有 → 視為被掏空
                self.report("D2", stem, "AC 檔找不到任何 '### ACxx' 標題，也沒有 Given/When/Then 段")

            # D5：md 與 html 狀態一致
            html = md.with_suffix(".html")
            if html.exists():
                html_status = parse_status(read(html))
                if html_status and ac_status and html_status != ac_status:
                    self.report(
                        "D5", stem,
                        f".md 狀態 '{ac_status}' 與 .html 狀態 '{html_status}' 不一致",
                    )

            # D6：AC 範本 ↔ 需求錨點
            anchor = self.root / "docs" / "req" / f"{stem}-requirement.md"
            if not anchor.exists():
                self.report("D6", stem, f"缺需求錨點檔 docs/req/{stem}-requirement.md")

    # --- D3：PRD 追溯矩陣 --------------------------------------------------
    def check_prd(self, backlog_rows):
        prd_dir = self.root / "docs" / "prd"
        if not prd_dir.is_dir():
            return
        for prd in sorted(prd_dir.glob("*.md")):
            text = read(prd)
            matrix = section_after(text, "追溯矩陣")
            if not matrix.strip():
                continue
            self.checks += 1
            # 只看追溯矩陣表的「User Story」欄（其他欄如 FR-01 不是 backlog ID）
            us_idx = None
            for line in matrix.splitlines():
                if not line.startswith("|"):
                    continue
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                if any(c in ("User Story", "US", "US ID", "Backlog ID") for c in cells):
                    us_idx = cells.index(next(c for c in cells if c in ("User Story", "US", "US ID", "Backlog ID")))
                    continue
                if us_idx is None or us_idx >= len(cells):
                    continue
                for token in re.findall(r"[A-Za-z][A-Za-z0-9]*-[A-Za-z0-9-]+", cells[us_idx]):
                    if token not in backlog_rows:
                        self.report("D3", f"{prd.name}:{token}", f"追溯矩陣引用了不存在的 ID '{token}'")

    # --- D7：對帳表（覆蓋率 + 狀態值 + 已交付必對帳）------------------------
    def check_reconcile(self, backlog_rows):
        """對帳表必須覆蓋錨點的全部 R-ID；狀態值必須合法；已交付的 US 必須有對帳表。"""
        rec_dir = self.root / "docs" / "reconcile"
        req_dir = self.root / "docs" / "req"
        if req_dir.is_dir():
            for anchor in sorted(req_dir.glob("*-requirement.md")):
                key = anchor.name[: -len("-requirement.md")]
                ids = anchor_rids(anchor)
                rec = rec_dir / f"{key}-reconcile.md"
                done = norm_status(backlog_rows.get(key, "")) == "done"
                if not rec.exists():
                    if done:
                        self.report("D7", key, "US 已交付但沒有對帳表（docs/reconcile/…）")
                    continue
                self.checks += 1
                text = read(rec)
                rows = parse_reconcile_rows(text)
                if not rows:
                    self.report("D7", key, "對帳表解析不到任何 '| R<n> |' 列")
                    continue
                listed = {rid for rid, _ in rows}
                missing = [r for r in ids if r not in listed]
                if missing:
                    self.report("D7", key, f"對帳表未覆蓋需求句：{', '.join(missing)}")
                for rid, status in rows:
                    if norm_emoji(status) not in {norm_emoji(v) for v in VALID_STATUS}:
                        self.report("D7", key, f"對帳表 {rid} 的狀態值不合法：{status!r}")

    # --- D8：交付摘要的對帳段 ↔ 對帳結果一致 -------------------------------
    def check_deliverable_reconcile(self, from_date=None):
        """交付摘要若對應有需求錨點的 US，必需含「需求對帳」段；且狀態不得與對帳結果矛盾。

        對帳結果以**權威表** `docs/reconcile/<US>-reconcile.md` 為準（PRD ADR-D2），
        交付摘要內嵌表只做交叉比對（內嵌與權威表矛盾 → 違規）。
        """
        deliv_dir = self.root / "docs" / "deliverable"
        req_dir = self.root / "docs" / "req"
        rec_dir = self.root / "docs" / "reconcile"
        if not deliv_dir.is_dir() or not req_dir.is_dir():
            return
        for doc in sorted(deliv_dir.glob("*.md")):
            if from_date and doc.name[:10] < from_date:
                continue
            text = read(doc)
            us_ids = sorted({
                m.group(0) for m in re.finditer(r"\b[A-Z][A-Za-z0-9]*-[A-Za-z0-9-]+\b", text)
                if (req_dir / f"{m.group(0)}-requirement.md").exists()
            })
            if not us_ids:
                continue
            self.checks += 1
            section = sections_with(text, "需求對帳")
            if not section.strip():
                self.report("D8", doc.name, f"對應有需求錨點的 US（{', '.join(us_ids)}）但交付摘要缺「需求對帳」段")
                continue
            embedded_rows = parse_reconcile_rows(section)
            declared = deliverable_status(text)
            # 權威表（多 US 合併）：以 (R-ID, 狀態) 多重集比對
            #   為何不用 dict：不同 US 都可能從 R1 起算 → 以 R-ID 為全域鍵會互相覆蓋、誤判矛盾
            auth_pairs = []
            gaps = []
            for us in us_ids:
                rec = rec_dir / f"{us}-reconcile.md"
                if not rec.exists():
                    gaps.append(f"{us}: 缺權威對帳表")
                    continue
                for rid, status in parse_reconcile_rows(read(rec)):
                    norm = norm_emoji(status)
                    auth_pairs.append((rid, norm))
                    if norm in {norm_emoji(v) for v in GAP_STATUS}:
                        gaps.append(f"{us} {rid}={status}")
            emb_pairs = [(rid, norm_emoji(st)) for rid, st in embedded_rows]
            if sorted(emb_pairs) != sorted(auth_pairs):
                self.report(
                    "D8", doc.name,
                    "交付摘要的「需求對帳」段與權威對帳表不一致"
                    f"（摘要 {sorted(emb_pairs)} vs 權威 {sorted(auth_pairs)}）",
                )
            if gaps and declared.startswith("✅"):
                self.report("D8", doc.name, f"對帳有未對上的項目（{', '.join(gaps)}）但交付狀態標為「✅ 完成」")
            if "對帳降級" in text and declared.startswith("✅"):
                self.report("D8", doc.name, "標註「對帳降級」但交付狀態仍標「✅ 完成」（降級不得宣告通過）")

    # --- D4：交付摘要提到的檔案 -------------------------------------------
    def check_deliverables(self, from_date=None):
        """只檢查日期 >= from_date 的交付摘要。

        理由：歷史交付摘要引用的檔案可能已在後續被刪除 / 改名，回溯檢查會產生大量假紅；
        機制生效日之後的交付才受檢查（當下寫的宣稱必須成立）。
        """
        deliv_dir = self.root / "docs" / "deliverable"
        if not deliv_dir.is_dir():
            return
        for doc in sorted(deliv_dir.glob("*.md")):
            if from_date and doc.name[:10] < from_date:
                continue
            text = read(doc)
            self.checks += 1
            for path in sorted(set(PATH_LIKE.findall(text))):
                if not path.startswith(KNOWN_PREFIXES):
                    continue
                if any(ph in path for ph in PLACEHOLDER):
                    continue
                for candidate in expand_paths(path):
                    if (self.root / candidate).exists():
                        break
                else:
                    self.report("D4", f"{doc.name}:{path}", f"交付摘要提到的檔案不存在：{path}")


def load_whitelist(path):
    """回傳 {kind#key: reason}；格式不合法 → 印錯並以 rc=2 結束"""
    if not path:
        return {}, None
    p = Path(path)
    if not p.exists():
        return {}, None
    entries, errors = {}, []
    for lineno, raw in enumerate(read(p).splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split("#")
        if len(parts) != 3:
            errors.append(f"{p}:{lineno} 格式錯誤（需為 <類>#<鍵>#<理由>）：{line}")
            continue
        kind, key, reason = (x.strip() for x in parts)
        if not kind or not key:
            errors.append(f"{p}:{lineno} 缺類別或鍵：{line}")
            continue
        if key == "*":
            errors.append(f"{p}:{lineno} 不允許全類豁免（{kind}#*）：{line}")
            continue
        if not reason:
            errors.append(f"{p}:{lineno} 缺理由（fail-closed）：{line}")
            continue
        entries[f"{kind}#{key}"] = reason
    if errors:
        for e in errors:
            print(f"白名單錯誤：{e}", file=sys.stderr)
        return {}, "invalid"
    return entries, None


def main():
    ap = argparse.ArgumentParser(description="文件漂移檢查（D1..D6）")
    ap.add_argument("--root", default=".", help="目標專案根目錄（預設：目前目錄）")
    ap.add_argument("--whitelist", default=None, help="白名單檔（預設：<root>/docs/ci/drift-whitelist.txt）")
    ap.add_argument(
        "--from-date",
        default=DEFAULT_FROM_DATE,
        help=f"D4 只檢查日期 >= 此值的交付摘要（預設 {DEFAULT_FROM_DATE}，即機制生效日）",
    )
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"用法錯誤：{root} 不是目錄", file=sys.stderr)
        return 2
    # --from-date 只接受 YYYY-MM-DD。
    # 為什麼必須驗：比對用的是**字串**比較（doc.name[:10] < from_date）。
    # 若允許任意字串，傳入非日期值（例如 "bad-date"）會讓所有交付摘要都被跳過
    #   → 檢查範圍靜默縮成空集 → D8 硬門檻被一個 typo 關掉 → **假綠**。
    # 這裡 fail-closed：格式不合法 → rc=2（用法錯誤），不靜默放行。
    # 同時用 strptime 擋掉「格式對但日期不存在」的輸入（例如 2026-13-45、2026-02-30）——
    #   那些字串仍能通過 regex，卻會讓字串比較的範圍算錯，同樣是靜默漏檢。
    try:
        datetime.strptime(args.from_date, "%Y-%m-%d")
    except ValueError:
        print(
            f"用法錯誤：--from-date 必須是合法的 YYYY-MM-DD 日期，收到 {args.from_date!r}",
            file=sys.stderr,
        )
        return 2
    backlog = root / "docs" / "backlog.md"
    if not backlog.exists():
        print(f"用法錯誤：{root} 下找不到 docs/backlog.md（此檢查不適用於該專案）", file=sys.stderr)
        return 2

    wl_path = args.whitelist or str(root / "docs" / "ci" / "drift-whitelist.txt")
    whitelist, err = load_whitelist(wl_path)
    if err:
        return 2

    checker = Checker(root, whitelist)
    backlog_rows, _ = parse_backlog(backlog)
    checker.check_ac_files(backlog_rows)
    checker.check_prd(backlog_rows)
    checker.check_reconcile(backlog_rows)
    checker.check_deliverable_reconcile(from_date=args.from_date)
    checker.check_deliverables(from_date=args.from_date)

    for kind, key, reason in checker.exempted:
        print(f"WHITELIST {kind} {key}: {reason}")
    for kind, key, message in checker.violations:
        print(f"DRIFT {kind} {key}: {message}")
    if checker.violations:
        print(
            f"FAIL: {len(checker.violations)} 項漂移，{len(checker.exempted)} 項豁免",
            file=sys.stderr,
        )
        return 1
    print(f"OK: {checker.checks} 項檢查完成，{len(checker.exempted)} 項豁免")
    return 0


if __name__ == "__main__":
    sys.exit(main())
