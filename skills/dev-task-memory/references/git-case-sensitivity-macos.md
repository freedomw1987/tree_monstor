# Git Case-Sensitivity vs macOS Case-Insensitive Filesystem

Day 11 lesson (2026-06-09): Mac HFS+/APFS 預設係 **case-insensitive but
case-preserving**,而 git 係 **case-sensitive**。同一個 directory 入面
如果有 `docs/api.md`(tracked by git)同 `docs/API.md`(new file)— **macOS
file system 將兩個視為同一個 file**,但 git 會見到兩個唔同 path。

## Symptom(實際 hit 過)

- David 嘅 Day 10 commit(`fdfc473`)tracked `docs/api.md`(lowercase)—
  個 case 對 David 嚟講 work
- Agent Day 11 patch 用 `docs/API.md`(capital)— git 見到 case diff
- `git status --porcelain` 顯示:`M  docs/api.md`(lowercase)— 即係
  agent 嘅 patch 落咗去 lowercase version(因為 macOS filesystem 將
  兩個視為同一個 file)
- `git add docs/API.md` 唔 work(個 file 喺 filesystem 唔存在獨立)— 要
  `git add docs/api.md` 先 work

## 解決 Recipe

```bash
# Step 1: 確認 git case-sensitivity
git config core.ignorecase
# macOS 預設: "true" (filesystem case-insensitive)
# Linux 預設: "false" (filesystem case-sensitive)

# Step 2: 確認 tracked file 嘅 case
git ls-files docs/ | grep -i api
# 如果返 "docs/api.md" — tracked 係 lowercase,patch 都要用 lowercase

# Step 3: Patch 用 tracked case
patch /Users/.../docs/api.md  # 唔好用 docs/API.md
```

## Prevention(Day 11 紅線)

- **紅線 37**:**Patch 任何 doc file 之前,先 `git ls-files <path>` 確認
  tracked case**,然後 patch 用 tracked case 嘅 path
- **紅線 38**:**新 project 嘅 doc file 用 lowercase-by-default**(`docs/api.md`
  而唔係 `docs/API.md`),避免 case issue
- **紅線 39**:**Push 之前必 `git ls-files docs/` 確認 冇 case-collision
  tracked + untracked**(e.g. 同時有 `docs/api.md` + `docs/API.md` tracked
  即係 bug,要手動 fix)

## 對齊其他 skills

- 冇直接對應,但對齊 6/6 David 嘅「Revert detection 鐵律」(push 之前必
  headless check)— case collision 都係需要 headless check 嘅一類

## 跟 filesystem-isolation 嘅關係

呢個 pitfall 屬於 "filesystem-quirk",類似 `~/.www symlink → ~/Sites/localhost`
(`~/www` 係 symlink,MEMORY.md 已經有)。Red lines 嘅 pattern 一致:
**永遠 confirm actual path 而唔係 assume**。
