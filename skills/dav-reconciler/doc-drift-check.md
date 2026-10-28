# Dav Reconciler — 文件漂移檢查（D1..D8）工具用法

> 本檔為 `dav-reconciler` skill 的子檔，講「目標專案安裝 tree_monstor 之後，自己點跑文件漂移檢查」。入口在同套 `SKILL.md`。
>
> 目標專案安裝 tree_monstor 後，本 skill 的 `scripts/check-doc-drift.py` 會跟著到位，
> 專案可自己跑「文件漂移檢查」（D1..D8）把「同一件事多份文件各說各話」擋在 CI。

## 怎麼跑

```bash
# 目標專案的專案根目錄下執行（--root 預設＝目前目錄）

python3 <安裝後的 skill 目錄>/scripts/check-doc-drift.py --root .
```

- **`--root <專案根>`**
  - 說明：要檢查的專案根目錄（預設：目前目錄）
- **`--whitelist <檔>`**
  - 說明：白名單檔（預設：`<root>/docs/ci/drift-whitelist.txt`）
- **`--from-date YYYY-MM-DD`**
  - 說明：交付摘要檢查的生效日（回溯舊交付會大量假紅）
- **`--require-window-checks`**
  - 說明：
    **fail-closed 嚴格模式**：`docs/deliverable/` 存在時，窗內必須有交付摘要，且至少要有一支引用得到 `docs/req/` 錨點（否則 D4/D8 的檢查件數為 0＝硬門檻靜默失效）→
    rc=1。本 repo 的 `scripts/ci/check-doc-drift.sh` 在未指定 `--root` 時會**自動**加上它；帶 `--root` 即視為外部專案、只印 `WARNING`（可攜語意）

**rc 契約**：`0` 無違規（含全部被白名單豁免）｜`1` 有違規｜`2` 用法 / 環境錯誤（fail-closed）

## 目標專案要先準備什麼

1. `docs/backlog.md`（狀態欄位是 D1 的比對基準；本專案以 backlog.md 的「狀態定義」為單一來源）
2. `docs/ci/drift-whitelist.txt`（白名單，每行 `<類>#<鍵>#<理由>`；**理由不可為空**，全類豁免 `<類>#*` 會被 rc=2 擋下）

## CI 範例

```yaml
# 方式 A（推薦）：用 wrapper —— 未帶 --root 時自動開嚴格模式（本 repo 的做法）

- name: Verify no document drift
  run: bash scripts/ci/check-doc-drift.sh --from-date 2026-10-26

# 方式 B：直接呼叫 python —— 這時**必須自己**帶 --require-window-checks，
#         否則等同只拿 warning 模式，fail-closed 不會生效
- name: Verify no document drift
  run: python3 <skill 目錄>/scripts/check-doc-drift.py --root . --from-date 2026-10-26 --require-window-checks
```
