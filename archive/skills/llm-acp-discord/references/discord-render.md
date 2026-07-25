# Discord Message 渲染範本

> 2026-06-04 第一次用 skill 喺 Discord 真實用過嘅 5 個場景。
> 全部用純 markdown text（Hermes Discord channel 唔支援 embed）。

---

## 1. 單題 cycle（`acp`）

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

**判斷後**：
```
❌ 錯
正確: D
[可選] 💡 解題思路: ...

下一題? (y/n)
```

或：
```
🎉 啱晒
[可選] 💡 解題思路: ...
```

---

## 2. 多題 cycle（`acp 3` / `acp 5`）

開頭同上，但 progress 用 `(N/total)`。

**結算**（必須等 `/finish` 嘅 `correctCount`，唔好自己 counter）：
```
📊 結果

| | 1 | 2 | 3 | 4 | 5 |
|---|---|---|---|---|---|
| 題目 | #151 | #158 | #36 | #152 | #70 |
| 你答 | B | C | B | C | B |
| 結果 | ❌ | ❌ | ❌ | ❌ | ✅ |

總分: 1/5 (20%)
```

---

## 3. 錯題本（`acp wrong`）

同 #1 一樣，但 mode 標明：
```
🦞 LLM-ACP 練習 (錯題本 1/?)

**題 #53** (single)
你在开发一个旅途规划系统...
...
```

---

## 4. Stats（`acp stats`）

```
📊 Stats

- 總 attempts: 10
- 總答題: 29
- 準確率: 51.7%
- 錯題本: 14 條

最近 attempts:
  cmpygd8wa...  random   1/5
  cmpyg5gai...  random   2/3
  cmpyg39bd...  wrong    1/1
  ...
```

---

## 5. Help（`acp help`）

```
📖 指令表

| 指令 | 嘢 |
|------|-----|
| `acp` | 抽 1 條 random |
| `acp N` | 抽 N 條 random（例：`acp 10`） |
| `acp wrong` | 抽 1 條錯題本 |
| `acp wrong N` | 抽 N 條錯題本 |
| `acp seq 42` | 抽第 42 題 |
| `acp stats` | 睇當前 stats |
| `acp help` | 顯示呢個表 |

**答題時直接覆字母：**
- `A` / `B` / `C` / `D` — 單選
- `AB` / `ABC` — 多選（唔使逗號）
- `s` / `skip` — 跳過
- `reveal` — 直接睇答案（唔計分）
```

---

## 字數限制

Discord 限制 2000 char/msg。本 skill 嘅 256 題目最長嗰條約 200 字 + 4 個選項各 ~30 字 = ~320 char。**完全安全**。

如果將來加 1KB 題目，需要 truncate 或者拆 message。

---

## 不支援嘅嘢

- ❌ Embed（Hermes Discord channel 唔 render）
- ❌ Buttons / Components（同上）
- ❌ 多過 2000 char 嘅 message（會被 Discord truncate 或者完全寄唔出）
- ❌ 多行 markdown table 超過 25 行（會 break alignment）

全部用 plain markdown text + emoji。
