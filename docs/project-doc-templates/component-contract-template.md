# Per-Component Contract — `docs/components/<Name>.md`

> **When to use:** DESIGN 階段，每個 component 一個檔。
> **No-code rule：** 嚴格。Contract 只列 props / events / a11y / states，**不寫 source 語言 example**。

## 必填區塊

```markdown
# Component: Button

**對應 US**: US-001, US-007
**對應實作**: `src/components/Button.tsx`（僅 reference，不放 code snippet）

## Purpose
Primary action affordance for forms、dialogs、navigation CTAs.

## Props
| Prop | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| variant | `primary` \| `secondary` \| `ghost` | no | `primary` | Visual variant |
| size | `sm` \| `md` \| `lg` | no | `md` | Size token |
| label | string | yes | — | Button text |
| onClick | `() => void` | yes | — | Click handler |
| disabled | boolean | no | `false` | Disabled state |
| loading | boolean | no | `false` | Loading spinner replaces label |
| iconLeft | string \| null | no | `null` | Icon name (per icon registry) |
| type | `button` \| `submit` \| `reset` | no | `button` | HTML button type |

## Events
- `click` → calls `onClick`
- Keyboard: `Enter` / `Space` triggers click

## States
default / hover / active / disabled / loading

## Accessibility
- Min hit-area: 44×44px
- `role="button"`
- `aria-disabled` when `disabled` 或 `loading`
- Visible focus ring per `--focus-ring` token
- Loading state: `aria-busy="true"`, label remains for screen readers

## Token usage
- background → `--color-primary`（或 `secondary`/`ghost` 對應變體）
- text → `--color-on-primary`
- padding → `--space-2` `--space-3`
- radius → `--shape-small` (4px)
- elevation → `--elevation-1` (default), `--elevation-2` (hover)

## Do's and Don'ts
- ✅ Do: 文字按鈕至少 44x44px
- ❌ Don't: 嵌套 button（a11y 違規）

## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
```

## 規則
- Type 欄只列型別（不寫實作 code）
- 不用 `<Button onClick={...}>OK</Button>` 之類 example
- 改 component → 加 changelog；如影響 a11y / token → 同步 DESIGN.md master