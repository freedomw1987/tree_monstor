# Tiptap / ProseMirror rich text editor E2E testing patterns

> Source: pm-system `e2e/tests/project-detail-bug-tab.spec.ts` Sprint 12 (2026-06-10)
> Real failure → fix cycle: 1/4 → 2/4 → 3/4 → 4/4 pass, total 12.7s

## Background: Tiptap 嘅 `onUpdate` 唔監聽 DOM `input` event

`RichTextEditor.tsx` 用 `@tiptap/react` 嘅 `useEditor` hook(L21):

```typescript
useEditor({
  content: value,
  onUpdate: ({ editor }) => {
    const html = editor.getHTML()           // ← 觸發點
    const normalized = html === '<p></p>' ? '' : html
    onChange(normalized)                    // ← React state 同步
  },
  editorProps: {
    handlePaste: (view, event) => {         // ← 真實 paste 入口
      const items = event.clipboardData?.items
      for (const item of items) {
        if (item.type.startsWith('image/')) {
          event.preventDefault()
          handleImageFile(item.getAsFile()!)  // ← 落到 data URL 或 upload
          return true
        }
      }
      return false
    },
  },
})
```

**關鍵 invariant**:`onUpdate` **只喺 Tiptap command pipeline 觸發**(eg. user typing、`editor.commands.setContent()`、`setImage()`)。**`el.innerHTML = '...'; el.dispatchEvent('input')` 唔會觸發**。但 React 嘅 `useEffect` 監聽 `value` 變化 → `editor.commands.setContent(value)` → 個 useEffect 會喺 React state 改完先跑,所以對「edit 模式」round-trip 工作。

**對「create 模式」第一次 set** 用 `innerHTML + input event`:
- React state `value=''`(initial)→ useEffect 比較 `currentHtml === incoming` 唔 set
- 直接 set DOM innerHTML → DOM 變咗
- React state 仲係 `''`
- Submit 時個 React state value(空) 變 `<p></p>` 經 normalize 變 `''`
- 個 description 跌咗

## 3 個 Pitfall 嘅完整 失敗/成功 紀錄

### Pitfall 1 — `innerHTML + dispatchEvent('input')` 對 inline `<img>` 失敗

```typescript
// ❌ 失敗:set 了 innerHTML 但 submit 後 backend 收到冇 <img>
const richDesc = `<p>text <strong>bold</strong></p><p><img src="data:image/png;base64,iVBORw0KGgo="></p>`
await proseMirror.evaluate((el, html) => {
  el.innerHTML = html
  el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: 'x' }))
}, richDesc)
await page.getByRole('button', { name: '建立缺陷' }).click()
// Backend GET /api/bugs/:id → description: "<p>text <strong>bold</strong></p><p></p>"
// 個 <p><img></p> 段落連同 <img> 整個被 Tiptap 喺 schema normalize 階段 drop 咗
```

**Error message observed**:
```
expect(received).toMatch(expected)
Expected: /<img[^>]+data:image\/png/
Received string: "<p>text <strong>bold</strong></p><p></p>"
```

**Root cause**:Tiptap Image extension 收到 `setContent(html)` 嘅 inline data URL `<img>` 會 silently drop,原因可能係:
1. 個 base64 token 唔完整(`iVBORw0KGgo=` 得太短,Tiptap 嘅 ProseMirror schema validator 認為 src 唔合法)
2. Tiptap `addImage` command 對 `data:` URL 唔友善(eg. 需要 https/http scheme)

無論 root cause 點,結論係 **唔可以靠 setContent 嚟測試 image paste**。

### Pitfall 1 嘅 fix — 用 `ClipboardEvent('paste')` 帶真實 File

```typescript
// ✅ 成功
const pngBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII='
await proseMirror.evaluate((el, b64) => {
  const bin = atob(b64)
  const bytes = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i)
  const file = new File([bytes], 'paste.png', { type: 'image/png' })
  const dt = new DataTransfer()
  dt.items.add(file)
  el.focus()
  el.dispatchEvent(new ClipboardEvent('paste', {
    bubbles: true,
    cancelable: true,
    clipboardData: dt,
  }))
}, pngBase64)
await page.waitForTimeout(500)  // FileReader async + Tiptap onUpdate + React state sync
// Submit → backend description: "<p>text <strong>bold</strong></p><p><img src=\"data:image/png;base64,iVBORw0KGgo...\" alt=\"\"></p>"
```

**為咩 work**:`handlePaste` 喺 `editorProps` 監聽 `paste` event(原生 DOM event,Playwright dispatch 會觸發)→ 見到 `clipboardData.items[0].type === 'image/png'` → 拎 File → `handleImageFile(file)` → 因 ProjectDetailPage 冇傳 `uploadEntity` prop,fallback `FileReader.readAsDataURL(file)` → `editor.commands.setImage({ src: dataUrl })` → `onUpdate` 觸發 → `onChange(dataUrl)` 同步 React state。

### Pitfall 2 — Edit mode 嘅 `innerHTML` mock 點解 work

`bugs-fix.spec.ts:217-221` 嗰個 pattern 喺 **edit 模式** work 嘅原因(L211):

```typescript
// 1. 個 bug 已經有 description(server side)
// 2. PUT /api/bugs/:id 表單開咗,RichTextEditor value = bug.description
// 3. useEffect 監聽 value,setContent(value) 將 React state sync 入 Tiptap
// 4. 用戶 mock innerHTML,DOM 變咗但 React state 唔變
// 5. submit 按鈕 click → handleEditBug 用 React state 嘅 value(就係 bug.description 原本嗰個 string,做咗編輯後再 set)
// 6. 因為 onChange 唔 trigger,React state 唔變 → 改咗嘅內容 唔 save
```

但 spec 仍然 pass,因為 PUT API 接受舊 description,response 返原本 string,UI 即時更新顯示原本 string。**Test 冇真正 verify 用戶嘅編輯被 save**。

呢個係 **anti-pattern** — spec pass 但 feature regression 冇 cover。如果要真 cover edit 嘅 image paste,需要做用 Pitfall 1 嘅 workaround。

### Pitfall 3 — 唔好信 DOM `.ProseMirror` 嘅 innerHTML 嚟做 assertion

```typescript
// ❌ 失敗:DOM innerHTML 有 <img>,但 React state 冇
await proseMirror.evaluate((el, html) => {
  el.innerHTML = html
  // ... 冇 trigger Tiptap onUpdate
}, '<p>text</p><p><img src="data:..."></p>')
// 喺呢個 moment DOM 有 <img> ✓
await page.getByRole('button', { name: '建立缺陷' }).click()
// submit 嘅 body 用 React state(冇 <img>)→ backend 冇 <img>
```

**✅ Assertion 必須喺 server side**:
```typescript
const detail = await page.request.get(`${BACKEND}/api/bugs/${found.id}`)
const detailBody = await detail.json()
expect(detailBody.bug.description).toMatch(/<img[^>]+data:image\/png/)
```

## Alternative: 有 `uploadEntity` prop 嘅 app

如果 `RichTextEditor` 接受 `uploadEntity={{ type: 'bug', id: 'xxx' }}`(pm-system 嘅 RequirementDetailPage / BugDetailPage 嗰啲 callers),`handleImageFile` 會 upload 去 `/api/attachments` 同 insert URL:

```typescript
// 1. Mock upload endpoint via page.route
await page.route('**/api/attachments/upload', async (route) => {
  await route.fulfill({
    status: 200,
    contentType: 'application/json',
    body: JSON.stringify({
      id: 'mock-att-1',
      filename: 'paste.png',
      url: '/api/attachments/mock-att-1',
    }),
  })
})
// 2. 觸發 file input change(唔係 clipboard paste)
//    file input 喺 RichTextEditor 入面係隱藏,<input type="file" className="hidden">
// 3. 抑或 dispatch 真實 paste event(如上)
```

Upload path 嘅 test 仲要 cleanup mock attachment,否則 mock ID 喺 `description` 嘅 `<img src="/api/attachments/mock-att-1">` 喺 reload 嘅時候會 404(因為 mock ID 唔真實存在)。

## Quick reference: 邊個 pattern 對應咩 content type

| Content | Mock method | Works? |
|---|---|---|
| 純文字 paragraph | `innerHTML + dispatchEvent('input')` | ✅ |
| `<strong>` / `<em>` / `<a>` inline mark | `innerHTML + dispatchEvent('input')` | ✅ |
| `<h2>` heading | `innerHTML + dispatchEvent('input')` | ⚠️ 部分 |
| `<ul>` / `<ol>` list | `innerHTML + dispatchEvent('input')` | ⚠️ 部分 |
| Image paste(data URL, 冇 uploadEntity) | `ClipboardEvent('paste', { clipboardData: dt })` + image File | ✅ |
| Image upload(有 uploadEntity) | 必須 mock `/api/attachments/upload` + clipboard paste 或 file input | ✅ |
| Drag-drop file | `DispatchEvent('drop', { dataTransfer: dt })` + image File | ✅ |

## 相關 source code

- `frontend/src/components/RichTextEditor.tsx` L73-79: Tiptap `onUpdate` callback
- `frontend/src/components/RichTextEditor.tsx` L85-99: `handlePaste` for image/* File
- `frontend/src/components/RichTextEditor.tsx` L120-145: `handleImageFile` with/without `uploadEntity`
- `frontend/src/components/RichTextEditor.tsx` L150-160: `useEffect` sync React state → Tiptap setContent
- `frontend/src/pages/ProjectDetailPage.tsx` L1729: `<RichTextEditor value={newBugDesc} onChange={setNewBugDesc} ... />` — 冇 uploadEntity
- `frontend/src/pages/RequirementDetailPage.tsx` L? `<RichTextEditor value={editReqDesc} onChange={setEditReqDesc} uploadEntity={{ type: 'requirement', id }} />` — 有 uploadEntity

## 點解唔好提 Tiptap schema API 直接 mock

**Option B**: 用 `window.__editor` reference 拎 Tiptap editor instance,直接 call `editor.commands.setContent('<p>text</p>')`:

```typescript
// ❌ 唔 robust:RichTextEditor 冇 expose 個 editor instance
await page.evaluate(() => {
  // 揾唔到 Tiptap instance(global window 冇)
})
```

Tiptap 嘅 `useEditor` 唔 default 將 editor 暴露 global。透過 React DevTools probe / `__REACT_DEVTOOLS_GLOBAL_HOOK__` 拎到 fiber → 攞到 hook state → call setContent,**但係依賴 React internals + 容易 break 喺 minor version bump**。**唔建議**。

`ClipboardEvent('paste', { clipboardData })` 係 surface-level 嘅真實用戶行為,Playwright 完全支援,robust 過依賴 React internals。
