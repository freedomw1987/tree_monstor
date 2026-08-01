# Form Auto-Prefill Race Fix (`userTouched` Flag)

When prefilling a form field from a network call, you risk clobbering a value the user typed before the response returned. The fix is a `userTouched` flag that disables the prefill effect after the user has interacted with the field.

## The bug

```tsx
// ❌ User types "5" before the fetch returns; effect clobbers it with the system default "3"
const [taxRate, setTaxRate] = useState(0);

useEffect(() => {
  fetch('/api/settings/tax').then(r => r.json()).then(data => {
    setTaxRate(data.rate);
  });
}, []);
```

The user's intentional value is lost.

## The fix: user-touched flag

```tsx
const [taxRate, setTaxRate] = useState(0);
const [userTouchedTax, setUserTouchedTax] = useState(false);

useEffect(() => {
  if (userTouchedTax) return; // pre-await check
  let alive = true;
  settingsApi.getTax()
    .then(data => {
      if (!alive) return;
      if (userTouchedTax) return; // post-await re-check
      const n = Number(data.rate);
      if (Number.isFinite(n) && n !== taxRate) setTaxRate(n);
    })
    .catch(() => {
      // Non-fatal: let the user type a value manually
    });
  return () => { alive = false; };
  // eslint-disable-next-line react-hooks/exhaustive-deps
}, [userTouchedTax]);

// In the input:
<input
  value={taxRate}
  onChange={(e) => {
    setUserTouchedTax(true);
    setTaxRate(Number(e.target.value) || 0);
  }}
/>
```

## Why both checks (pre-await + post-await)

1. **Pre-await check** (`if (userTouchedTax) return`): If the user has already touched the field by the time the effect runs, don't even start the fetch.
2. **Post-await re-check** (inside `.then`): The user might have typed *during* the network roundtrip. The flag at .then-time reflects the current state, not the state when the effect started.

The `alive` flag handles the unmount-during-fetch case (React strict mode, route change, etc.).

## When to apply

- Default tax rate from system settings → prefill
- Default language/locale from user profile → prefill
- Default project/workspace from URL query string → prefill
- Any "smart default" that comes from a network call

## When NOT to apply

- Hardcoded defaults (e.g. `useState(0)`) — no network, no race
- Edit mode where the value comes from `existing.foo` in the same render — no race
- Fields the user shouldn't be able to override (just hardcode the value, don't prefill)

## Edit-mode skip

If the field is for an existing record, the prefill is unnecessary because the value is already in `existing` prop. Add a guard:

```tsx
useEffect(() => {
  if (existing) return; // edit mode: existing.taxRate is already in state
  // ... prefill logic
}, [existing, userTouchedTax]);
```

## Alternative: use react-query

`useQuery({ enabled: !userTouchedTax })` is another way, but you still need a `useState` for the flag, and the extra abstraction may not be worth it for a single field. The plain `useState` pattern above is fine for one field. If you have 3+ prefilled fields, consider whether the same pattern can be extracted into a small `useAutoPrefill(fieldName, fetcher)` hook.

## See also

- crm-system Day 14.7 Step 9 (commit 9bc8695) — QuotationBuilder tax prefill with this pattern
- Day 14.7 crm-system Step 7 (commit bd1d107) — `settingsApi.getTax/putTax` wire shape (the network call this prefill uses)
