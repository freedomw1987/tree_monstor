---
name: mutation-testing
description: |
  用 mutation testing 驗證 unit test 嘅 quality — 不只「覆蓋率」,還「有效」。
  工具:Stryker (TypeScript / JS) / mutmut (Python) / PIT (Java)。
  觸發情境:P0 US 嘅 unit test 已 100% coverage 但仍懷疑 test quality;每季度一次 mutation score review。
  Pair with regression-guard + unit-test-coverage-push。
trigger: |
  「mutation testing」「mutation score」「test 雖然 100% 但好似冇效」「Stryker」「mutmut」
  或任何 P0 US 季度 audit、coverage 達標但 release 出 bug 嘅事後檢討
applicability: generic-pattern
---

Last-verified: 2026-07-28
# Mutation Testing — 驗證 Test 嘅 Quality

> **為何需要這個 skill** — 100% line coverage 唔等於 test 有效。一個 test `expect(true).toBe(true)` 行覆蓋率 100%,但殺唔到任何 bug。**Mutation testing** 故意改 source code 嘅小部分(mutant),如果所有 test 仲過 = 個 test 寫得冇意義。
>
> **對應 `docs/testing-strategy-tiered.md`**:T3 Mature 嘅「應測層」之一,P0 US 季度跑一次。

---

## When to load

- P0 US 嘅 unit test 已達 ≥ 90% line coverage,但 release 後仲出 bug
- Quarter-end 嘅 test quality audit
- 從零開始寫 critical algorithm 嘅 test(pricing engine / RBAC / auth)
- 接手 legacy code 嘅 unit test,想知邊個 test 寫得冇 quality

## When NOT to load

- P1/P2/P3 US(over-engineering)— 用 line coverage 就夠
- E2E / integration test(mutation testing 主要用喺 unit layer)
- Production code(只係用嚟 audit test quality,唔係 production 工具)
- 開發 hotfix 期間(慢,sprint 後先跑)

---

## 🎯 核心概念

### Mutation operators(常見類型)

| Operator | 例子(source → mutant) | 殺到 = test 有效 |
|----------|----------------------|-------------------|
| **Arithmetic** | `+` → `-` | `expect(sum).toBe(10)` 真係 check 加法 |
| **Conditional** | `>` → `>=`、`===` → `!==` | `expect(result).toBeGreaterThan(5)` 真係 check boundary |
| **Negation** | `&&` → `\|\|` | `expect(canEdit && isOwner).toBe(true)` 真係兩者都 check |
| **Constant** | `0` → `1`、`""` → `"foo"` | `expect(count).toBe(0)` 真係 check empty |
| **Return value** | `return x` → `return null` | Test 真係 verify function output |

### Mutation score

```
mutation_score = (killed_mutants / total_mutants) * 100%
```

| 指標 | 健康 | 警告 | 不健康 |
|------|------|------|--------|
| Mutation score(P0 US) | ≥ 80% | 60-79% | < 60%(test 形式主義) |
| Mutation score(P1 US) | ≥ 60% | 40-59% | < 40% |
| Mutants 總數 / source LOC | 0.5-2 | < 0.3 或 > 5 | 太少 = source 太簡單 / 太多 = source 太複雜 |

---

## 🛠 工具選擇

| Stack | 工具 | 安裝 |
|-------|------|------|
| TypeScript / JS | **Stryker**(`@stryker-mutator/*`) | `npm i -D @stryker-mutator/core @stryker-mutator/typescript-checker @stryker-mutator/vitest-runner` |
| Python | **mutmut** | `pip install mutmut` |
| Java | **PIT**(pitest.org) | Maven/Gradle plugin |
| Go | **go-mutesting** | `go install github.com/avito-tech/go-mutesting/...` |

---

## 🔄 Stryker SOP(TypeScript)

### Setup(單次)

```bash
npm i -D @stryker-mutator/core
npx stryker init  # 自動生成 stryker.config.json
```

```json
// stryker.config.json
{
  "$schema": "node_modules/@stryker-mutator/core/schema/stryker-schema.json",
  "packageManager": "npm",
  "reporters": ["html", "json", "progress"],
  "testRunner": "vitest",
  "coverageAnalysis": "perTest",
  "mutate": [
    "src/**/*.ts",
    "!src/**/*.test.ts",
    "!src/**/*.spec.ts",
    "!src/**/*.d.ts",
    "!src/migrations/**",
    "!src/types/**"
  ],
  "thresholds": {
    "high": 80,
    "low": 60,
    "break": 50
  },
  "vitest": { "configFile": "vitest.config.ts" }
}
```

### 跑(per P0 US 或全 codebase)

```bash
# 全 codebase(慢,幾小時)
npx stryker run

# 只跑某 P0 US 嘅 module
npx stryker run --mutate 'src/payment/**'

# CI 模式(fail if threshold 唔達標)
npx stryker run --check
```

### 解讀 HTML report

`reports/mutation/mutation.html` 顯示每行 source code 嘅 mutation 結果:

- 🟢 Killed = mutant 被 test 殺到(✅ test 有效)
- 🔴 Survived = mutant 生存(❌ 該行 test 冇 check)
- ⏸️ Timeout / No coverage = 該行無 test

**行動**:
- Survived 嘅行 → 加 assertion 或新 test
- 重複 run → mutation score 升 ≥ 80% = 健康

---

## 🔧 修復 Survived Mutants

### Pattern 1:Conditional 改 `>` → `>=`

```typescript
// Source
function isAdult(age: number): boolean {
  return age > 18;
}

// Mutant:return age >= 18
// Survived 代表 test 只有 age=19 過,age=18 唔過

// 修法:加 boundary test
it('returns false at age 18', () => {
  expect(isAdult(18)).toBe(false);
});
it('returns true at age 19', () => {
  expect(isAdult(19)).toBe(true);
});
```

### Pattern 2:Negation 改 `&&` → `||`

```typescript
// Source
if (isAdmin && hasPermission('delete')) { ... }

// Survived = test 只 check isAdmin=true,hasPermission=false 嘅時候

// 修法:加 negation test
it('blocks when only one condition true', () => {
  expect(canDelete(false, true)).toBe(false);
  expect(canDelete(true, false)).toBe(false);
});
```

### Pattern 3:String 改 `""` → `"foo"`

```typescript
// Source
if (name === '') throw new Error('empty');

// Survived = test 只 pass name='Alice',唔 pass name=''

// 修法:加 empty case
it('throws on empty name', () => {
  expect(() => validateName('')).toThrow('empty');
});
```

### Pattern 4:Return value 改 `null` / `undefined`

```typescript
// Source
function findUser(id: string): User | null {
  return users.get(id) ?? null;
}

// Survived = test 只 check user found case,唔 check user not found

// 修法:加 null case
it('returns null for missing user', () => {
  expect(findUser('nonexistent')).toBeNull();
});
```

---

## 🚨 Common Pitfalls

### Pitfall 1:Equivalent mutants(等價突變)

有啲 mutant 邏輯上等價,殺唔到係正常嘅,**唔好無限 chase**:

```typescript
// Source:return a + b
// Mutant:return a + b + 0  // 等價,殺唔到正常

// Source:return x !== null
// Mutant:return !(x === null)  // 等價
```

**判斷**:Mutant 嘅行為真係唔變 → 標 `equivalent`,從 score 排除。Stryker 有 `mutator.excludedMutations` 可以禁特定 operator。

### Pitfall 2:Mutation 慢 — 只跑 P0

```bash
# ❌ 一次跑全 codebase(8 小時)
npx stryker run

# ✅ 只跑 P0 US module
npx stryker run --mutate 'src/payment/**,src/auth/**,src/rbac/**'
```

**預估時間**:`mutants × avg_test_time × modules`。Vitest + per-test coverage 通常 100 mutants = 5-15 分鐘。

### Pitfall 3:Boundary value 唔 test

```typescript
// 99% 嘅 survived mutant 都係 boundary condition 唔 test:
// - off-by-one (> vs >=)
// - empty / null check
// - default value
// 寫 test 嘅時候永遠問:「boundary 喺邊?」
```

---

## 📊 Reporting & Quarterly Review

`docs/qa-tracker.md` 嘅 changelog 加 mutation score 紀錄:

```markdown
## Changelog
| 日期 | 變更 | 原因 |
|------|------|------|
| 2026-07-28 | Mutation score(P0): 82%(↑ 7% vs 2026-Q2) | Quarterly audit: 補 boundary test × 12 |
| 2026-04-15 | Mutation score(P0): 75% | Quarterly audit: 修 8 個 Survived mutant |
```

CI 整合(進階):
```yaml
# .github/workflows/mutation-test.yml
name: Mutation Test (quarterly)
on:
  schedule:
    - cron: '0 3 1 */3 *'  # 每季第一日 03:00
  workflow_dispatch:

jobs:
  mutation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npx stryker run --check
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: mutation-report
          path: reports/mutation/
```

---

## 🆚 同其他測試嘅關係

| 測試 | 衡量 | 限制 |
|------|------|------|
| **Line coverage** | 邊行 code 跑過 | 跑過唔等於 check 過 |
| **Branch coverage** | 邊個 if/else branch 跑過 | 同上 |
| **Mutation score** | test 寫得幾嚴 | 慢、有 equivalent mutant noise |
| **Code review** | test 寫得啱唔啱 | 主觀、scale 唔到 |

**結論**:三者互補。Mutation testing 唔係取代 coverage,**係 coverage 嘅 meta-test**。

---

## 🎬 David 嘅實戰情境

情境:某 P0 US-007 嘅 payment 模組有 100% line coverage,但 production 出咗 bug — `discount` 欄位 null 嘅時候 crash。

**正確流程**(用本 skill):
1. **跑 Stryker**:`npx stryker run --mutate 'src/payment/discount.ts'`
2. **發現 Survived mutants**:
   - `if (discount === null)` → mutant `if (discount !== null)` Survived
   - 代表 test **只 check discount 有值嘅 case**,null case 冇 test
3. **加 null case test**:
   ```typescript
   it('throws on null discount', () => {
     expect(() => applyDiscount(100, null)).toThrow();
   });
   ```
4. **重跑**:mutation score 73% → 89%,null mutant 變 Killed
5. **結果**:production bug 預先 catch 到

**錯誤流程**:
- 「Coverage 100% 啦,放心」→ 漏 bug
- 「加咗 test 啦」→ 但加嘅 test 仲係 placeholder,score 升唔到
- 「Mutation testing 太慢唔做」→ 同 type system 缺失一樣嘅風險

---

## Related docs

- [Testing strategy](../../../docs/testing-strategy.md)
- [Testing strategy tiered](../../../docs/testing-strategy-tiered.md)
- [Regression guard skill](../../regression-guard/SKILL.md)
- [Unit test coverage push skill](../unit-test-coverage-push/SKILL.md)
- [QA tracker](../../../docs/qa-tracker.md)