# Bundled single-file HTML variant

> **When to use this instead of the per-doc `_html/<name>.html` output.**
> The default `build.sh` produces one HTML per source MD plus a boss
> variant (N×2 files for N docs). The bundled variant produces **one
> single self-contained HTML file** containing the entire project docs
> with in-browser sidebar navigation and search. Choose it when:
>
> - You need to **email / share / archive** the docs as one file
> - You want a **portable artifact** that opens with `file://` on any
>   machine without a local server
> - You want **cross-doc navigation and search** built in
> - The project's doc set is small enough (~20 docs, <1 MB total) to
>   inline into one file
>
> For large doc sets, or when reviewers want to diff individual files,
> stick with the per-doc variant.

## Architecture

1. A **build script** (`scripts/build_bundled_html.cjs`) reads every
   `docs/*.md` in the project + the repo-root `README.md` and produces
   one output file `<project>/docs/<project>-docs.html`.

2. The output is **fully self-contained**:
   - All CSS is inlined into a single `<style>` block
   - All JS is inlined into a single `<script>` block
   - Each source MD is embedded as a `<script type="text/markdown" id="doc-XXX" data-title="..." data-file="...">`
     block; the script `textContent` is the raw markdown
   - A small **in-browser markdown parser** (~500 lines, no deps)
     renders the active doc on demand

3. The HTML uses **hash-based routing** (`#database` → load doc-database)
   so URLs are shareable.

4. The bundled file lives at `docs/<project>-docs.html`. It is
   **`.gitignore`'d** alongside the per-doc output.

## Why inline `<script type="text/markdown">` instead of `fetch()`?

`fetch('foo.md')` from a `file://` page is blocked by Chrome / Edge
("CORS request not http"), silently returns an error in Safari for
some file types, and only works in Firefox by default. Embedding the
markdown inline eliminates the issue entirely. The browser happily
exposes `textContent` of any script block, so parsing is trivial.

## Build script shape

```js
// scripts/build_bundled_html.cjs
const fs = require('fs');
const path = require('path');

const project = process.argv[2];              // e.g. "crm-system"
const projectDir = path.join(process.env.HOME, 'www', project);
const docsDir = path.join(projectDir, 'docs');
const rootReadme = path.join(projectDir, 'README.md');
const outPath = path.join(docsDir, `${project}-docs.html`);

const docFiles = [
  { id: 'root',         title: 'README',         file: rootReadme },
  { id: 'progress',     title: 'PROGRESS',       file: path.join(docsDir, 'PROGRESS.md') },
  { id: 'docs-index',   title: 'Doc index',      file: path.join(docsDir, 'README.md') },
  // ... one entry per file
];

let tpl = fs.readFileSync(path.join(__dirname, 'bundled-template.html'), 'utf8');
const embedded = docFiles.map(({ id, file, title }) => {
  const raw = fs.readFileSync(file, 'utf8');
  // Escape any closing </script> in the markdown content so it
  // doesn't terminate our embedding script block prematurely.
  const safe = raw.replace(/<\/script>/gi, '<\\/script>');
  return `  <script type="text/markdown" id="doc-${id}" data-title="${title}">\n${safe}\n  </script>`;
}).join('\n');

const final = tpl.replace('<SCRIPTS_PLACEHOLDER />', embedded);
fs.writeFileSync(outPath, final);
console.log(`✓ Built ${outPath} (${(fs.statSync(outPath).size / 1024).toFixed(1)} KB)`);
```

## Gotchas (read this before running)

### 1. Use `.cjs` extension if `package.json` has `"type": "module"`

If the **repo root** has `"type": "module"` in its `package.json`
(common in modern Bun / Vite projects), a script with `const fs = require('fs')`
will fail with `ReferenceError: require is not defined in ES module scope`.

**Fix:** name the file `build_bundled_html.cjs` (not `.js`) so Node
treats it as CommonJS. Do NOT change the project to "type": "commonjs"
— that breaks everything else.

```bash
# Symptom
$ node build_bundled_html.js
ReferenceError: require is not defined in ES module scope
# Fix
$ mv build_bundled_html.js build_bundled_html.cjs
$ node build_bundled_html.cjs
```

### 2. Escape `</script>` inside embedded markdown

Markdown that contains literal HTML (e.g. code samples showing HTML)
might contain `</script>`. The browser HTML parser sees the first
`</script>` and terminates the script block — your remaining
markdown content becomes unparsed body text.

**Always** do this when embedding:

```js
const safe = raw.replace(/<\/script>/gi, '<\\/script>');
//                              ^^^^  one extra backslash
```

Then in the browser, the parser sees `<\/script>` which it treats
as a string (because of the backslash), and the actual `</script>`
text inside the markdown content is preserved verbatim in the
rendered output.

**ALSO escape `app.js` and `styles.css`** before inlining (not just
markdown). `app.js` is the rendered JS engine and gets inlined
verbatim. While your `app.js` likely doesn't contain a literal
`</script>` today, future edits to it might, and a single accidental
literal will silently break the entire viewer.

```js
let appTpl = fs.readFileSync(path.join(here, 'app.js'),     'utf8').replace(/<\/script>/gi, '<\\/script>');
let cssTpl = fs.readFileSync(path.join(here, 'styles.css'), 'utf8').replace(/<\/script>/gi, '<\\/script>');
```

### 2a. Self-test the inlined JS with `node --check` (2026-06-06 — required)

Even after escaping `</script>`, a separate class of bug can ship:
**the inlined JS itself is syntactically invalid** because a
markdown code sample contains a string that, once concatenated into
the build output, breaks the parser.

Symptom seen in crm-system 2026-06-06:

```
Uncaught SyntaxError: Invalid or unexpected token
  at index.html.bundled.html:4898:72
```

The whole viewer breaks — sidebar loads but content pane stays
"載入中..." because the script tag terminates mid-way through the
markdown content.

**Always** add this to your build script after `fs.writeFileSync(outPath, ...)`:

```js
// Self-test: extract the inlined <script>...</script> JS, run `node --check`
const inlinedScriptMatch = finalHtml.match(/<script>\s*\n([\s\S]*?)\n\s*<\/script>/);
if (inlinedScriptMatch) {
  const tmpScript = '/tmp/inlined-app-test.js';
  fs.writeFileSync(tmpScript, inlinedScriptMatch[1]);
  try {
    require('child_process').execFileSync('node', ['--check', tmpScript], { stdio: 'pipe' });
    console.log('  ✓ inlined JS passed node --check');
  } catch (e) {
    console.error('  ✗ inlined JS failed syntax check:');
    console.error(e.stderr?.toString() || e.message);
    process.exit(1);   // FAIL THE BUILD, don't ship broken HTML
  } finally {
    fs.unlinkSync(tmpScript);
  }
}
```

**What `node --check` catches that "eyeball the file" misses:**

| Pattern in MD | What breaks in the inlined JS |
|---|---|
| Markdown content with a JS code sample whose source string contains a literal `</script>` substring | Outer `<script>` tag terminates early, viewer dies |
| Code sample showing `'$&'` regex replacement string | Backslash-n in MD source becomes real newline in the inlined JS string |
| Template-literal code sample with `\${...}` | Backslash-dollar interpolates incorrectly when inlined |

**If `node --check` fails after your build:** open the inlined JS
at the line it reports, work backwards to the MD file that
contributed that string, and look for a literal `</script>`
substring or other JS-breaking sequence. Either escape it (in the
build script) or move the offending code sample out of the bundled
viewer's MD sources (into a separate, gitignored file or a
code-hosting link).

### 3. The regex extraction footgun (re.DOTALL)

When verifying the bundle by extracting the markdown out of the HTML
with a regex, **`<script type="text/markdown">(.+?)</script>` with
`re.DOTALL` will over-match** if the following block is a regular
`<script>` (your `app.js`):

```python
# BAD: matches from the first markdown script through the </script> of app.js
docs = re.findall(r'<script type="text/markdown" id="([^"]+)"[^>]*>(.*?)</script>', html, re.DOTALL)
# → bogus "doc-XXX" entry containing all of app.js
```

**Fix:** verify by counting unique IDs, or check the file size only.
The browser's own HTML parser handles this correctly because it
matches by **element type, not by tag name only** — `<script type="text/markdown">`
is a different element from `<script>`, and the parser correctly
respects that boundary.

### 4. Strip the leading H1 (or not)

If your sidebar already shows the doc title, the leading `# Title`
in each MD will be rendered as a duplicate H1 in the content area.
Two options:

- **Strip it at build time** in the script:
  ```js
  if (id !== 'root') content = raw.replace(/^# [^\n]*\n+/, '');
  ```
  Keep it for the root README (it's the entry point) but strip for
  the rest.

- **Or:** leave the duplicate and style the content H1 differently
  from sidebar text (the GitHub-like approach).

### 5. In-browser parser: keep it small, test it

Don't pull in `marked` or `markdown-it` (~100KB minified) when you
only need GFM basics. A 500-line state machine covers:
- ATX headings, fenced code, lists (ul/ol + task-list), tables, blockquotes
- Inline code, bold, italic, links, images
- HTML pass-through (don't sanitise unless you trust the source)

**The MD source is yours** (it's the project's own docs/), so XSS is
not a concern. If you ever render untrusted MD in the same viewer,
add a sanitiser.

### 6. Hash routing for shareable URLs

The viewer's `loadDoc(id)` should `history.replaceState(null, '', '#' + id)`
and listen for `hashchange`. This way, `https://.../docs.html#database`
is shareable and refresh-safe.

### 7. Use a real `<script>` placeholder instead of `<SCRIPTS_PLACEHOLDER />` (2026-06-06)

The recipe above uses `<SCRIPTS_PLACEHOLDER />` as the slot to inject
embedded MD blocks. That works, but a **more robust pattern** is to
ship a real placeholder `<script>` tag in the template:

```html
<!-- template index.html -->
<script type="text/markdown" id="doc-XXX"></script>
<script src="app.js"></script>
```

The build script then does a string replace on the placeholder's `id`:

```js
const final = template.replace(
  '<script type="text/markdown" id="doc-XXX"></script>',
  embedded  // concatenated real doc blocks
);
```

**Why this is better** than the `<SCRIPTS_PLACEHOLDER />` approach:
- The placeholder survives a browser test load (renders as an empty
  script block instead of literal text in the body).
- The `app.js` can `document.getElementById('doc-XXX')` against the
  placeholder and skip it at runtime (treats it as "not yet replaced").
- If you skip the build step, the template still works as a development
  shell — the dev server can serve real `.md` files via fetch and
  `app.js` populates them at runtime.

**Heads-up:** if you use the recipe's `<SCRIPTS_PLACEHOLDER />`
pattern, the placeholder is **literal text in the output HTML** until
the build script runs. If you accidentally run the build twice, the
second pass finds no placeholder to replace (it was already consumed
in pass one) and the output looks fine — but you have a useless
`<SCRIPTS_PLACEHOLDER />` somewhere in the body if the template was
modified. The `<script type="text/markdown">` placeholder is more
self-healing.

### 8. Naming the output file — `<project>-docs.html` vs `index.html.bundled.html`

Default is `<project>-docs.html` (e.g. `crm-system-docs.html`).
This file goes in `docs/` and is **gitignored** along with the per-doc
output.

**Exception (2026-06-06 crm-system):** David sometimes explicitly
asks for the bundled file to be **committed** (e.g. for a stable URL
the team can share via Discord without David having to rebuild). In
that case:
- Name it `index.html.bundled.html` so it doesn't conflict with
  Vite/React's `index.html`
- Commit it with a clear message ("docs: pre-built bundled HTML for sharing")
- Re-run the build script on every docs change (or wire up a
  `docs:build` script in `package.json`)
- Document the rebuild step in `CONTRIBUTING.md` so contributors
  don't break the bundled file

This is a **deviation from the default** — make sure David confirms
this is the intent. The default is gitignore.

## Verification (no browser required)

You can verify a bundled build structurally without a browser:

```python
# Verify all docs are embedded
import re
with open("docs.html") as f: html = f.read()
tags = re.findall(r'<script type="text/markdown" id="([^"]+)"', html)
print(f"Embedded docs: {len(tags)}")
for t in tags: print(f"  - {t}")
# Sanity: ends with </html>, has inline <style>, inlined <script>
assert html.rstrip().endswith('</html>')
assert '<style>' in html
assert 'text/markdown' in html
```

For visual verification, open the file in any browser (`open docs.html`).
The browser will show: dark top bar with project name, left sidebar
with grouped links, main content area, search box, theme toggle.

**Hermes-environment limitation:** if you're running inside Hermes and
the `browser_navigate` tool blocks `file://` URLs, you won't be able
to E2E-verify the bundled file. Fall back to:
1. Structural verification (Python above) — confirms no broken
   structure or missing MD content
2. Screenshot of the open browser via `screencapture` if macOS — may
   be denied by the sandbox; if so, the structural check is sufficient
3. Open the file in your own browser (David) and visually confirm

## Files this skill adds

| Path | Purpose |
|------|---------|
| `scripts/build_bundled_html.cjs` | The Node build script |
| `references/bundled-html-recipe.md` | This file (gotchas + recipe) |

The HTML template (the shell with sidebar, search, theme toggle,
markdown parser) is a small self-contained artifact (~17 KB) — inline
it inside the `.cjs` build script as a string literal so the user
only needs the single script file to build.

## User-style preferences (David, 2026-06-06)

- **Self-contained preferred.** David dislikes external assets (no
  CDN, no web fonts, no image files served from elsewhere). All CSS
  and JS inlined; theme toggle uses emoji `🌙/☀️`, not icon font.
- **Dark mode mandatory.** Top bar is always dark; content area is
  light by default with a toggle for dark.
- **繁體中文香港口語** for the topbar chrome (e.g. "搜尋文件...",
  "切換主題", "載入中..."). MD content language is the user's choice.
- **Search shortcut** `/` focuses the search box; `Esc` clears.
  Mention this in the search placeholder.
- **`<kbd>/</kbd>` visual hint** in the sidebar near the search
  filter explanation ("Tip: <kbd>/</kbd> focuses the search box").
