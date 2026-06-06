# Discord Render Examples

E2E 試過嘅 render 樣板。改 wording 可以，但 layout 同 emoji 跟呢個。

## 1. 抽 1 條題 (`acp`)

```
🦞 LLM-ACP 練習 (1/1)

**題 #14** (single)
向量检索召回了 10 条切片，但部分切片与问题相关度很低，干扰了大模型答案。哪种方式能更好地过滤掉低相关度切片？

  A. 简单把生成结果截断
  B. 在大模型回答后再次让用户手动删除
  C. 结合文本重排序模型 (ReRank) 并只保留 Top N
  D. 使用高温度的模型进行生成

覆: A/B/C/D  跳過: s  揭曉: reveal
```

> ⚠️ 用 `題 {q.seq}` 直接 render，唔好自己再加 `#`。

## 2. 答啱

```
✅ 啱晒！

題 #14: 你揀咗 C
下一題?  (y / 再嚟一題 / acp stats)
```

## 3. 答錯

```
❌ 錯

題 #14: 你揀咗 A
正確: C — ReRank + Top N
```

## 4. 答錯 + 喺錯題本

```
❌ 錯

題 #14: 你揀咗 A
正確: C
💡 呢條加入咗錯題本
(注意: 答啱咗之後 backend 唔會自動 mark resolved，要清就要 docker compose down -v)
```

## 5. 多題完成 (`acp 5`)

```
🎉 5 題做完！

✅ 啱: 3/5 (60%)
❌ 錯: 2 條

#1 ✅ C
#14 ❌ A → C
#87 ✅ B
#203 ✅ D
#42 ❌ A → C

想試 (a) 全部再嚟 / (b) 淨係錯嗰 2 條 / (c) acp stats
```

## 6. `acp stats`

```
📊 LLM-ACP 統計

- 嘗試次數: 5
- 答題總數: 25
- 正確率: 68.0%
- 錯題本: 9 條
- 最近 5 次:
  - 1/5 (20%) random
  - 3/5 (60%) wrong
  - 4/5 (80%) random
  - 5/5 (100%) mock
  - 2/5 (40%) random
```

## 7. `acp help`

```
🦞 LLM-ACP Discord 練習

抽題:
  acp           抽 1 條 random
  acp 5         抽 5 條 random
  acp wrong     抽錯題本
  acp seq 42    抽第 42 題

其他:
  acp stats     睇統計
  acp help      呢個 help

答題: A / B / C / D
      多選: ABCD (唔使逗號，後端自動 sort)
控制: s 跳過 / reveal 揭曉(唔入 DB) / n 下一題
```

## 字數限制注意

Discord 限制 2000 char/msg。題目 + 4 選項正常 300-600 char 唔會爆，但有時題目會去 1000+ char。**仲未撞過 limit**，但 render 時要 watch 住：
- 題目 > 1500 char → 截斷並加 `…(題目太長已截斷)`
- 4 個 options 個別太長 → 截斷 50 char + `…`
