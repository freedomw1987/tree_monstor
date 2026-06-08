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
kbd{display:inline-block;padding:2px 5px;font-size:12px;line-height:1;color:var(--text);background:var(--kbd-bg);border:1px solid var(--border);border-radius:4px;vertical-align:middle}
.topbar{position:sticky;top:0;z-index:10;background:var(--topbar-bg);color:var(--topbar-text);border-bottom:1px solid var(--border)}
.topbar-inner{display:flex;align-items:center;gap:16px;padding:12px 24px;max-width:1400px;margin:0 auto}
.brand{font-size:17px;font-weight:600;margin:0;color:var(--topbar-text)}
.brand-sub{font-size:12px;color:var(--topbar-text-soft);margin-right:auto}
.topbar-actions{display:flex;align-items:center;gap:8px}
#search{padding:6px 10px;font-size:13px;background:var(--topbar-bg);color:var(--topbar-text);border:1px solid #444c56;border-radius:6px;width:220px;outline:none}
#search::placeholder{color:var(--topbar-text-soft)}#search:focus{border-color:var(--text-link)}
#theme-toggle{background:transparent;border:1px solid #444c56;border-radius:6px;padding:5px 9px;color:var(--topbar-text);font-size:14px;cursor:pointer}
#theme-toggle:hover{background:rgba(255,255,255,.08)}
.layout{display:grid;grid-template-columns:260px 1fr;max-width:1400px;margin:0 auto;min-height:calc(100vh - 53px)}
.sidebar{border-right:1px solid var(--border);background:var(--bg-soft);padding:24px 16px;overflow-y:auto;position:sticky;top:53px;max-height:calc(100vh - 53px)}
.nav-group{margin-bottom:12px}
.nav-group-title{font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.6px;color:var(--text-soft);margin:16px 8px 4px;display:block}
.nav-group ul{list-style:none;margin:0;padding:0}
.nav-group li a{display:block;padding:5px 8px;border-radius:6px;font-size:13.5px;color:var(--text)}
.nav-group li a:hover{background:var(--accent-bg);color:var(--text-link);text-decoration:none}
.nav-group li a.active{background:var(--accent-bg);color:var(--text-link);font-weight:600}
.content{padding:32px 40px;max-width:920px;width:100%}
.doc h1,.doc h2,.doc h3,.doc h4,.doc h5,.doc h6{margin-top:24px;margin-bottom:14px;font-weight:600;line-height:1.25}
.doc h1{font-size:2em;border-bottom:1px solid var(--border);padding-bottom:8px}
.doc h2{font-size:1.5em;border-bottom:1px solid var(--border);padding-bottom:6px}
.doc h3{font-size:1.25em}
.doc p{margin:0 0 14px}.doc ul,.doc ol{padding-left:26px;margin:0 0 14px}.doc li{margin:3px 0}
.doc code{background:var(--bg-code);border-radius:4px;padding:1.5px 5px;font-size:.88em;color:var(--text)}
.doc pre{background:var(--bg-code);border:1px solid var(--border);border-radius:6px;padding:14px 16px;overflow-x:auto;font-size:13px;line-height:1.5;margin:0 0 14px}
.doc pre code{background:transparent;border:0;padding:0;color:var(--text);white-space:pre}
.doc table{border-collapse:collapse;width:100%;margin:0 0 18px;display:block;overflow-x:auto;font-size:13.5px}
.doc th,.doc td{border:1px solid var(--border);padding:7px 11px;text-align:left;vertical-align:top}
.doc th{background:var(--bg-soft);font-weight:600}
.doc tbody tr:nth-child(even){background:var(--table-stripe)}
.doc blockquote{margin:0 0 14px;padding:0 14px;color:var(--blockquote);border-left:4px solid var(--border)}
.doc hr{border:0;border-top:1px solid var(--border);margin:26px 0}
.doc img{max-width:100%;height:auto}
mark{background:#fff3a3;color:inherit;padding:0 2px;border-radius:2px}
[data-theme=dark] mark{background:#7d4e00;color:#fff}
@media (max-width:800px){.layout{grid-template-columns:1fr}.sidebar{position:relative;top:0;max-height:none;border-right:0;border-bottom:1px solid var(--border)}.content{padding:24px 18px}.topbar-inner{flex-wrap:wrap}.brand-sub{display:none}#search{width:140px}}
@media print{.topbar,.sidebar{display:none}.layout{grid-template-columns:1fr}.content{padding:0;max-width:none}}
  </style>
</head>
<body>
  <header class="topbar">
    <div class="topbar-inner">
      <h1 class="brand">📋 __PROJECT__</h1>
      <span class="brand-sub">Documentation</span>
      <div class="topbar-actions">
        <input id="search" type="search" placeholder="搜尋文件..." aria-label="搜尋" />
        <button id="theme-toggle" aria-label="切換主題">🌙</button>
      </div>
    </div>
  </header>
  <div class="layout">
    <aside class="sidebar"><nav id="nav"></nav></aside>
    <main class="content"><article id="doc" class="doc"><div class="loading">載入中...</div></article></main>
  </div>
<SCRIPTS_PLACEHOLDER />
  <script>
(function(){
'use strict';
var escapeHtml=function(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#39;')};
function renderInline(text){
text=text.replace(/\`([^\`]+)\`/g,function(_,c){return '<code>'+c+'</code>'});
text=text.replace(/!\\[([^\\]]*)\\]\\(([^)\\s]+)(?:\\s+"([^"]*)")?\\)/g,function(_,alt,url,title){return '<img src="'+url+'" alt="'+alt+'"'+(title?' title="'+title+'"':'')+' loading="lazy" />'});
text=text.replace(/\\[([^\\]]+)\\]\\(([^)\\s]+)\\)/g,function(_,l,u){var e=/^https?:\\/\\//.test(u);return '<a href="'+u+'"'+(e?' target="_blank" rel="noopener"':'')+'>'+l+'</a>'});
text=text.replace(/\\*\\*([^*]+)\\*\\*/g,'<strong>$1</strong>');
text=text.replace(/__([^_]+)__/g,'<strong>$1</strong>');
text=text.replace(/(^|[^*])\\*([^*\\n]+)\\*(?!\\*)/g,'$1<em>$2</em>');
text=text.replace(/(^|[^_])_([^_\\n]+)_(?!_)/g,'$1<em>$2</em>');
return text;
}
function renderMarkdown(md){
var lines=md.split('\\n');var out=[];var i=0;var inCode=false;var codeLang='';var codeBuf=[];var listStack=[];var paraBuf=[];var inTable=false;var tableHeader=[];var tableRows=[];
var flushPara=function(){if(paraBuf.length){out.push('<p>'+renderInline(paraBuf.join(' '))+'</p>');paraBuf=[]}};
var closeLists=function(toIndent){toIndent=toIndent===undefined?-1:toIndent;while(listStack.length&&listStack[listStack.length-1].indent>toIndent)out.push('</'+listStack.pop().tag+'>')};
var flushTable=function(){if(!inTable)return;var aligns=tableHeader._aligns||[];out.push('<table><thead><tr>'+tableHeader.map(function(c,i){return '<th style="text-align:'+(aligns[i]||'left')+'">'+renderInline(c)+'</th>'}).join('')+'</tr></thead><tbody>'+tableRows.map(function(row){return '<tr>'+row.map(function(c,i){return '<td style="text-align:'+(aligns[i]||'left')+'">'+renderInline(c)+'</td>'}).join('')+'</tr>'}).join('')+'</tbody></table>');inTable=false;tableHeader=[];tableRows=[]};
while(i<lines.length){
var line=lines[i];var trimmed=line.trim();
if(/^\`\`\`/.test(trimmed)){if(inCode){out.push('<pre><code class="lang-'+escapeHtml(codeLang)+'">'+escapeHtml(codeBuf.join('\\n'))+'</code></pre>');inCode=false;codeBuf=[];codeLang=''}else{flushPara();closeLists();flushTable();inCode=true;codeLang=trimmed.slice(3).trim()}i++;continue}
if(inCode){codeBuf.push(line);i++;continue}
if(trimmed===''){flushPara();closeLists();flushTable();i++;continue}
if(/^(\\s*\\*){3,}$|^(\\s*-){3,}$|^(\\s*_){3,}$/.test(trimmed)){flushPara();closeLists();flushTable();out.push('<hr />');i++;continue}
var h=/^(#{1,6})\\s+(.+?)\\s*#*\\s*$/.exec(trimmed);
if(h){flushPara();closeLists();flushTable();var level=h[1].length;var text=h[2];var id=text.toLowerCase().replace(/[\`*_~]/g,'').replace(/[^a-z0-9\\u4e00-\\u9fff\\s-]/g,'').trim().replace(/\\s+/g,'-');out.push('<h'+level+' id="'+escapeHtml(id)+'">'+renderInline(text)+'</h'+level+'>');i++;continue}
if(/^>\\s?/.test(trimmed)){flushPara();closeLists();flushTable();var bqBuf=[];while(i<lines.length&&/^>\\s?/.test(lines[i].trim())){bqBuf.push(lines[i].trim().replace(/^>\\s?/,''));i++}out.push('<blockquote>'+renderMarkdown(bqBuf.join('\\n'))+'</blockquote>');continue}
if(/^\\s*\\|.*\\|\\s*$/.test(line)&&i+1<lines.length&&/^\\s*\\|?\\s*:?-+:?\\s*(\\|\\s*:?-+:?\\s*)+\\|?\\s*$/.test(lines[i+1])){flushPara();closeLists();if(!inTable){inTable=true;tableHeader=line.trim().replace(/^\\|/,'').replace(/\\|$/,'').split('|').map(function(c){return c.trim()});var sep=lines[i+1].trim().replace(/^\\|/,'').replace(/\\|$/,'').split('|').map(function(c){return c.trim()});tableHeader._aligns=sep.map(function(c){var l=c.startsWith(':');var r=c.endsWith(':');if(l&&r)return 'center';if(r)return 'right';if(l)return 'left';return ''});i+=2;continue}}
if(inTable&&/^\\s*\\|.*\\|\\s*$/.test(line)){var cells=line.trim().replace(/^\\|/,'').replace(/\\|$/,'').split('|').map(function(c){return c.trim()});tableRows.push(cells);i++;continue}else if(inTable){flushTable()}
var listMatch=/^(\\s*)([-*+]|\\d+\\.)\\s+(.*)$/.exec(line);
if(listMatch){flushPara();flushTable();var indent=listMatch[1].length;var marker=listMatch[2];var isOrdered=/\\d+\\./.test(marker);var tag=isOrdered?'ol':'ul';var content=listMatch[3];if(listStack.length===0||indent>listStack[listStack.length-1].indent){listStack.push({tag:tag,indent:indent});out.push('<'+tag+'>')}else if(indent===listStack[listStack.length-1].indent){}else{closeLists(indent-1);listStack.push({tag:tag,indent:indent});out.push('<'+tag+'>')}var taskMatch=/^\\[([ xX])\\]\\s+(.*)$/.exec(content);if(taskMatch){var checked=taskMatch[1]!==' ';out.push('<li class="task-list-item"><input type="checkbox" disabled'+(checked?' checked':'')+'/> '+renderInline(taskMatch[2])+'</li>')}else{out.push('<li>'+renderInline(content)+'</li>')}i++;continue}else if(listStack.length){closeLists()}
paraBuf.push(trimmed);i++
}
flushPara();closeLists();flushTable();if(inCode)out.push('<pre><code>'+escapeHtml(codeBuf.join('\\n'))+'</code></pre>');
return out.join('\\n')
}
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
function buildSearchIndex(){var idx=[];var s=document.querySelectorAll('script[type="text/markdown"]');for(var i=0;i<s.length;i++){var el=s[i];if(!el.id||el.id==='doc-XXX')continue;var lines=el.textContent.split('\\n');var heading='';for(var j=0;j<lines.length;j++){var h=/^#{1,3}\\s+(.+?)\\s*$/.exec(lines[j]);if(h)heading=h[1];var text=lines[j].replace(/[\`*_#>[\\]]/g,'').trim();if(text.length>30)idx.push({id:el.id.replace(/^doc-/,''),heading:heading,text:text})}}return idx}
function search(q){if(!q||q.length<2)return [];var idx=window.__searchIdx;var lower=q.toLowerCase();var matches=[];var seen={};for(var i=0;i<idx.length;i++){if(idx[i].text.toLowerCase().indexOf(lower)>=0){var key=idx[i].id+'|'+idx[i].heading+'|'+idx[i].text.slice(0,60);if(seen[key])continue;seen[key]=true;matches.push(idx[i]);if(matches.length>=25)break}}return matches}
function renderSearchResults(matches,q){if(!matches.length)return '<p style="color:var(--text-soft);font-size:13px;">No matches.</p>';var grouped={};for(var i=0;i<matches.length;i++)(grouped[matches[i].id]=grouped[matches[i].id]||[]).push(matches[i]);var titleById={};var s=document.querySelectorAll('script[type="text/markdown"]');for(var i=0;i<s.length;i++)if(s[i].id&&s[i].id!=='doc-XXX')titleById[s[i].id.replace(/^doc-/,'')]=s[i].dataset.title||s[i].id;var html='';for(var id in grouped){html+='<div class="nav-group"><span class="nav-group-title">'+escapeHtml(titleById[id]||id)+'</span><ul>';var items=grouped[id].slice(0,5);for(var j=0;j<items.length;j++){var m=items[j];var snippet=m.text.length>110?m.text.slice(0,110)+'…':m.text;var re=new RegExp('('+q.replace(/[.*+?^${}()|[\\]\\\\]/g,'\\\\$&')+')','ig');var highlighted=snippet.replace(re,'<mark>$1</mark>');html+='<li><a href="#'+id+'" data-doc="'+id+'">'+escapeHtml(m.heading)+'</a><br><span style="font-size:12px;color:var(--text-soft);">'+highlighted+'</span></li>'}html+='</ul></div>'}return html}
function initTheme(){var saved=localStorage.getItem('crm-docs-theme')||'light';document.documentElement.setAttribute('data-theme',saved);var btn=document.getElementById('theme-toggle');btn.textContent=saved==='dark'?'☀️':'🌙';btn.addEventListener('click',function(){var c=document.documentElement.getAttribute('data-theme')||'light';var n=c==='dark'?'light':'dark';document.documentElement.setAttribute('data-theme',n);localStorage.setItem('crm-docs-theme',n);btn.textContent=n==='dark'?'☀️':'🌙'})}
function boot(){initTheme();var docs=buildIndex();var initialId=(location.hash||'#root').slice(1);var valid=false;for(var i=0;i<docs.length;i++)if(docs[i].id===initialId){valid=true;break}if(!valid)initialId='root';document.getElementById('nav').innerHTML=renderSidebar(docs,initialId);loadDoc(initialId);document.getElementById('nav').addEventListener('click',function(e){var a=e.target.closest('a[data-doc]');if(!a)return;e.preventDefault();loadDoc(a.dataset.doc)});window.addEventListener('hashchange',function(){var id=location.hash.slice(1);for(var i=0;i<docs.length;i++)if(docs[i].id===id){loadDoc(id);break}});window.__searchIdx=buildSearchIndex();var searchInput=document.getElementById('search');var nav=document.getElementById('nav');function showAll(){nav.innerHTML=renderSidebar(docs,initialId)}searchInput.addEventListener('input',function(e){var q=e.target.value;if(q.length<2){showAll();return}var results=search(q);nav.innerHTML=renderSearchResults(results,q)+'<div style="padding:8px;border-top:1px solid var(--border);margin-top:8px;"><a href="#" id="search-clear" style="font-size:12px;color:var(--text-soft);">← Back to full index</a></div>';document.getElementById('search-clear').addEventListener('click',function(ev){ev.preventDefault();searchInput.value='';showAll()})});document.addEventListener('keydown',function(e){if(e.key==='/'&&document.activeElement!==searchInput){e.preventDefault();searchInput.focus()}else if(e.key==='Escape'&&document.activeElement===searchInput){searchInput.value='';showAll();searchInput.blur()}})}
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
  .replace('<SCRIPTS_PLACEHOLDER />', embedded);

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
