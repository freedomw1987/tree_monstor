# dav-self-compact — 安裝／驗證／故障排除

## §1 裝兩樣嘢 ＋ 對齊一個設定

1. **Extension**（提供 `ctx_status` ＋ 每輪注入提示 ＋ `/ctx` 指令）：

```bash
mkdir -p ~/.pi/agent/extensions
# Symlink the DIRECTORY (pi discovers <dir>/index.ts; relative imports keep working)
ln -sfn "$PWD/skills/dav-self-compact/extension" ~/.pi/agent/extensions/dav-self-compact
```

> `./install.sh --agent pi` 會自動做呢步（`install_pi_extensions`）＋ 順手 symlink 現成 agent `~/.agents/dav-long-run.md`；手動裝先用上面兩行。

2. **Skill**（父 session 用；subagent 要另外傳，見 `protocol.md` §7）：

```bash
ln -sfn "$PWD/skills/dav-self-compact" ~/.pi/agent/skills/dav-self-compact
```

3. **原生自動壓縮對齊**（hard block 嘅真保險絲）—— 改 `~/.pi/agent/settings.json`：

```json
{
  "compaction": {
    "modelOverrides": {
      "minimax/MiniMax-M3.1-Flash": { "reserveTokens": 880000 }
    }
  }
}
```

- 公式：`reserveTokens = contextWindow − hardTokens`（hardTokens = 有效窗口 × hardPercent）。
- 純百分比模式：1M ＋ hard 60% → `400000`；設咗 `absoluteCapTokens: 200000` → hardTokens = 120k → `880000`。
- 摘要長度唔受 `reserveTokens` 影響（pi 用模型輸出上限做摘要），所以調大唔會整肥摘要。
- key 係 `provider/modelId`（大小寫敏感）；同一 provider 其他 1M 模型要各自加一條。
- **只可以對真係咁大窗口嘅模型設大值**：若模型窗口細過 `reserveTokens`，條件永遠成立 → 每輪都壓縮。
- 改完唔使重開 pi，但**新 session** 先用到新值；`ctx_status` 會顯示原生觸發點，對唔上就有 ⚠ 提示。

## §2 驗證

- **Extension 載入咗未**：`pi -p "call ctx_status and report the result"` → 應回覆一條 `ctx …% … zone=… …（native auto-compaction fires at …%）`。
- **手動睇**：`/ctx` → 顯示 usage、zone、action 同保險絲狀態。
- **Skill 載入咗未**：開新 session 問「dav-self-compact 嘅三個區係咩？」→ 應答得出 smart／soft／hard。
- **行數規矩**：`bats tests/skill-size.bats` → 全綠（主檔 ≤50 行、子檔 ≤150 行、context ≤400 行）。
- **保險絲有冇真係生效**：把 `reserveTokens` 暫時設細（例：`contextWindow − 30000`），跑一段長對話，睇 session JSONL 有冇 `"type": "compaction"`；驗完記得改返。

## §3 閾值設定檔（可選）

`~/.pi/agent/dav-self-compact.json`：

```json
{
  "softPercent": 50,
  "hardPercent": 60,
  "targetPercent": 35,
  "targetMinPercent": 20,
  "absoluteCapTokens": 0
}
```

- 想真係長期留喺「聰明區」而唔係「窗口嘅一半」→ 設 `absoluteCapTokens`（例：`200000`）。
- 檔案唔存在／壞咗 → 用默認值，唔會令 session 死機。

## §4 故障排除

- **`ctx_status` 唔見**：extension 冇載入 → 檢查 `~/.pi/agent/extensions/dav-self-compact/`（要係 symlink 去 `<repo>/skills/dav-self-compact/extension`，而該目錄有 `index.ts`）＋ `lib/zone.ts` 存在；`/reload` 或重開 pi。
- **`zone=unknown`**：剛壓縮完、未有新模型回應 → 等下一輪再查（唔係錯誤）。
- **見到 `⚠ native auto-compaction only fires at X%`**：settings 未設 `reserveTokens` → 照 §1 第 3 點改。
- **壓縮冇發生**：先睇 `keepRecentTokens`（默認 20000）——context 未超過它就「冇嘢可壓」；再睇 `compaction.enabled` 有冇被關。
- **壓縮完 usage 唔跌**：通常係交接筆記太薄，或者對話有超大字串（貼咗長 log）→ 拆細啲、再壓；連續兩次唔跌就停低報告。
- **前台 subagent 冇 `ctx_status`**：前台 subagent 唔自動載入全域 extension → agent frontmatter 加 `extensions: [<extension 目錄>]` 同 `tools: [..., ctx_status]`（見 `protocol.md` §7），或者接受「靠父 agent ＋ 交接筆記」嘅 fallback。
- **唔好用 `ctx_compact` 呢類自製工具**：pi 1.4.0 喺 tool call 內觸發壓縮會連摘要一齊被 abort（見 `reference.md` §6）。
