---
name: react-context-auth-user-switch
description: Detect user login/logout within same tab using React Context + localStorage — fixes stale user data when switching accounts without full page reload
tags: ['react', 'context', 'localstorage', 'auth', 'hooks']
---

# React Context — Detect User Login/Logout Within Same Tab

## Problem

When using React Context + localStorage for auth state, switching users (logout → login as different user) within the **same tab** fails to update the UI. The old user's data persists because Context's `useEffect` only runs on mount.

## Root Causes

1. `localStorage` changes do NOT trigger React re-renders
2. `window.addEventListener('storage', ...)` only fires across **other tabs**, not same-tab changes
3. Using `localStorage.getItem('auth_user')` as a `useEffect` dependency creates a new string reference every call, breaking equality checks

## Solution: Explicit Refresh Function from Login (Verified Working)

The most reliable approach: call an explicit refresh function from Login immediately after writing to localStorage, before navigating to the chat page.

### Step 1: ChatContext — expose `refreshConversations()` and `reset()`

```jsx
const refreshConversations = useCallback(() => {
  const token = localStorage.getItem('auth_token')
  if (!token) return
  dispatch({ type: 'RESET' })
  dispatch({ type: 'SET_LOADING_CONVERSATIONS', payload: true })
  apiFetch('/api/conversations')
    .then(data => {
      if (data.success) {
        dispatch({ type: 'SET_CONVERSATIONS', payload: data.data })
      }
    })
    .catch(err => console.error('[ChatContext] fetch error:', err))
    .finally(() => {
      dispatch({ type: 'SET_LOADING_CONVERSATIONS', payload: false })
    })
}, [])

const reset = useCallback(() => {
  dispatch({ type: 'RESET' })
}, [])

return (
  <ChatContext.Provider value={{
    state,
    createConversation,
    deleteConversation,
    renameConversation,
    selectConversation,
    addMessage,
    saveMessageToDb,
    reset,           // ← also expose reset
    refreshConversations,  // ← expose for explicit call from Login
  }}>
    {children}
  </ChatContext.Provider>
)
```

### Step 2: Login.jsx — call `refreshConversations()` on success

```jsx
import { useChat } from '../context/ChatContext';

function Login() {
  const { refreshConversations } = useChat()

  async function handleSubmit(e) {
    // ... validate + fetch token from API ...
    localStorage.setItem('auth_token', data.data.token)
    localStorage.setItem('auth_user', JSON.stringify(data.data.user))
    refreshConversations()  // ← call BEFORE navigate
    navigate('/chat')
  }
}
```

### Step 3: Logout — call `reset()` to clear stale context

```jsx
// In Sidebar.jsx logout handler
function handleLogout() {
  localStorage.removeItem('auth_token')
  localStorage.removeItem('auth_user')
  reset()  // ← clear React context state
  window.location.hash = '#/login'
}
```

## Anti-Patterns That Don't Work

| Approach | Why It Fails |
|----------|-------------|
| `useEffect(() => {...}, [localStorage.getItem('auth_user')])` | Returns a new string reference every call — unreliable as dependency |
| `window.addEventListener('storage', ...)` | Only fires in **other tabs**, not same tab |
| Polling with `setInterval` alone | Works but timing-dependent; use as fallback, not primary solution |
| `useRef` with check BEFORE assignment | Initial mount with existing token gets skipped — must set ref BEFORE check |

## Fallback: Polling for Edge Cases

The primary fix (Step 2 above) handles in-app login/logout. Add polling as a **secondary fallback** for edge cases like direct URL navigation after login, browser back/forward, or page refresh:

```jsx
// In ChatProvider — runs alongside the explicit refresh approach
const prevUserIdRef = useRef(getCurrentUserId())

useEffect(() => {
  const interval = setInterval(() => {
    const userId = getCurrentUserId()
    if (userId !== prevUserIdRef.current) {
      prevUserIdRef.current = userId
      if (!userId) {
        dispatch({ type: 'RESET' })
        return
      }
      refreshConversations()
    }
  }, 300)
  return () => clearInterval(interval)
}, [])
```

**Why 300ms:** Fast enough to catch user switch within ~300ms, not so fast as to cause performance issues.

**Note:** `useRef` ordering matters — always set `prevUserIdRef.current = userId` BEFORE the comparison check, not after, so that the initial mount with an existing token still triggers a fetch.

## AuthContext — Always Use `login()` / `logout()` Methods

For apps using a central `AuthContext` with `user`, `token`, `login()`, `logout()` (not a ChatContext), the same principle applies but the fix is simpler:

```tsx
// ❌ WRONG — AdminLogin bypassed AuthContext, ProtectedRoute saw stale null user
const handleSubmit = async (e) => {
  const { data } = await api.post('/auth/login', { email, password })
  localStorage.setItem('token', data.token)      // React state NOT updated
  localStorage.setItem('user', JSON.stringify(data.user))
  navigate('/admin/dashboard')  // AdminProtectedRoute: user still null → redirects back
}

// ✅ CORRECT — useAuth().login() updates both localStorage AND React state
const { login } = useAuth()
const handleSubmit = async (e) => {
  await login(email, password)  // sets user + token in context AND localStorage
  navigate('/admin/dashboard')  // ProtectedRoute sees user immediately
}
```

**Root cause**: `AuthContext` initializes `user`/`token` from localStorage only on mount. Direct localStorage writes don't trigger re-render of the AuthContext consumer, so ProtectedRoute components still see `null` even after storage is updated.

**Rule**: Any component that modifies auth state must go through `useAuth().login()` or `useAuth().logout()`. Never write `localStorage` directly for auth in React apps.

**Verified in**: UMAC AI project — `AdminLogin.tsx` was broken (wrote localStorage directly); fixed by using `useAuth().login()`.

## When This Skill Applies

- React Context holding per-user data (conversations, messages, settings, profile)
- Login/logout flows where SPA doesn't do a full page reload between users
- Apps with multiple accounts on same device
- WhatsApp-style chatbots with conversation lists keyed by user_id
- AuthContext-based SPAs with ProtectedRoute components
