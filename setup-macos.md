# Tree Monstor — macOS + Hermes 0.15.1 啟動指南

> **適用版本**:Hermes Agent v0.15.1+ (macOS)
> **Profile 路徑**:`~/.hermes/profiles/developer/`

---

## 快速啟動(3 步)

```bash
# 1. 編輯 .env,把 DISCORD_BOT_TOKEN / OPENROUTER_API_KEY 填進去
nano ~/.hermes/profiles/developer/.env

# 2. (選用但推薦) 對 default profile 做備份,以防改動出包
cp ~/.hermes/config.yaml ~/.hermes/config.yaml.backup-before-developer
cp ~/.hermes/.env ~/.hermes/.env.backup-before-developer

# 3. 啟動 developer profile
~/.hermes/profiles/developer/LAUNCH.sh
```

`LAUNCH.sh` 內部執行 `hermes --profile developer` — Hermes 會:
1. 把 `HERMES_HOME` 切到 `~/.hermes/profiles/developer/`
2. 自動讀 `config.yaml` 跟 `.env`
3. **自動載入 `SOUL.md` 到 system prompt(這就是 Tree Monstor 的身份)**
4. 開 Discord gateway 連線

啟動成功後,在 Discord 用 `/status` 應該會看到:
```
Profile: developer
Model: MiniMax-M3
```

---

## 啟動前確認事項

### ✅ 必做

| # | 項目 | 怎麼檢查 |
|---|------|---------|
| 1 | `.env` 已填好 | `cat ~/.hermes/profiles/developer/.env \| grep -E "BOT_TOKEN\|API_KEY" \| grep -v "your_"` 應有非空值 |
| 2 | SOUL.md 存在 | `ls -la ~/.hermes/profiles/developer/SOUL.md` 應有 ~13k bytes |
| 3 | config.yaml 存在 | `ls -la ~/.hermes/profiles/developer/config.yaml` |
| 4 | 預設 Discord channel 已設 | 跟 default 走一樣的 `DISCORD_HOME_CHANNEL` |

### ⚠️ 容易踩的坑

**1. 不要在 default profile 還在跑的時候啟動 developer**

兩個 gateway 用**不同的 bot token** 沒問題(它們是不同 bot),但用**同一個 token** 會互踢。請確認:
- 這個 profile 的 `.env` 裡的 `DISCORD_BOT_TOKEN` ≠ `~/.hermes/.env` 裡的 token
- 兩個 token 對應到**不同的 Discord Application**

**2. SOUL.md 跟 Hermes 內建身份的覆蓋**

Hermes 0.15.1 有內建的 `DEFAULT_AGENT_IDENTITY`(您 `~/.hermes/SOUL.md` 那份)。Tree Monstor 的 SOUL.md 透過 `load_soul_md()` 自動覆蓋它。**第一次啟動後**,您可以打 `/personality developer` 切到 developer 身份。

**3. Skill 載入來源**

`hermes --profile developer` 啟動時,Hermes 會從 `~/.hermes/profiles/developer/skills/` 找 skill。Tree Monstor 的 local skills catalog 見 `skills/README.md`；每個 skill 的 canonical source 是 `skills/<name>/SKILL.md`，**直接可用**,不用額外安裝。

**4. Sessions 跟 logs 分離**

每個 profile 有獨立的:
- `~/.hermes/profiles/developer/sessions/` — 對話紀錄
- `~/.hermes/profiles/developer/state.db` — SQLite
- `~/.hermes/profiles/developer/logs/` — agent.log / errors.log / gateway.log

跟 default 完全隔離 ✅

---

## 背景服務化(選用,launchd)

macOS 用 **launchd**,不是 Linux 的 systemd。Hermes 0.15.1 內建 `hermes gateway install` 幫您處理:

```bash
# 安裝 launchd service(背景跑,登入後自動啟動)
hermes --profile developer gateway install

# 啟動
hermes --profile developer gateway start

# 停止
hermes --profile developer gateway stop

# 狀態
hermes --profile developer gateway status
```

`hermes gateway install` 內部會呼叫 `hermes_cli.gateway.get_launchd_plist_path` 產生正確的 `~/Library/LaunchAgents/...plist` 檔。

---

## 切回 default profile

```bash
# 切回 default(寫回 active_profile 檔)
hermes profile use default

# 或啟動時明確指定
hermes --profile default
```

---

## 故障排除

| 症狀 | 原因 | 解法 |
|------|------|------|
| 啟動後 Discord bot 沒反應 | `.env` 沒填 token | `nano .env` 填好後重啟 |
| `/status` 顯示 `Profile: default` 而不是 `developer` | `HERMES_HOME` 環境變數沒設到 | 用 `LAUNCH.sh` 啟動,不要直接 `hermes` |
| 報錯 `SOUL.md not found` | `get_hermes_home()` 沒切到 developer | 同上 |
| Bot 在 Discord 出現離線又上線的循環 | Token 跟 default 衝突 | 確認用了不同的 Discord Application |
| 出現 `Permission denied` 在 `~/.hermes/profiles/developer/` | 檔案權限問題 | `chmod -R u+rwX ~/.hermes/profiles/developer/` |

---

## 進階:在現有 dev session 內臨時切到 developer 身份

如果您已經在 default profile 跑著,只是想**臨時讓當前 session 套用 Tree Monstor 行為**,可以:

```bash
# 在 default session 內 `/skill load` 把 SOUL.md 內容手動加進 context
/skill view developer   # 列出 developer profile 的 skill
# 或
/personality developer  # 切到 developer personality
```

這是「借用行為模式」,不是「真的切到 developer profile」。要完整切過去還是要用 `LAUNCH.sh` 啟新 session。
