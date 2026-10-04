# Output Structure — dav-wiki

> 本檔定義 dav-wiki 的產出台帳：檔案樹狀結構與各節點用途。
> 配合 [SKILL.md](SKILL.md) 使用（SKILL.md 主檔只留導航與指針）。

---

## 1. 檔案樹

`docs/` 為**寫入目的地**（專案約定），不是讀取來源；skill 可獨立搬動。

```
docs/
  README.md
  wiki/
    _index.json
    _tags.json
    {category}/{YYYY-MM}/
      {title}.md
      assets/
        images/{n}.png
        videos/{n}.mp4
        videos/{n}.transcript.md
        audio/{n}.mp3
  concepts/
    _concepts.json
    {slug}.md
```

## 2. 各節點用途

| 節點 | 用途 |
|------|------|
| `docs/wiki/_index.json` | 交叉引用來源：`tags` / `keywords` 雙重比對（見 SKILL.md Step 5）|
| `docs/wiki/_tags.json` | tag 索引（自動提取的 tag 彙總）|
| `docs/wiki/{category}/{YYYY-MM}/` | 歸檔維度：category（用戶確認）+ 月份 |
| `.../assets/images/` | 圖片資產（OCR / 截圖）|
| `.../assets/videos/` | 影片資產（含 `{n}.transcript.md` 字幕逐字稿）|
| `.../assets/audio/` | 音訊資產（Whisper 轉錄）|
| `docs/concepts/_concepts.json` | 概念索引（`slug` → 檔案、狀態）|
| `docs/concepts/{slug}.md` | 概念本體（語意命題，可 derive / revise / merge / deprecate）|
| `docs/README.md` | 導航頁，每次寫入後重建 |
