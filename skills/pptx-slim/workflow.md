# PPTX Slim — 流程細節（7 步）

> 本檔為 `pptx-slim` skill 的子檔，逐Step 寫「動作 / 為什麼 / 產出 / 證據」。入口在同套 `SKILL.md`。

## 1 偵察

- 動作：跑 `scripts/pptx-probe.py`：列 media 佔比、非媒體體積、每支影片的解析度／時長／bitrate
- 為什麼：先知道體積來源同「最貴的幾支」，否則盲壓
- 產出：偵察表（分類彙總 + Top 20）
- 證據：probe 原始輸出

## 2 定 profile

- 動作：給 2–3 個選項（如 1080p CRF24／720p CRF28／只壓 Top 3）＋標明推薦
- 為什麼：畫質與體積是取捨，必須用戶決定
- 產出：選定 profile
- 證據：對話一句「用 profile X」

## 3 轉碼

- 動作：跑 `scripts/pptx-shrink-media.py`（同容器、同檔名、壓完更大自動保留原檔）
- 為什麼：媒體就是 90%+ 體積來源
- 產出：`encoded/` 目錄 + encode log
- 證據：每支 before→after 大小表

## 4 重打包

- 動作：跑 `scripts/pptx-repack.py`：開新檔、只換 media entry、其他 entry 逐 byte 複製
- 為什麼：XML／rels 動一下就會散動畫與時序
- 產出：新 .pptx
- 證據：`N/N entries written, M replaced`

## 5 驗證

- 動作：跑 `scripts/pptx-verify.py`：CRC｜entry 齊全 + 非媒體 byte 相同｜rels 零斷鏈｜時長漂移
- 為什麼：靜默壞檔比大檔更貴：開會才發現就太遲
- 產出：驗證報告（四關全綠）
- 證據：verify 輸出 + 播放器實開結果

## 6 交件

- 動作：命名 `<原名>_<profile>.pptx`；用完對比原檔 md5
- 為什麼：原檔可回溯，出錯可零成本重來
- 產出：最終檔
- 證據：`ls -l` 前後對照

## 7 加碼（可選）

- 動作：影片壓完仍不夠小時：跑 `scripts/pptx-shrink-images.py`（無損優先）或對影片用 `--only` 精準打擊
- 為什麼：圖片常是「第二大來源」（實測 139 MiB 含 29 MiB TIFF）
- 產出：`image-log.tsv` + 更新的對照表
- 證據：同上四關重跑，並加 `--media-dir` 交叉核對與 `--image-mode` 畫質關
