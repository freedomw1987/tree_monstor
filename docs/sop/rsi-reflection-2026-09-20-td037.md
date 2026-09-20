# RSI 反思 — TD-037（2026-09-20）

> **對應 Sprint**：Sprint 13 TD-037
> **類型**：技術債（擴充 rsi-propose 能力）
> **SP**：1 SP

## 1. 做了什麼

`rsi-propose.sh` 加 `--output-format json` 旗標。

- 既有 `text` 格式保留為預設
- 新加 `json` 格式：含 schema_version / generated_at / proposals[]
- 每個 proposal 含 id / event_type / count / confidence / file / description / diff_preview
- confidence 公式：min(1.0, freq × 0.3 + projects × 0.2 + 1)

## 2. 為什麼這樣做

| 需求 | 解法 |
|---|---|
| Agent 無法解析 text 輸出 | 加 JSON 結構 |
| cron 無法自動套用 text 輸出 | JSON 可被機器解析 |
| 既有功能不能破壞 | text 預設保留 |
| 中文不被 unicode escape | python `ensure_ascii=False` |

## 3. 過程問題與解法

### 問題 1：awk 三元運算被截斷

```bash
# 失敗
confidence="$(awk -v c="$count" -v p="$projects" 'BEGIN { printf "%.2f", (c * 0.3 + p * 0.2 + 1) > 1 ? 1 : (c * 0.3 + p * 0.2 + 1) }')"

# 解法：用 if/else
confidence="$(awk -v c="$count" -v p="$projects" 'BEGIN { v = c * 0.3 + p * 0.2 + 1; if (v > 1) v = 1; printf "%.2f", v }')"
```

### 問題 2：python json.dumps 預設 `ensure_ascii=True`

中文被轉成 `\uXXXX`，對人類閱讀不友善。

**解法**：明確傳 `ensure_ascii=False`

### 問題 3：bash 函式定義位置

函式定義放在檔案最後會導致「command not found」。

**解法**：函式定義必須在呼叫之前，或在 main 函式內

## 4. 量化指標

| 指標 | 數值 |
|---|---|
| 工具功能 | rsi-propose 多了 1 個輸出格式 |
| bats 新增 | 6 個 |
| markdownlint | 0 issues |
| 向後相容 | ✅ text 預設保留 |

## 5. 下一步建議

- Sprint 14+ 可加 `--output-format yaml`（給 K8s / Ansible 用）
- Agent 自動讀取 JSON 套用提案（需人類批准前仍）

## 6. 版本

- v1.0（2026-09-20）— TD-037 反思初版