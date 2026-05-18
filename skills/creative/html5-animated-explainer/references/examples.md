# 參考示例說明

---

## 完整參考實現

David Chu 的原始專案位於：

```
~/projects/animation-skill/
```

該目錄包含：
- `README.md` — 完整的 Prompt 文本（包含 ENGINE REQUIREMENTS）
- 參考實現架構描述（見 README.md 第 10-117 行）

---

## 最小可運行示例（Minimal Example）

以下是符合引擎規範的最精簡示例，僅有 2 個場景，用於驗證引擎正確性：

### 使用方式

1. 複製以下 HTML 內容
2. 儲存為 `demo.html`
3. 雙擊運行

```html
<!DOCTYPE html>
<html lang="zh-TW">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>HTML5 Animated Explainer — Demo</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Chiron+GoRound+TC&family=DM+Mono:wght@400;500&family=Instrument+Serif&display=swap" rel="stylesheet">
<style>
:root{
  --bg:#F9F7F7;--bg2:#EEF1F7;--card:#fff;--teal:#3F72AF;
  --teal-soft:rgba(63,114,175,0.08);--coral:#E07A5F;
  --coral-soft:rgba(224,122,95,0.08);--navy:#112D4E;--text:#112D4E;
  --muted:rgba(17,45,78,0.7);--border:rgba(17,45,78,0.08);
  --shadow:0 2px 20px rgba(17,45,78,0.06);
  --font-heading:'Chiron GoRound TC','Instrument Serif',sans-serif;
  --font-body:'Chiron GoRound TC',sans-serif;
  --font-mono:'DM Mono',monospace;
}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:var(--font-body);background:var(--bg);color:var(--text);overflow:hidden}

/* ── Ambient Layer ── */
#ambient{position:fixed;inset:0;pointer-events:none;z-index:0;overflow:hidden}
#ambient .p{position:absolute;border-radius:50%;background:var(--teal-soft);animation:float linear infinite}
#ambient .p:nth-child(odd){background:var(--coral-soft)}
@keyframes float{0%{transform:translateY(0)rotate(0deg);opacity:.6}100%{transform:translateY(-100vh)rotate(360deg);opacity:0}}
#ambient .bg{position:absolute;border-radius:50%;filter:blur(80px);opacity:.4;animation:drift 20s ease-in-out infinite alternate}
#ambient .bg:nth-child(1){width:600px;height:600px;background:var(--teal-soft);top:-200px;right:-100px}
#ambient .bg:nth-child(2){width:500px;height:500px;background:var(--coral-soft);bottom:-150px;left:-100px;animation-delay:-10s}
@keyframes drift{0%{transform:translate(0,0)scale(1)}100%{transform:translate(30px,20px)scale(1.1)}}
#sceneFlash{position:fixed;inset:0;pointer-events:none;z-index:1;background:radial-gradient(circle at 50% 50%,rgba(63,114,175,0.15),transparent 70%);opacity:0;transition:opacity .1s}
#sceneFlash.flash{opacity:1}

/* ── Stage ── */
#stage{position:fixed;inset:0 0 44px 0;perspective:1800px;z-index:2}
.scene{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;opacity:0;transform:scale(1.05)translateZ(-200px);transition:opacity .8s cubic-bezier(.4,0,.2,1),transform .8s cubic-bezier(.4,0,.2,1);pointer-events:none;gap:24px}
.scene.active{opacity:1;transform:scale(1)translateZ(0);pointer-events:auto}
.scene.zoom-out{opacity:0;transform:scale(1.1)translateZ(-400px)}

/* ── Text ── */
.subtitle{font-family:var(--font-mono);font-size:12px;color:var(--teal);text-transform:uppercase;letter-spacing:3px;opacity:0;transform:translateY(20px);transition:opacity .6s ease,transform .6s ease}
.title{font-family:var(--font-heading);font-size:clamp(32px,6vw,64px);color:var(--navy);text-align:center;opacity:0;transform:translateY(20px);transition:opacity .6s ease .2s,transform .6s ease .2s}
.title .hl{color:var(--teal)}
.note{font-size:16px;color:var(--muted);max-width:640px;text-align:center;line-height:1.7;opacity:0;transform:translateY(20px);transition:opacity .6s ease .4s,transform .6s ease .4s}
.note code{background:var(--teal-soft);color:var(--teal);padding:2px 8px;border-radius:4px;font-family:var(--font-mono);font-size:14px}

/* data-at reveal */
[data-at="1"]{transition-delay:.1s}
[data-at="2"]{transition-delay:.3s}
[data-at="3"]{transition-delay:.5s}
[data-at="4"]{transition-delay:.7s}
[data-at="5"]{transition-delay:.9s}
[data-at="6"]{transition-delay:1.1s}
[data-at="7"]{transition-delay:1.3s}
[data-at="8"]{transition-delay:1.5s}
.scene[data-visible] .subtitle,
.scene[data-visible] .title,
.scene[data-visible] .note{opacity:1;transform:translateY(0)}

/* ── 3D Visual: Rotating Cube Demo ── */
.cube-scene{width:200px;height:200px;perspective:800px;opacity:0;transform:translateY(20px);transition:opacity .6s ease .6s,transform .6s ease .6s}
.cube{width:100%;height:100%;position:relative;transform-style:preserve-3d;animation:cubeSpin 8s linear infinite}
@keyframes cubeSpin{0%{transform:rotateX(-20deg)rotateY(0deg)}100%{transform:rotateX(-20deg)rotateY(360deg)}}
.cube .face{position:absolute;width:200px;height:200px;background:var(--card);border:1px solid var(--border);box-shadow:var(--shadow);display:flex;align-items:center;justify-content:center;font-family:var(--font-mono);font-size:12px;color:var(--muted);backface-visibility:hidden}
.cube .face:nth-child(1){transform:rotateY(0deg)translateZ(100px)}
.cube .face:nth-child(2){transform:rotateY(90deg)translateZ(100px)}
.cube .face:nth-child(3){transform:rotateY(180deg)translateZ(100px)}
.cube .face:nth-child(4){transform:rotateY(-90deg)translateZ(100px)}
.cube .face:nth-child(5){transform:rotateX(90deg)translateZ(100px)}
.cube .face:nth-child(6){transform:rotateX(-90deg)translateZ(100px)}

/* ── 3D Visual: Flip Card Demo ── */
.flipcard-scene{width:280px;height:180px;perspective:1000px;opacity:0;transform:translateY(20px);transition:opacity .6s ease .6s,transform .6s ease .6s}
.flipcard{width:100%;height:100%;position:relative;transform-style:preserve-3d;animation:flipAnim 4s ease-in-out infinite}
@keyframes flipAnim{0%,100%{transform:rotateY(0deg)}50%{transform:rotateY(180deg)}}
.flipcard .fc{position:absolute;width:100%;height:100%;backface-visibility:hidden;border-radius:16px;display:flex;align-items:center;justify-content:center;font-family:var(--font-heading);font-size:24px;color:var(--card)}
.flipcard .fc.front{background:var(--teal);box-shadow:var(--shadow)}
.flipcard .fc.back{background:var(--coral);transform:rotateY(180deg)}

/* ── Controls Bar ── */
#ctrl{position:fixed;bottom:0;left:0;right:0;height:44px;background:rgba(255,255,255,0.95);backdrop-filter:blur(12px);border-top:1px solid var(--border);display:flex;align-items:center;padding:0 16px;gap:12px;z-index:100}
#prog{position:absolute;top:0;left:0;right:0;height:3px;background:var(--border);cursor:pointer}
#progbar{height:100%;background:var(--teal);width:0%;transition:width .1s linear}
.chap{position:absolute;top:0;width:2px;height:100%;background:rgba(255,255,255,0.8);transform:translateX(-50%)}
.chap.past{background:var(--coral)}
.chap.next{animation:pulse 1.5s ease-in-out infinite}
@keyframes pulse{0%,100%{opacity:.4}50%{opacity:1}}
.caption{flex:1;font-size:13px;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.time{font-family:var(--font-mono);font-size:12px;color:var(--muted);white-space:nowrap}
.btn{cursor:pointer;background:none;border:none;font-size:18px;padding:4px 10px;color:var(--navy);transition:color .2s,transform .1s;user-select:none}
.btn:hover{color:var(--teal)}
.btn:active{transform:scale(0.92)}
.btn.on{color:var(--coral)}

/* ── Accessibility ── */
@media(prefers-reduced-motion:reduce){
  *,*::before,*::after{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important}
}
</style>
</head>
<body>

<!-- Ambient -->
<div id="ambient">
  <div class="bg"></div><div class="bg"></div>
  <!-- 18 particles added by JS -->
</div>
<div id="sceneFlash"></div>

<!-- Stage -->
<div id="stage">
  <!-- Scene 0: Rotating Cube -->
  <div class="scene" data-scene="0">
    <div class="subtitle" data-at="1">3D TRANSFORM</div>
    <div class="title" data-at="2">從 <span class="hl">噪點</span> 到驚艷</div>
    <div class="cube-scene" data-at="3">
      <div class="cube">
        <div class="face">FRONT</div>
        <div class="face">RIGHT</div>
        <div class="face">BACK</div>
        <div class="face">LEFT</div>
        <div class="face">TOP</div>
        <div class="face">BOTTOM</div>
      </div>
    </div>
    <div class="note" data-at="5">一切始於隨機——然後 AI 學會看見模式</div>
  </div>

  <!-- Scene 1: Flip Card -->
  <div class="scene" data-scene="1">
    <div class="subtitle" data-at="1">FLIP CARD</div>
    <div class="title" data-at="2">學習 <span class="hl">翻轉</span> 思考</div>
    <div class="flipcard-scene" data-at="3">
      <div class="flipcard">
        <div class="fc front">看這面</div>
        <div class="fc back">翻轉了！</div>
      </div>
    </div>
    <div class="note" data-at="5">當你需要切換視角時，翻牌效果最有效</div>
  </div>
</div>

<!-- Controls -->
<div id="ctrl">
  <div id="prog"><div id="progbar"></div></div>
  <button class="btn" id="prevBtn" title="上一頁 (←)">◀</button>
  <button class="btn" id="playBtn" title="播放/暫停 (Space)">▶</button>
  <button class="btn" id="nextBtn" title="下一頁 (→)">▶</button>
  <div class="caption" id="cap"></div>
  <div class="time"><span id="ct">00:00</span> / <span id="tt">00:00</span></div>
</div>

<script>
const scenes = [
  { start:0, end:10, el: document.querySelector('[data-scene="0"]') },
  { start:10, end:20, el: document.querySelector('[data-scene="1"]') }
];
const subs = [
  {s:0,e:5,t:'一切從隨機噪點開始'},
  {s:5,e:10,t:'AI 慢慢看見輪廓'},
  {s:10,e:15,t:'翻轉視角，發現新可能'},
  {s:15,e:20,t:'下一步，由你決定'}
];
const TOTAL = 20;
let currentTime = 0, playing = false, lastTS = 0;

function pad(n){return String(Math.floor(n)).padStart(2,'0')}
function setTime(t){currentTime=Math.max(0,Math.min(t,TOTAL));update()}

function update(){
  const t=currentTime;
  document.getElementById('ct').textContent=`${pad(t/60)}:${pad(t%60)}`;
  document.getElementById('tt').textContent=`${pad(TOTAL/60)}:${pad(TOTAL%60)}`;
  document.getElementById('progbar').style.width=(t/TOTAL*100)+'%';

  // captions
  const sub=subs.find(s=>t>=s.s&&t<s.e);
  const cap=document.getElementById('cap');
  if(sub&&cap.textContent!==sub.t){cap.classList.remove('cap-in');void cap.offsetWidth;cap.textContent=sub.t;cap.classList.add('cap-in')}
  cap.style.opacity=sub?1:0;

  // scenes
  let curScene=null;
  scenes.forEach((sc,i)=>{
    const active=t>=sc.start&&t<sc.end;
    if(active)curScene=i;
    sc.el.classList.remove('active','zoom-out');
    if(active){sc.el.classList.add('active');sc.el.setAttribute('data-visible','')}
    else if(t<sc.start)sc.el.classList.remove('active');
    else sc.el.classList.add('zoom-out');
  });

  // chapter dots
  document.querySelectorAll('.chap').forEach((d,i)=>{
    d.classList.toggle('past',i<curScene);
    d.classList.toggle('next',i===curScene);
  });
}

function tick(ts){
  if(playing&&lastTS){const dt=(ts-lastTS)/1000;setTime(currentTime+dt)}
  lastTS=playing?ts:0;
  requestAnimationFrame(tick);
}
requestAnimationFrame(tick);

document.getElementById('playBtn').onclick=()=>{playing=!playing;document.getElementById('playBtn').textContent=playing?'⏸':'▶';document.getElementById('playBtn').classList.toggle('on',playing)};
document.getElementById('prevBtn').onclick=()=>{const cs=scenes.findIndex(s=>currentTime>=s.start&&currentTime<s.end);setTime(cs>0?scenes[cs-1].start:0)};
document.getElementById('nextBtn').onclick=()=>{const cs=scenes.findIndex(s=>currentTime>=s.start&&currentTime<s.end);setTime(cs<scenes.length-1?scenes[cs+1].start:TOTAL)};
document.getElementById('prog').onclick=e=>{const r=document.getElementById('prog').getBoundingClientRect();setTime((e.clientX-r.left)/r.width*TOTAL)};

document.onkeydown=e=>{
  if(e.code==='Space'){e.preventDefault();document.getElementById('playBtn').click()}
  if(e.key==='ArrowLeft')document.getElementById('prevBtn').click();
  if(e.key==='ArrowRight')document.getElementById('nextBtn').click()
};
let tx=0;
document.ontouchstart=e=>{tx=e.touches[0].clientX};
document.ontouchend=e=>{const dx=e.changedTouches[0].clientX-tx;if(Math.abs(dx)>50){dx<0?document.getElementById('nextBtn').click():document.getElementById('prevBtn').click()}};

// ambient particles
const amb=document.getElementById('ambient');
for(let i=0;i<18;i++){
  const p=document.createElement('div');p.className='p';
  const s=10+Math.random()*30,w=s;
  p.style.cssText=`width:${s}px;height:${s}px;left:${Math.random()*100}%;top:${Math.random()*120}%;animation-duration:${15+Math.random()*20}s;animation-delay:${-Math.random()*20}s`;
  amb.appendChild(p);
}

// flash on scene change
let lastScene=-1;
setInterval(()=>{
  const cs=scenes.findIndex(s=>currentTime>=s.start&&currentTime<s.end);
  if(cs!==lastScene&&lastScene!==-1){const f=document.getElementById('sceneFlash');f.classList.add('flash');setTimeout(()=>f.classList.remove('flash'),200)}
  lastScene=cs;
},100);

// chapter dots
const prog=document.getElementById('prog');
scenes.slice(1).forEach((sc,i)=>{
  const d=document.createElement('div');d.className='chap';
  d.style.left=(sc.start/TOTAL*100)+'%';
  prog.appendChild(d);
});

update();
</script>
</body>
</html>
```

---

## 驗收清單（QA Gate）

產出的 HTML 必須通過以下所有檢查：

- [ ] 雙擊 `.html` 文件直接運行（無需 server）
- [ ] Play/Pause/Prev/Next 按鈕正常運作
- [ ] 進度條可點擊跳轉
- [ ] 章節點存在且點擊可跳轉
- [ ] `prefers-reduced-motion` 查詢存在
- [ ] 所有 3D 動畫使用純 CSS `transform`，無任何 library
- [ ] Google Fonts 載入成功（檢查 Network tab）
- [ ] 切換場景時 `#sceneFlash` 有閃光效果
- [ ] 18 個 ambient particles 存在
- [ ] 無 JavaScript console error