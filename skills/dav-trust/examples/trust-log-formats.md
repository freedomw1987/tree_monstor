# dav-trust 樣例檔 — Trust Log 檔頭 / 檢查點格式

> 配合 [`../SKILL.md`](../SKILL.md) 同 [`../resume.md`](../resume.md) 使用：呢度只放**可直接複製嘅範本**，
> 規則（欄位意義 / 更新時機 / 寫入位置）→ 同套本 skill 子檔（`../resume.md` §2）。

---

## 1. trust-log 檔頭範本（trust 啟動時寫一次，缺一不可續跑）

```markdown
# Trust Log — <專案名稱>

> 啟動時間:   2026-10-23 14:23:07 +0800
> Deadline:   2026-10-23 16:23:07 +0800
> 大目標:     <一句話可驗收的大目標>
> 時間錨點:   START_TS=2026-10-23 14:23:07 +0800、DEADLINE_TS=2026-10-23 16:23:07 +0800
> 進度錨點:   PHASE=執行、DONE=US-101,US-102、NEXT=US-103、UPDATED_AT=2026-10-23 15:02:11 +0800
```

## 2. 進度錨點更新範本（每完成一個 US / 階段切換）

```markdown
> 進度錨點:   PHASE=執行、DONE=US-101,US-102,US-103、NEXT=US-104、UPDATED_AT=2026-10-23 15:31:02 +0800
```

## 3. 暫停狀態錨點範本（用戶叫停「暫停」時）

```markdown
> 進度錨點:   PHASE=暫停、DONE=US-101,US-102,US-103,US-104、NEXT=US-105、UPDATED_AT=2026-10-23 15:58:40 +0800
```
