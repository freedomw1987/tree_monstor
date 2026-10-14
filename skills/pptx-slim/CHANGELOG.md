# Pptx Slim — CHANGELOG

> 本檔為 pptx-slim 的完整變動歷史。引用：`SKILL.md` 變動歷史章節
>
> 主檔只保留最近幾條以節省 LLM 注意力；細節與實測數字在 `examples.md`。

| 版本 | 日期 | 變動 | 為什麼 |
|------|------|------|--------|
| v1.1 | 2026-10-05 | V03 二審**兩輪**（dev-checker-loop Reviewer）修正。Round-1（P0 0／P1 1／P2 6／P3 9）：① 媒體判定改用共用 `is_media()`（換掉的**圖片**不再被 G2b 誤報「非媒體被動過」）② `--media-dir` 空目錄／錯路徑不再空過③ `--only` 精確優先（不會 `media1` 連 media10–17）④ repack 預設不覆蓋已存在的 `--dst`（`--force` 才可）⑤ G2 改分塊串流比對、G4 一次性開 zip（2.9 GB 級不再爆記憶體）⑥ 四關措辭對齊腳本 G1–G4。Round-2（P0 0／P1 0／P2 2／P3 11）：⑦ `SKILL.md` Step 7「三關」→「四關」⑧ 打錯的 `--only` 詞不再靜默丟掉（印 WARN 說沒命中）⑨ `--list` 不再建空的 `--out` 目錄（先看不跑＝零副作用）⑩ G4 在輸出檔缺 entry 時**自行判 FAIL**，不再抛 `KeyError` traceback；`human_bytes()` 標籤改 KiB／MiB／GiB（分母 1024）。`tests/pptx-slim.bats` 功能探針 6 → **11** 支；`tests/ffmpeg-version.bats` 7 → **8** 支（FV-8 單獨咬住第二組能力實測）| Reviewer 抓到 1 個 P1（換圖片假紅）與 8 個 P2（空過假綠／記憶體／旗標鎖／第二組無探針咬住），全部已修並補回歸護欄；突變驗證共 12 支（pptx-slim）＋3 支（ffmpeg 能力實測）全紅 |
| v1.0 | 2026-10-05 | 初版。從「2.9 GB 培訓 PPT → 418 MB」實戰流程提煉：4 支工具（`pptx-probe.py` 偵察與估數／`pptx-shrink-media.py` 影片轉碼含「壓完更大就保留原檔」／`pptx-repack.py` 只換媒體重打包／`pptx-verify.py` 四關驗證）+ 共用模組 `pptx_common.py`；紀律：原檔零改動、檔名與容器不變、非媒體 entry 逐 byte 原樣、缺任一驗證關即不得交件；`tests/pptx-slim.bats` 6 支功能探針（含 2 支 mutant 種壞，證明驗證器咬得住）| 這套能力高度機械又易錯（zip 重打包／ffmpeg 參數／驗證順序），每次重寫的成本與風險都高；提煉成 skill 後可重用、可回歸 |

建立過程中由探針與沙盒實測抓到並修正的三點：

1. `pptx-repack.py` 只在「媒體真的被換掉」時才用 ZIP_STORED；保留原檔時沿用原壓縮方式，
   否則「全部媒體都保留原檔」的輸出反而會比原檔大。由 `tests/pptx-slim.bats` PPTX-SLIM-3 抓到。
2. 只把**影片**視為必要項：媒體目錄裡沒有圖片時不再誤報 WARN（圖片是獨立可選的加碼項）。
3. `--crf 0`（無損）不再硬塞 `-profile:v high`：libx264 無損會走 High 4:4:4 Predictive，硬塞會直接轉碼失敗。
