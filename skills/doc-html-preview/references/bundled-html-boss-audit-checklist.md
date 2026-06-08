# Boss-facing audit checklist for the bundled HTML doc viewer

> **When to run this**: after building `docs/<project>-docs.html` (or
> `docs/index.html.bundled.html`) and before showing it to the boss /
> client / investor. The build script (`build_bundled_html.cjs`) only
> handles structural correctness — it does NOT verify the artifact is
> boss-appropriate. The boss cares about *first impression + easy
> navigation + printability*, not schema correctness.
>
> If David says anything like "你 check 一 check 設定" / "HTML doc 是
> 有了新要求" / "for 老闆" without specifying what, run this audit
> proactively and fix what you find — don't ask David to enumerate
> requirements.

## 9-point boss-audit checklist (verified crm-system 2026-06-06)

| # | Check | Why it matters | Fix |
|---|-------|----------------|-----|
| 1 | **Default landing is the boss doc, not the dev README** | First impression — if the boss opens and sees schema tables, they assume the whole doc is engineering-grade and skip it. | In `app.js` boot, set `PREFERRED_LANDING = 'prd'` (or whichever is the boss-facing doc). Only fall back to `root` if no boss doc exists. |
| 2 | **`<title>` is in 繁中, not English** | Browser tab shows the title; if it's "CRM System — Documentation" the boss doesn't know if the tab is for them. | Change `<title>` to "CRM 系統 — 項目文檔" (or whatever matches the brand). |
| 3 | **Subtitle shows a meaningful version label, not "Day N snapshot"** | "Day 9 snapshot" is dev jargon. The boss wants to know "is this current?" | Change to "最新版本: Day N · YYYY-MM-DD" (or release tag + date). |
| 4 | **Skip-to-content link present (a11y)** | Keyboard-only users (often bosses on iPad) need to jump past the nav. Without it, Tab is painful. | Add `<a href="#doc" class="skip-link">跳到內容</a>` at the top of `<body>`, style with `position: absolute; top: -40px;` and `top: 8px` on `:focus`. |
| 5 | **Print / Export-PDF button** | The boss often wants a PDF version for board meetings. Without a button, they have to discover the browser's print menu. | Add `<button id="print-btn" aria-label="列印 / 匯出 PDF">🖨</button>` and a 5-line `initPrintButton()` that calls `window.print()`. The existing `@media print` CSS handles the rest. |
| 6 | **Footer explains "how to use this"** | The recipient might not know what to do with a `.html` file. They might email back asking "how do I open this?" | Add `<footer class="doc-footer">` with one sentence + kbd hints for 🖨 and 🌙. CSS-hide in `@media print`. |
| 7 | **Print CSS hides chrome (topbar, sidebar, footer)** | Without this, the printed PDF has the navbar visible on every page. | Add `.topbar, .sidebar, .doc-footer { display: none; }` inside `@media print`. Bonus: append `url(href)` to external links via `::after` so the PDF is self-contained. |
| 8 | **Sidebar has `aria-label="文件目錄"`** | Screen readers need to know the nav is nav, not body content. | Add `aria-label` to `<aside>`. |
| 9 | **`<main>` has `tabindex="-1"`** | The skip-link target needs to be focusable for the focus ring + screen-reader announcement. | Add `tabindex="-1"` to `<main class="content">`. |

## How to apply this

1. Build the bundled HTML (`node scripts/build_bundled_html.cjs`).
2. Run the 9-point audit.
3. Edit the source files (`index.html`, `app.js`, `styles.css`).
4. Re-run the build script.
5. Open the output and visually confirm.

## Why the user might say "check your settings" without specifying

Common phrases from David that should trigger this audit (not literal
search — semantic):

- "你 check 一 check 你嘅設定"
- "HTML doc 是有了新要求"
- "for the boss" / "畀老闆睇" / "客戶版本"
- "睇起嚟唔 professional"
- "我 send 咗畀老闆佢冇反應" (silent signal — too technical / too much jargon)

When David uses these phrases, **default to running the audit
yourself** — don't ask "what new requirements?" because David
himself may not have enumerated them; he just senses the artifact
isn't boss-ready.

## Test of the audit (concrete)

After applying all 9 fixes on crm-system's `index.html.bundled.html`:

```
✓ <title>CRM 系統 — 項目文檔</title>
✓ Skip link (a11y)
✓ Print button
✓ Footer hint
✓ Default PRD landing
✓ initPrintButton()
✓ print CSS hides footer
✓ doc footer kbd hint
✓ Sidebar aria-label
```

The artifact then opens at the PRD (boss's first stop), shows a 🖨
button to export PDF, has a footer that says "double-click 個 file
就開到, 無需安裝", and prints cleanly without the navbar.

## Anti-patterns to avoid

- ❌ **Asking the user to enumerate requirements** when the request is
  ambiguous. Run the audit, find issues, fix them, report what you
  changed.
- ❌ **Auditing only structural correctness** (broken links, syntax
  errors). The build script does that — your job is to verify the
  artifact serves its *audience*.
- ❌ **Skipping the print stylesheet** because the boss hasn't
  asked for PDF yet. They will. The 5-line `@media print` block
  takes 30 seconds to add and saves an embarrassing "can you make
  this printable?" follow-up.
- ❌ **Default landing = dev README** because the README is the
  "first" doc alphabetically. The audience-aware default is the
  boss doc.
