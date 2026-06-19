# Pagination Smoke Test Template

Drop-in Python script for verifying the **pagination invariant** on any backend endpoint. Write to `/tmp/<feature>_pagination_smoke.py` (NOT in the project repo), run after the backend rebuild, then optionally `rm` it.

## What it asserts

The core invariant of this pattern: **totalCount + totalHours must be IDENTICAL across page 1, page 2, group-by mode, and Excel export**, because all four read from the same server-side aggregate, not from paged `findMany`.

If any assertion fails, the design is broken and stats cards / Excel totals will be wrong.

## Template

```python
"""Smoke test for /api/<feature> pagination + total count + Excel export.

Usage:
  1. Adjust LOGIN_EMAIL / LOGIN_PASSWORD to a valid user
  2. Adjust BASE_URL (default: http://localhost:4001)
  3. Adjust SEED_SQL or remove the seed block
  4. python3 /tmp/<feature>_pagination_smoke.py
"""
import urllib.request, json, sys

BASE = "http://localhost:4001"
LOGIN_EMAIL = "admin@test.com"
LOGIN_PASSWORD = "admin123"

def req(path, method="GET", body=None, token=None):
    url = f"{BASE}{path}"
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")

# 1. Login
code, body = req("/auth/login", "POST", {"email": LOGIN_EMAIL, "password": LOGIN_PASSWORD})
assert code == 200, f"login failed: {code} {body}"
token = body["accessToken"]
print(f"login OK (token len={len(token)})")

# === THE INVARIANT: totalCount + totalHours must be IDENTICAL across all modes ===

# 2. Page 1 with small pageSize
code, p1 = req("/api/<feature>?page=1&pageSize=5", token=token)
print(f"page=1 pageSize=5: code={code} rows={len(p1.get('rows', p1.get('<plural>', [])))} "
      f"totalCount={p1.get('totalCount')} totalHours={p1.get('totalHours')} "
      f"page={p1.get('page')} totalPages={p1.get('totalPages')}")
assert code == 200
assert p1["totalCount"] > 0, "no rows in DB; seed first or adjust test"
assert p1["totalPages"] >= 1
rows1 = [r["id"] for r in p1.get("rows", p1.get("<plural>", []))]
assert len(rows1) <= 5

# 3. Page 2 — verify disjoint + identical totals
if p1["totalPages"] >= 2:
    code, p2 = req("/api/<feature>?page=2&pageSize=5", token=token)
    rows2 = [r["id"] for r in p2.get("rows", p2.get("<plural>", []))]
    assert p1["totalCount"] == p2["totalCount"], "totalCount inconsistent"
    assert p1["totalHours"] == p2["totalHours"], "totalHours inconsistent"
    assert p1["totalPages"] == p2["totalPages"], "totalPages inconsistent"
    assert set(rows1) & set(rows2) == set(), "page overlap!"
    print("OK: page 1 + page 2 are disjoint, totals consistent")
else:
    print(f"only 1 page; skipping page 2 disjoint check")

# 4. limit=-1 (Excel export) — returns the full set
code, all_rows = req("/api/<feature>?limit=-1", token=token)
all_data = all_rows.get("rows", all_rows.get("<plural>", []))
assert code == 200
assert len(all_data) == all_rows["totalCount"], \
    f"limit=-1 must return all rows: got {len(all_data)} vs total {all_rows['totalCount']}"
assert all_rows["totalCount"] == p1["totalCount"], "limit=-1 total disagrees with paged total"
assert all_rows["totalHours"] == p1["totalHours"], "limit=-1 sum disagrees with paged sum"
print(f"OK: limit=-1 returns {len(all_data)} rows (matches totalCount)")

# 5. Explicit limit (smaller than default)
code, small = req("/api/<feature>?limit=3", token=token)
small_data = small.get("rows", small.get("<plural>", []))
assert code == 200
assert len(small_data) == min(3, small["totalCount"])
print(f"OK: limit=3 returns {len(small_data)} rows")

# 6. limit=-1 metadata is well-formed
assert all_rows["page"] == 1
assert all_rows["pageSize"] == all_rows["totalCount"]
assert all_rows["totalPages"] == 1
print("OK: limit=-1 metadata correct")

# 7. groupBy mode is UNAFFECTED by pagination
code, g = req("/api/<feature>?groupBy=day", token=token)
assert code == 200
assert "groupedData" in g or "groups" in g
print(f"OK: groupBy mode unchanged (sum = {g.get('grandTotal', g.get('sum'))})")

# 8. Default pageSize is what backend documents (usually 50)
code, default = req("/api/<feature>", token=token)
default_data = default.get("rows", default.get("<plural>", []))
assert code == 200
assert len(default_data) == min(50, default["totalCount"]), \
    f"default pageSize should be 50, got {len(default_data)}"
print(f"OK: default pageSize = 50")

# 9. All metadata keys present
for k in ("totalCount", "totalHours", "page", "pageSize", "totalPages"):
    assert k in default, f"missing key {k} in response"
print("OK: all pagination metadata keys present")

# 10. Out-of-range page returns empty + correct total
code, oob = req("/api/<feature>?page=999&pageSize=50", token=token)
assert code == 200
oob_data = oob.get("rows", oob.get("<plural>", []))
assert len(oob_data) == 0
assert oob["totalCount"] == default["totalCount"]
print("OK: out-of-range page returns empty + correct total")

# 11. === THE CRITICAL INVARIANT ===
# Across all four modes (paged, all-rows, groupBy, default), the totals match.
assert p1["totalCount"] == all_rows["totalCount"] == default["totalCount"]
assert p1["totalHours"] == all_rows["totalHours"] == default["totalHours"]
# If groupBy is supported, its sum should also match.
if "grandTotal" in g:
    assert abs(g["grandTotal"] - p1["totalHours"]) < 0.01, "groupBy sum diverges from list sum"
print("OK: TOTALS CONSISTENT across paged / all / groupBy / default")

print("\n=== ALL SMOKE TESTS PASSED ===")
```

## Seeding test data (if DB is empty)

Some projects' dev DBs ship empty. To seed without polluting:

```bash
# 1. Seed via docker compose exec + psql
docker compose exec db psql -U <user> -d <db> <<SQL
INSERT INTO <table> (id, ..., created_at)
SELECT
  'test-<feature>-' || lpad(i::text, 4, '0'),
  ...,
  NOW() - ((i * 3) || ' hours')::interval,
  NOW()
FROM generate_series(1, 137) AS i;
SQL

# 2. Run the smoke test
python3 /tmp/<feature>_pagination_smoke.py

# 3. Rollback the seed
docker compose exec db psql -U <user> -d <db> \
  -c "DELETE FROM <table> WHERE id LIKE 'test-<feature>-%';"
```

For the seed, distribute rows across users (e.g. `OFFSET (i % user_count)`) so the data isn't all owned by one user — that catches RBAC bugs too.

## When to add new assertions

If the project adds new dimensions to the page (search, sort, multi-select filters), add an assertion per dimension:

- **Search**: filter with `?q=foo` → assert `totalCount` shrinks to non-zero
- **Sort**: `?sortBy=hours&sortDir=asc` → assert first row's `hours` is min
- **Date range**: `?startDate=...&endDate=...` → assert `totalCount` filters correctly
- **User/team filter**: assert RBAC: a Developer should NOT see other users' rows

## Common failure modes the smoke test catches

| Failure mode | Symptom in test | Root cause |
|--------------|-----------------|------------|
| `findMany` only, no `aggregate` | `totalCount` from page 1 ≠ page 2 | Backend forgot the aggregate call |
| Aggregate uses different `where` | `totalCount` from list ≠ groupBy | Filter clauses drifted between two queries |
| Excel reads from paged state | (frontend, not testable here) | Frontend bug — not in this smoke test |
| `totalCount` includes soft-deleted rows | `totalCount > actual visible count` | Missing `where: { deletedAt: null }` in one query |
| Out-of-range page returns 404 | `oob` test throws | Backend should 200 with empty array, not 404 |
| Default pageSize is 1000 | `len(default_data) == 1000` | Backend defaults don't match documentation |
