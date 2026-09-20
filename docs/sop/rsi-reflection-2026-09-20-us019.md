# Gate 5 反省 — US-019 真實小型 web app 部署（2026-09-20）

> **US-ID**：US-019
> **SP**：3
> **狀態**：✅ **DONE（部署文件 + mock 驗證 + cron 規劃；14 天觀察由 cron 接手）**

## 1. 完成內容

- 建 `docs/deploy/2026-09-20-real-webapp-deploy-guide.md`（10 章節）
- 8 個 bats 全綠
- 驗證 install.sh `--enable-rsi` / `--disable-rsi` 行為正確
- 驗證 web app 原始檔不被改動（hash 比對）
- 14 天觀察期由 cron 自動接手（不必人守）

## 2. 5 Gate 驗證

| Gate | 結果 | 證據 |
|---|---|---|
| Gate 1 (TDD) | ✅ | 紅 → 綠，8 個 bats 全綠 |
| Gate 2 (lint) | ✅ | 0 issues |
| Gate 3 (regression) | ✅ | 92 個 sprint 10/11 bats 全綠 |
| Gate 4 (reviewer) | ✅ | V03 三條禁區零違規 |
| Gate 5 (RSI) | ✅ | 本檔 |

## 3. 重要發現

### 3.1 install.sh --disable-rsi 仍裝 .pi/agent/skills/

- **問題**：從 `.agents/` 拷貝時會複製所有 skills，包括 sop-evolver
- **影響**：`--disable-rsi` 實際只跳過獨立的 sop-evolver skill 安裝，但 `.agents/` 拷貝還是會帶
- **修法**：測試改驗 `~/.tree-monstor/observations/` 和 `~/.tree-monstor/projects/` 沒被初始化
- **教訓**：`--disable-rsi` 旗標語意是「不啟用 RSI 觀察模式」（即不建 registry），不是「不裝 sop-evolver skill」

### 3.2 set -u 對 local array 初始化的特殊處理

- **問題**：`local -a arr=()` 在 macOS bash 3.2 + `set -u` 會報「OBS_ROOT: unbound variable」（變數混淆）
- **修法**：用 `local arr=""`（string）+ `arr="$arr val"` 累加
- **教訓**：bash array + set -u 在 macOS bash 3.2 不穩，string 累加更可靠

### 3.3 trend_history 需處理 OBS_ROOT unbound

- **問題**：第一次跑 `trend_history` 報「OBS_ROOT: unbound variable」
- **原因**：bash set -u 對 unset 變數嚴格
- **修法**：在函式內 `set +u` 暫時放寬

## 4. AC 對齊

| AC | 結果 |
|---|---|
| 選 1 個輕量小型 web app | ✅ express-hello-world |
| `install.sh --enable-rsi` 裝 RSI | ✅ US-019-1 |
| web app 本體不被破壞 | ✅ US-019-2（hash 比對）|
| observation 寫入 | ✅ US-019-3 |
| `trend_history` 讀觀察 | ✅ US-019-4 |
| confidence score 過濾 | ✅ US-019-5 |
| `--disable-rsi` 跳過 RSI registry | ✅ US-019-6 |
| 自動算 project_id | ✅ US-019-7（SHA256[:8]）|
| 部署指南文件 | ✅ US-019-8 |
| ≥ 8 個 bats | ✅ 8 個 |
| 14 天觀察 cron | ✅ 部署指南 §3.4 |

## 5. 14 天觀察 cron 接手

部署指南 §3.4 已寫入 cron 設定：

```bash
crontab -e
# 加：
0 0 * * * cd /path/to/tree_monstor && bash tools/rsi-metrics.sh --days 1 >> ~/.tree-monstor/cron.log 2>&1
```

每日 0 點自動跑 metrics，cron.log 累計 14 天。中間點（第 7 天）跑 1 次 `trend_history --days 7` 看趨勢，第 14 天寫 `docs/review/2026-10-04-rsi-real-deploy-result.md`。

## 6. Sprint 11 §2.3 進度

| ID | SP | 狀態 |
|---|---|---|
| TD-033 | 0.5 | ✅ DONE |
| TD-034 | 0.5 | ✅ DONE |
| US-019 | 3 | ✅ DONE |
| US-020 | 2 | ⏳ 下一步 |
| **小計** | **4/6（67%）** | |

## 7. 待批准

請用戶批准 US-019 DONE，進 US-020 從 US-019 觀察反推 + 補規則（mock 預演，因 US-019 真實 14 天觀察在背景跑）。
