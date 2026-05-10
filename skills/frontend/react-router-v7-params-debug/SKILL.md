---
name: react-router-v7-params-debug
description: Debug route params not being passed in react-router-dom v7 components
---

# react-router-dom v7 Route Params Debugging

## Trigger Condition
When URL params (`:token`, `:email`, etc.) from react-router routes are `undefined` in component props, causing API calls to fail silently or send empty params.

## Root Cause
**react-router-dom v7 changed how route params are passed to components.**

Old pattern (v6): Route params were automatically passed as props.
```jsx
// v6 - token arrived as prop automatically
function ResetPassword({ token }) { ... }
<Route path="/reset/:token" element={<ResetPassword />} />
```

New pattern (v7): Route params are NOT passed as props. Must use `useParams()` hook.
```jsx
// v7 - MUST use useParams()
import { useParams } from 'react-router-dom';
function ResetPassword() {
  const { token } = useParams();
  ...
}
```

## Diagnosis Steps

1. **Check if component receives params as props**: Inspect the component definition - if it destructures params from props instead of using `useParams()`, that's the bug.

2. **Instrument fetch to see what's sent**: In browser console (or via browser_console tool):
```js
window._fetch = window.fetch;
window.fetch = function(...args) {
  console.log('FETCH:', args[0], JSON.parse(args[1]?.body||'{}'));
  return window._fetch(...args).then(r => { console.log('RESP:', r.status); return r; });
};
```

3. **Verify build is actually updated**: Check `dist/index.html` for the new JS hash, and confirm the compiled JS contains `useParams` references.

4. **Clear browser cache**: Use privacy/incognito mode, or DevTools Network tab with "Disable cache" checked. Old JS may be cached.

## Fix Pattern
```jsx
import { useParams } from 'react-router-dom';

function YourComponent() {
  const { paramName } = useParams();
  // use paramName in API calls, etc.
}
```

## Special Case: Email params need decodeURIComponent
URL-encoded params (like email addresses) need decoding:
```jsx
function Verify() {
  const { email } = useParams();
  const email = decodeURIComponent(email || ''); // email is URL-encoded in route
}
```

Update `App.jsx` routes — no need to pass params as props:
```jsx
// Before (v6 style - broken in v7)
<Route path="/reset/:token" element={<ResetPassword token={token} />} />

// After (v7 - correct)
<Route path="/reset/:token" element={<ResetPassword />} />
```

## Affected Components (watch for this pattern)
- `ResetPassword` — receives `:token` from URL
- `Verify` — receives `:email` from URL
- Any component using URL params (`:id`, `:slug`, etc.)

## Verification
After fix, the fetch call body should contain the full params:
```js
// Before (broken): {password: "xxx"} — missing token
// After (fixed): {token: "abc123", password: "xxx"}
```
