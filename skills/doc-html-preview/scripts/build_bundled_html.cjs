#!/usr/bin/env node
// build_bundled_html.cjs — Build a single self-contained HTML file
// containing every markdown doc in the project, with in-browser
// sidebar navigation and search.
//
// Usage:
//   node build_bundled_html.cjs <project-name> [extra-md-path ...]
//
// Output:
//   ~/www/<project>/docs/<project>-docs.html
//
// The output is gitignored by default (.gitignore snippet in this skill).
//
// IMPORTANT: this is CommonJS (.cjs) because modern Bun/Vite project
// roots have "type": "module" in package.json. Do not rename to .js.
//
// Recipe + gotchas: see references/bundled-html-recipe.md

const fs = require('fs');
const path = require('path');
const os = require('os');

const project = process.argv[2];
if (!project) {
  console.error('Usage: node build_bundled_html.cjs <project-name> [extra-md-paths...]');
  process.exit(1);
}

const projectDir = path.join(os.homedir(), 'www', project);
const docsDir = path.join(projectDir, 'docs');
const rootReadme = path.join(projectDir, 'README.md');
const outPath = path.join(docsDir, `${project}-docs.html`);

if (!fs.existsSync(docsDir)) {
  console.error(`ERROR: docs dir not found: ${docsDir}`);
  process.exit(1);
}

// Collect source MDs. The root README is included as the entry point.
// docs/README.md (the doc index) is included separately as 'docs-index'.
const docFiles = [
  { id: 'root',         title: 'README',         file: rootReadme },
];

if (fs.existsSync(docsDir)) {
  for (const f of fs.readdirSync(docsDir).sort()) {
    if (!f.endsWith('.md')) continue;
    if (f === 'README.md') {
      docFiles.push({ id: 'docs-index', title: 'Doc index', file: path.join(docsDir, f) });
      continue;
    }
    const id = f.replace(/\.md$/, '').toLowerCase().replace(/[^a-z0-9-]/g, '-');
    const title = f.replace(/\.md$/, '').replace(/[-_]/g, ' ');
    docFiles.push({ id, title, file: path.join(docsDir, f) });
  }
}

// Allow extra MD paths passed as args
for (const arg of process.argv.slice(3)) {
  if (fs.existsSync(arg)) {
    const f = path.basename(arg);
    const id = f.replace(/\.md$/, '').toLowerCase().replace(/[^a-z0-9-]/g, '-');
    const title = f.replace(/\.md$/, '').replace(/[-_]/g, ' ');
    docFiles.push({ id, title, file: arg });
  }
}

// ---------- HTML template (inline; ~17 KB) ----------
const TEMPLATE = `<!DOCTYPE html>
<html lang="zh-HK">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>__PROJECT__ — Documentation</title>
  <style>
:root{--bg:#fff;--bg-soft:#f6f8fa;--bg-code:#f6f8fa;--border:#d0d7de;--text:#1f2328;--text-soft:#57606a;--text-link:#0969da;--text-link-hover:#0550ae;--accent:#0969da;--accent-bg:#ddf4ff;--shadow:0 1px 0 rgba(31,35,40,.04);--table-stripe:#f6f8fa;--blockquote:#57606a;--topbar-bg:#24292f;--topbar-text:#fff;--topbar-text-soft:#d0d7de;--kbd-bg:#f6f8fa}
[data-theme=dark]{--bg:#0d1117;--bg-soft:#161b22;--bg-code:#161b22;--border:#30363d;--text:#e6edf3;--text-soft:#8b949e;--text-link:#58a6ff;--text-link-hover:#79c0ff;--accent:#58a6ff;--accent-bg:#1f6feb33;--shadow:0 0 transparent;--table-stripe:#161b22;--blockquote:#8b949e;--topbar-bg:#010409;--topbar-text:#e6edf3;--topbar-text-soft:#8b949e;--kbd-bg:#21262d}
*{box-sizing:border-box}html,body{margin:0;padding:0;background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","PingFang TC","Microsoft JhengHei","Noto Sans CJK HK","Helvetica Neue",Arial,sans-serif;font-size:15px;line-height:1.6;-webkit-font-smoothing:antialiased;-moz-osx-font-smoothing:grayscale}
a{color:var(--text-link);text-decoration:none}a:hover{color:var(--text-link-hover);text-decoration:underline}
code,kbd,pre,samp{font-family:ui-monospace,SFMono-Regular,"SF Mono",Menlo,Consolas,"Liberation Mono",monospace}
pre{background:var(--bg-code);border:1px solid var(--border);border-radius:6px;padding:12px;overflow:auto;font-size:13.5px}code{background:var(--bg-code);padding:1px 6px;border-radius:4px;font-size:90%}pre code{background:transparent;padding:0;font-size:inherit}
table{border-collapse:collapse;width:100%;margin:1em 0}th,td{border:1px solid var(--border);padding:6px 12px;text-align:left}th{background:var(--bg-soft);font-weight:600}tr:nth-child(2n){background:var(--table-stripe)}
blockquote{border-left:4px solid var(--border);color:var(--blockquote);padding:0 1em;margin:1em 0}
img{max-width:100%;height:auto;border-radius:4px}
h1,h2,h3,h4,h5,h6{font-weight:600;line-height:1.25;margin:1.5em 0 .5em}h1{font-size:2em;border-bottom:1px solid var(--border);padding-bottom:.3em}h2{font-size:1.5em;border-bottom:1px solid var(--border);padding-bottom:.3em}h3{font-size:1.25em}h4{font-size:1em}
hr{border:0;border-top:1px solid var(--border);margin:1.5em 0}
kbd{background:var(--kbd-bg);border:1px solid var(--border);border-bottom-width:2px;border-radius:4px;padding:1px 5px;font-size:90%}
mark{background:#fff3a3;color:inherit;padding:0 2px;border-radius:2px}
.topbar{position:sticky;top:0;z-index:100;background:var(--topbar-bg);color:var(--topbar-text);padding:10px 16px;display:flex;align-items:center;gap:12px;box-shadow:var(--shadow)}
.topbar h1{font-size:16px;margin:0;border:none;padding:0;color:var(--topbar-text)}
.topbar .sub{font-size:12px;color:var(--topbar-text-soft);margin-left:8px}
.topbar .spacer{flex:1}
.topbar input{padding:4px 10px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text);font-size:13px;width:240px}
.topbar button{background:transparent;border:1px solid var(--topbar-text-soft);color:var(--topbar-text);padding:3px 8px;border-radius:6px;cursor:pointer;font-size:13px}
.topbar button:hover{background:var(--topbar-text-soft);color:var(--topbar-bg)}
.layout{display:flex;min-height:calc(100vh - 50px)}
.sidebar{width:240px;background:var(--bg-soft);border-right:1px solid var(--border);padding:16px 0;overflow-y:auto;flex-shrink:0}
.sidebar .nav-group{margin-bottom:16px}
.sidebar .nav-group-title{font-size:11px;text-transform:uppercase;letter-spacing:.5px;color:var(--text-soft);padding:0 16px;margin-bottom:4px;font-weight:600}
.sidebar ul{list-style:none;padding:0;margin:0}
.sidebar li a{display:block;padding:4px 16px;color:var(--text);font-size:13.5px;border-left:2px solid transparent}
.sidebar li a:hover{background:var(--accent-bg);text-decoration:none}
.sidebar li a.active{background:var(--accent-bg);border-left-color:var(--accent);color:var(--accent);font-weight:600}
.content{flex:1;padding:32px 48px;max-width:none;min-width:0}
.content h1:first-child{margin-top:0}
.doc-footer{border-top:1px solid var(--border);padding:16px 48px;color:var(--text-soft);font-size:12px;background:var(--bg-soft)}
.doc-footer kbd{font-size:11px}
.skip-link{position:absolute;top:-40px;left:0;background:var(--accent);color:#fff;padding:8px 12px;z-index:1000;text-decoration:none;border-radius:0 0 4px 0}
.skip-link:focus{top:0}
@media print{.topbar,.sidebar,.doc-footer{display:none !important}.content{padding:0;max-width:100%}a{color:inherit;text-decoration:none}a[href^="http"]::after{content:" (" attr(href) ")"}}
@media (max-width:768px){.sidebar{position:fixed;left:-240px;top:50px;height:calc(100vh - 50px);z-index:99;transition:left .2s}.sidebar.open{left:0}.content{padding:16px}}
</style>
</head>
<body>
<a href="#doc" class="skip-link">跳到內容</a>
<div class="topbar">
  <h1>__PROJECT__ — Documentation</h1>
  <span class="sub" id="subtitle"></span>
  <span class="spacer"></span>
  <input id="search" type="search" placeholder="搜尋文件... (按 / 聚焦)" />
  <button id="theme-toggle" title="切換主題">🌙</button>
  <button id="print-btn" title="列印 / 匯出 PDF">🖨</button>
</div>
<div class="layout">
  <aside class="sidebar" id="nav" aria-label="文件目錄"></aside>
  <main class="content" id="doc" tabindex="-1"></main>
</div>
<footer class="doc-footer">
  雙按 <kbd>🖨</kbd> 列印或匯出 PDF · <kbd>🌙</kbd> 切換深色模式 · <kbd>/</kbd> 聚焦搜尋框
  <br />本文件由 <code>doc-html-preview</code> skill 自動產生 · 來源 MD 係 single source of truth
</footer>
<script type="text/markdown" id="doc-XXX"></script>
<script>
(function(){
'use strict';
var escapeHtml=function(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;')};
function renderInline(text){
text=text.replace(/\\`([^\\`]+)\\`/g,function(_,c){return '<code>'+c+'</code>'});
// FIX 2026-06-09: use new RegExp(...) constructor to avoid Node 22 V8 strict
// parser rejecting unescaped ')' inside character class. The literal form
// /[^)\s]+/ fails node --check on Node 22+, so we build the regex from a
// string. See references/node-22-regex-bug.md for full reproducer.
text=text.replace(new RegExp('!\\\\[([^\\\\]]*)\\\\]\\\\(\\\\s*([^\\\\s)]+)(?:\\\\s+"([^"]*)")?\\\\s*\\\\)','g'),function(_,alt,url,title){return '<img src="'+url+'" alt="'+alt+'"'+(title?' title="'+title+'"':'')+' loading="lazy" />'});
text=text.replace(new RegExp('\\\\[([^\\\\]]+)\\\\]\\\\(\\\\s*([^\\\\s)]+)\\\\s*\\\\)','g'),function(_,l,u){var e=/^https?:\\/\\//.test(u);return '<a href="'+u+'"'+(e?' target="_blank" rel="noopener"':'')+'>'+l+'</a>'});
text=text.replace(/\\*\\*([^*]+)\\*\\*/g,'<strong>$1</strong>');
text=text.replace(/__([^_]+)__/g,'<strong>$1</strong>');
text=text.replace(/(^|[^*])\\*([^*\\n]+)\\*(?!\\*)/g,'$1<em>$2</em>');
text=text.replace(/(^|[^_])_([^_\\n]+)_(?!_)/g,'$1<em>$2</em>');
return text}
function renderBlock(md){
var lines=md.split('\\n');
var out=[];
var inCode=false,codeLang='',codeBuf=[];
var inList=null,listType=null,listItems=[];
var inTable=false,tableHeader=[],tableRows=[];
var inBlockquote=false,blockquoteBuf=[];
var paraBuf=[];
function flushPara(){if(paraBuf.length){out.push('<p>'+renderInline(paraBuf.join(' '))+'</p>');paraBuf=[]}}
function closeLists(){if(inList){if(listType==='ul'){out.push('<ul>'+listItems.map(function(it){return '<li>'+renderInline(it)}).join('')+'</ul>')}else{out.push('<ol>'+listItems.map(function(it){return '<li>'+renderInline(it)}).join('')+'</ol>')};inList=null;listType=null;listItems=[]}}
function flushTable(){if(inTable){var h='<thead><tr>'+tableHeader.map(function(c){return '<th>'+renderInline(c)}).join('')+'</tr></thead>';var b='<tbody>'+tableRows.map(function(r){return '<tr>'+r.map(function(c){return '<td>'+renderInline(c)}).join('')+'</tr>'}).join('')+'</tbody>';out.push('<table>'+h+b+'</table>');inTable=false;tableHeader=[];tableRows=[]}}
function flushBlockquote(){if(inBlockquote){out.push('<blockquote>'+renderInline(blockquoteBuf.join(' '))+'</blockquote>');inBlockquote=false;blockquoteBuf=[]}}
for(var i=0;i<lines.length;i++){
var line=lines[i];
if(inCode){if(/^```/.test(line)){out.push('<pre><code'+(codeLang?' class="language-'+codeLang+'"':'')+'>'+escapeHtml(codeBuf.join('\\n'))+'</code></pre>');inCode=false;codeLang='';codeBuf=[]}else{codeBuf.push(line)};continue}
if(/^```/.test(line)){flushPara();closeLists();flushTable();flushBlockquote();inCode=true;codeLang=line.replace(/^```/,'').trim();codeBuf=[];continue}
var hMatch=/^(#{1,6})\\s+(.+?)\\s*#*\\s*$/.exec(line);
if(hMatch){flushPara();closeLists();flushTable();flushBlockquote();out.push('<h'+hMatch[1].length+'>'+renderInline(hMatch[2])+'</h'+hMatch[1].length+'>');continue}
if(/^\\s*$/.test(line)){flushPara();closeLists();flushTable();flushBlockquote();continue}
var hrMatch=/^---+$/.test(line);
if(hrMatch){flushPara();closeLists();flushTable();flushBlockquote();out.push('<hr />');continue}
var bqMatch=/^>\\s?(.*)$/.exec(line);
if(bqMatch){flushPara();closeLists();flushTable();if(!inBlockquote)inBlockquote=true;blockquoteBuf.push(bqMatch[1]);continue}
var ulMatch=/^\\s*[-*+]\\s+(.*)$/.exec(line);
if(ulMatch){flushPara();flushTable();flushBlockquote();var checked=ulMatch[1];var taskMatch=/^\\[(x| )\\]\\s+(.*)$/i.exec(checked);if(taskMatch){checked='<input type="checkbox" disabled'+(taskMatch[1].toLowerCase()==='x'?' checked':'')+' /> '+taskMatch[2]}if(inList!=='ul'){closeLists();inList='ul';listType='ul'}listItems.push(checked);continue}
var olMatch=/^\\s*\\d+\\.\\s+(.*)$/.exec(line);
if(olMatch){flushPara();flushTable();flushBlockquote();if(inList!=='ol'){closeLists();inList='ol';listType='ol'}listItems.push(olMatch[1]);continue}
var tableMatch=/^\\|(.+)\\|$/.exec(line);
if(tableMatch&&i+1<lines.length&&/^\\|?[\\s\\-:|]+\\|?$/.test(lines[i+1])){
flushPara();closeLists();flushBlockquote();
if(!inTable){inTable=true;tableHeader=tableMatch[1].split('|').map(function(c){return c.trim()});i++}
continue}
if(inTable&&/^\\|(.+)\\|$/.test(line)){tableRows.push(line.split('|').slice(1,-1).map(function(c){return c.trim()}).filter(Boolean));if(!lines[i+1]||!/^\\|/.test(lines[i+1]))flushTable();continue}
if(inTable){flushTable()}
paraBuf.push(line)
}
flushPara();closeLists();flushTable();flushBlockquote();if(inCode)out.push('<pre><code>'+escapeHtml(codeBuf.join('\\n'))+'</code></pre>');
return out.join('\\n')
}
function renderMarkdown(md){return renderBlock(md)}
function buildIndex(){var docs=[];var s=document.querySelectorAll('script[type="text/markdown"]');for(var i=0;i<s.length;i++){var el=s[i];if(!el.id||el.id==='doc-XXX')continue;docs.push({id:el.id.replace(/^doc-/,''),title:el.dataset.title||el.id,file:el.dataset.file||''})}return docs}
function renderSidebar(docs,currentId){
var groups=[
{label:'Overview',ids:['root','progress','docs-index']},
{label:'Reference',ids:['architecture','database','api']},
{label:'Features',ids:['ai-agent','frontend','rbac']},
{label:'Operations',ids:['operations','contributing']}
];
var byId={};for(var i=0;i<docs.length;i++)byId[docs[i].id]=docs[i];
return groups.map(function(g){var items=g.ids.filter(function(id){return byId[id]}).map(function(id){var active=id===currentId?' class="active"':'';return '<li><a href="#'+id+'" data-doc="'+id+'"'+active+'>'+escapeHtml(byId[id].title)+'</a></li>'}).join('');if(!items)return '';return '<div class="nav-group"><span class="nav-group-title">'+escapeHtml(g.label)+'</span><ul>'+items+'</ul></div>'}).join('')+'<div class="nav-group"><span class="nav-group-title">Search</span><p style="font-size:12px;color:var(--text-soft);padding:0 8px;margin:6px 0 0;">Tip: <kbd>/</kbd> focuses the search box.</p></div>'
}
function loadDoc(id){var el=document.getElementById('doc-'+id);if(!el){document.getElementById('doc').innerHTML='<p style="color:var(--text-soft);">Document not found.</p>';return}var html=renderMarkdown(el.textContent);var fileNote=el.dataset.file?'<p style="font-size:12px;color:var(--text-soft);margin-top:-8px;margin-bottom:18px;">Source: <code>'+escapeHtml(el.dataset.file)+'</code></p>':'';document.getElementById('doc').innerHTML=fileNote+html;var links=document.querySelectorAll('.sidebar a[data-doc]');for(var i=0;i<links.length;i++)links[i].className=links[i].dataset.doc===id?'active':'';history.replaceState(null,'','#'+id);window.scrollTo(0,0)}
function buildSearchIndex(){var idx=[];var s=document.querySelectorAll('script[type="text/markdown"]');for(var i=0;i<s.length;i++){var el=s[i];if(!el.id||el.id==='doc-XXX')continue;var lines=el.textContent.split('\\n');var heading='';for(var j=0;j<lines.length;j++){var h=/^#{1,3}\\s+(.+?)\\s*$/.exec(lines[j]);if(h)heading=h[1];var text=lines[j].replace(/[\\`*_#>[\\]]/g,'').trim();if(text.length>30)idx.push({id:el.id.replace(/^doc-/,''),heading:heading,text:text})}}return idx}
function search(q){if(!q||q.length<2)return [];var idx=window.__searchIdx;var lower=q.toLowerCase();var matches=[];var seen={};for(var i=0;i<idx.length;i++){if(idx[i].text.toLowerCase().indexOf(lower)>=0){var key=idx[i].id+'|'+idx[i].heading+'|'+idx[i].text.slice(0,60);if(seen[key])continue;seen[key]=true;matches.push(idx[i]);if(matches.length>=25)break}}return matches}
function renderSearchResults(matches,q){
  if(!matches.length)return '<p style="color:var(--text-soft);font-size:13px;">No matches.</p>';
  var grouped={};
  for(var i=0;i<matches.length;i++)(grouped[matches[i].id]=grouped[matches[i].id]||[]).push(matches[i]);
  var titleById={};
  var s=document.querySelectorAll('script[type="text/markdown"]');
  for(var i=0;i<s.length;i++)if(s[i].id&&s[i].id!=='doc-XXX')titleById[s[i].id.replace(/^doc-/,'')]=s[i].dataset.title||s[i].id;
  var html='';
  for(var id in grouped){
    html+='<div class="nav-group"><span class="nav-group-title">'+escapeHtml(titleById[id]||id)+'</span><ul>';
    var items=grouped[id].slice(0,5);
    for(var j=0;j<items.length;j++){
      var m=items[j];
      var snippet=m.text.length>110?m.text.slice(0,110)+'…':m.text;
      var re=new RegExp('('+q.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&')+')','ig');
      var highlighted=snippet.replace(re,'<mark>$1</mark>');
      html+='<li><a href="#'+id+'" data-doc="'+id+'">'+escapeHtml(m.heading)+'</a><br><span style="font-size:12px;color:var(--text-soft);">'+highlighted+'</span></li>';
    }
    html+='</ul></div>';
  }
  return html;
}
function initTheme(){var saved=localStorage.getItem('crm-docs-theme')||'light';document.documentElement.setAttribute('data-theme',saved);var btn=document.getElementById('theme-toggle');btn.textContent=saved==='dark'?'☀️':'🌙';btn.addEventListener('click',function(){var c=document.documentElement.getAttribute('data-theme')||'light';var n=c==='dark'?'light':'dark';document.documentElement.setAttribute('data-theme',n);localStorage.setItem('crm-docs-theme',n);btn.textContent=n==='dark'?'☀️':'🌙'})}
function initPrintButton(){var btn=document.getElementById('print-btn');if(btn)btn.addEventListener('click',function(){window.print()})}
function boot(){
initTheme();
initPrintButton();
var docs=buildIndex();
var initialId=(location.hash||'#root').slice(1);
var valid=false;
for(var i=0;i<docs.length;i++)if(docs[i].id===initialId){valid=true;break}
if(!valid)initialId='root';
document.getElementById('nav').innerHTML=renderSidebar(docs,initialId);
loadDoc(initialId);
document.getElementById('nav').addEventListener('click',function(e){var a=e.target.closest('a[data-doc]');if(!a)return;e.preventDefault();loadDoc(a.dataset.doc)});
window.addEventListener('hashchange',function(){var id=location.hash.slice(1);for(var i=0;i<docs.length;i++)if(docs[i].id===id){loadDoc(id);break}});
window.__searchIdx=buildSearchIndex();
var searchInput=document.getElementById('search');
var nav=document.getElementById('nav');
function showAll(){nav.innerHTML=renderSidebar(docs,initialId)}
searchInput.addEventListener('input',function(e){
  var q=e.target.value;
  if(q.length<2){showAll();return}
  var results=search(q);
  nav.innerHTML=renderSearchResults(results,q)+'<div style="padding:8px;border-top:1px solid var(--border);margin-top:8px;"><a href="#" id="search-clear" style="font-size:12px;color:var(--text-soft);">← Back to full index</a></div>';
  document.getElementById('search-clear').addEventListener('click',function(ev){ev.preventDefault();searchInput.value='';showAll()})
});
document.addEventListener('keydown',function(e){if(e.key==='/'&&document.activeElement!==searchInput){e.preventDefault();searchInput.focus()}else if(e.key==='Escape'&&document.activeElement===searchInput){searchInput.value='';showAll();searchInput.blur()}})
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot()
})();
  </script>
</body>
</html>
`;

// ---------- Embed markdown sources ----------
const embedded = docFiles.map(({ id, file, title }) => {
  if (!fs.existsSync(file)) {
    console.error(`⚠️  missing: ${file}`);
    return '';
  }
  let content = fs.readFileSync(file, 'utf8');
  // Strip the leading H1 (the sidebar already shows the title) for non-root docs
  if (id !== 'root') {
    content = content.replace(/^# [^\n]*\n+/, '');
  }
  // CRITICAL: escape any literal </script> in the markdown content so it
  // doesn't terminate our <script type="text/markdown"> block prematurely.
  const safe = content.replace(/<\/script>/gi, '<\\/script>');
  return `  <script type="text/markdown" id="doc-${id}" data-title="${title}" data-file="${file}">\n${safe}\n  </script>`;
}).filter(Boolean).join('\n');

const finalHtml = TEMPLATE
  .replace(/__PROJECT__/g, project)
  .replace('<script type="text/markdown" id="doc-XXX"></script>', embedded);

fs.writeFileSync(outPath, finalHtml);

// Self-test: extract the inlined <script>...</script> JS, run `node --check`.
// Catches `$&` regex-escape bugs and other JS syntax errors that would
// only surface when the page is opened in a browser.
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
    process.exit(1);
  } finally {
    try { fs.unlinkSync(tmpScript); } catch (e) { /* ignore */ }
  }
}

console.log(`✓ Built ${outPath}`);
console.log(`  Size: ${(fs.statSync(outPath).size / 1024).toFixed(1)} KB`);
console.log(`  Embedded ${docFiles.length} doc(s)`);
console.log(`  Open with: open ${outPath}`);
