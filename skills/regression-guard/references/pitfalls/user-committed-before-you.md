# ⚠️ Pitfall — User 喺你前面 commit 咗,你重做撞 hash

**場景**(2026-06-09 crm-system Day 10 doc sync):David 喺我 recon 嗰陣自己 commit 咗 `d79930e fix(ai): T1 nav label + T2/T3 chat route config + permission fix`,完全做齊 RG-002/003/004 嘅 3 個 fix。我**冇**睇 `git log origin/main..HEAD` 就 commit 我嘅 `c0d11b1 feat(ai): Day 10 AI Assistant infrastructure`,**入面包咗我重做嘅 `chat.ts` 改動** — push 之前先睇 log 發現撞。

**症狀**:`git log origin/main..HEAD` 出現 David 個 `d79930e`,而我嘅 `c0d11b1` 改 `apps/api/src/routes/chat.ts` 同 David 改嘅**完全一樣**。冇 `git diff d79930e..HEAD -- apps/api/src/routes/chat.ts` 報 conflict(因為 git 3-way merge 接受兩個 identical change),push 咗上去 remote 就有 duplicate commit。

**修正流程**:
```bash
# 1. Push 之前必跑
git log --oneline origin/main..HEAD

# 2. 如果撞 David 個 commit,soft-reset + unstage 衝突 file + reset 個 file 返 David 版本
git reset --soft HEAD~1                    # 取消我自己個 commit,file 留喺 staged
git reset HEAD <conflicted-file>          # unstage 個 file
git checkout <david-commit-sha> -- <file> # working tree 換返 David 版本
# 3. Commit 返只 stage 咗嘅、真正新嘅 file,commit message 引用 David hash:
git commit -m "feat(ai): Day 10 infrastructure

Note: chat.ts fix was already shipped by David in d79930e (RG-002/003 +
T2/T3 spec). This commit re-uses that version via git checkout to
avoid duplicate work on origin.

Refs: d79930e"
```

**預防 checklist**(任何 long session commit 之前必跑):
- [ ] `git log --oneline origin/main..HEAD` — 睇有冇 David 親做嘅 commit 我冇 follow 到
- [ ] `git diff <david-commit>..HEAD -- <file>` 逐個 file 比較,確認冇 identical change
- [ ] 如果撞,**soft reset + checkout David 版本 + reference** — 唔好 duplicate
- [ ] 跟住先 commit 真正新嘅 work
