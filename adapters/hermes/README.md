# Tree Monstor — Hermes Adapter (macOS 版)

> **適用平台**:macOS + Hermes Agent v0.15.1+
> **本檔案位置**:`~/.hermes/profiles/developer/adapters/hermes/README.md`

把 Tree Monstor 當作 Hermes Agent 的「developer profile」使用。

---

## 為什麼用 Profile(不用全域安裝)?

Hermes 0.15.1 內建 **profile 機制**,可以讓多個獨立 Hermes 實例並存,各自有獨立的:
- `SOUL.md` / `AGENTS.md` / `MEMORY.md`(身份)
- `config.yaml`(設定)
- `.env`(API keys / tokens)
- `skills/`(自帶 56 個 developer 專用 skills)
- `sessions/`、`logs/`、`state.db`(對話紀錄跟 log)

把 Tree Monstor 裝成 `developer` profile,**完全不影響** `default` profile 跑您平常的對話助理。兩個 profile 並存,各自有各自的 Discord bot。

---

## 🚀 快速啟動(3 步)

```bash
# 1. 編輯 .env,填入 token
cp ~/.hermes/profiles/developer/adapters/hermes/.env.template \
   ~/.hermes/profiles/developer/.env
nano ~/.hermes/profiles/developer/.env

# 2. 啟動
~/.hermes/profiles/developer/LAUNCH.sh
```

啟動後,在 Discord 用 `/status` 應看到 `Profile: developer`。

完整指南見:`~/.hermes/profiles/developer/setup-macos.md`

---

## Hermes 怎麼找到 Tree Monstor 的身份?

啟動時,Hermes 內部:
1. `hermes --profile developer` 把 `HERMES_HOME` 設成 `~/.hermes/profiles/developer/`
2. 讀取 `~/.hermes/profiles/developer/SOUL.md`(透過 `load_soul_md()` 函式)
3. SOUL.md 內容**自動注入 system prompt** 作為 primary identity
4. 然後才是 config.yaml 的其他設定

所以**您不用手動做「載入 SOUL」這件事** — Hermes 已經幫您處理了 ✅

---

## 跟 default profile 的關鍵差異

| 面向 | default profile | developer profile (Tree Monstor) |
|------|----------------|---------------------------------|
| 身份檔 | `~/.hermes/SOUL.md`(Hermes 內建) | `~/.hermes/profiles/developer/SOUL.md`(Tree Monstor) |
| 設定 | `~/.hermes/config.yaml` | `~/.hermes/profiles/developer/config.yaml` |
| 環境變數 | `~/.hermes/.env` | `~/.hermes/profiles/developer/.env` |
| Skills | `~/.hermes/skills/`(32 個) | `~/.hermes/profiles/developer/skills/`(56 個) |
| 對話紀錄 | `~/.hermes/sessions/` | `~/.hermes/profiles/developer/sessions/` |
| Discord bot | 您現在用的那個 | **新建的另一個**(必須用不同 Application) |
| 預設模型 | MiniMax-M3 | MiniMax-M3(跟 default 一致) |
| 專案目錄 | `~/` 自由 | `~/www/<project>/`(L2 隔離) |

---

## 常見指令

```bash
# 啟動 developer profile(chat 互動模式)
~/.hermes/profiles/developer/LAUNCH.sh

# 啟動 gateway(背景跑 Discord bot)
~/.hermes/profiles/developer/LAUNCH.sh gateway run

# 看 profile 狀態
~/.hermes/profiles/developer/LAUNCH.sh profile show

# 單次查詢
~/.hermes/profiles/developer/LAUNCH.sh chat -q "幫我看一下 SOUL.md"

# 背景服務化(macOS launchd)
~/.hermes/profiles/developer/LAUNCH.sh gateway install
~/.hermes/profiles/developer/LAUNCH.sh gateway start
~/.hermes/profiles/developer/LAUNCH.sh gateway status

# 切回 default
hermes profile use default
# 或
hermes --profile default
```

---

## 環境變數參考

| 變數 | 必填 | 用途 |
|------|------|------|
| `DISCORD_BOT_TOKEN` | ✅ | 這個 profile 專用的 Discord bot token(**不可**跟 default 同一個) |
| `OPENROUTER_API_KEY` | ✅ | subagent delegation 路由(用於 medium / complex tier) |
| `MINIMAX_API_KEY` | 選 | 跟 default 共用即可,可不填 |
| `HERMES_MAX_ITERATIONS` | 選 | 預設 1000,長期任務可調高到 1500 |
| `LOG_LEVEL` | 選 | debug / info / warn / error,預設 info |

---

## ⚠️ Tree Monstor 預設 `gateway.yaml` 為什麼不適用

Tree Monstor 的舊版 `gateway.yaml` 是給 Linux systemd 部署寫的,schema 跟 Hermes 0.15.1 不相容。Hermes 0.15.1 用的是 `~/.hermes/profiles/developer/config.yaml`,gateway 連線設定從那裡讀。

**請忽略** `adapters/hermes/gateway.yaml` 跟 `adapters/hermes/README.md` 提到的「Background Service (systemd)」段落 — 在 macOS 改用 launchd 跟 `hermes gateway install` 處理。

---

## 平台無關的核心

不管用 Hermes / Claude Code / Codex,**核心檔都一樣**:
- `SOUL.md` — 身份
- `AGENTS.md` — 啟動流程
- `MEMORY.md` — 長期記憶
- `docs/` — 詳細規範
- `skills/` — 56 個專業 skill

每個平台只差「怎麼把這份核心載入 prompt」,不差核心內容。
