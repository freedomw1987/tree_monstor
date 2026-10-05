# TMO-040：`setup-venv.sh` 破壞性護欄（NYH-5 方案 A）＋ 行政清理

- **日期**：2026-10-05
- **Backlog ID**：TMO-040（＋前置行政清理 TMO-049/051/052 結案；新開 TMO-053/054/055/056）
- **作者**：pi（david 的 agent，一般模式；非 trust）
- **狀態**：**待用戶驗收**。Gate 1–4 全綠；Gate 4 二審 verdict = `approve`（0 P0 / 0 P1 / 0 P2 / 1 P3 report-only），
  reviewer 明示「就程式碼層面：**沒找到更多問題**」、「交付用戶驗收：可以」。
- **commit**：`ef563f3`（行政清理）→ `b2a775b`（護欄實作）→ `fbccea1`（二審補正）

## 摘要

TMO-040 是 reviewer 在 TMO-029 Round-4 抓到的**真事故路徑**：`setup-venv.sh` 的 `POC_VENV_DIR` 護欄只擋
「結構性壞值」（空、非絕對、少於兩層、結尾斜線、`.`／`..`／`//` 段），但 `POC_VENV_DIR=$HOME --force`
這種**結構完全合法卻指向災難**的值仍會 `rm -rf` 家目錄。用戶於 2026-10-05 ask-me 拍板採 **A 方案**
（危險清單＋二次確認），本輪完成實作、探針與二審。

同時清掉三張純行政票（`ef563f3`）：TMO-049/051/052 的「待 CI 複驗」條件在 run `37248578384` @ `507b6d5`
成立（兩腿的 shellcheck＋bash syntax step、markdownlint job 皆 success）→ 全部 `done`；並把 3 條 orphan
的 need-you-help 條目對上票號、補回 NYH-3 遺失的「影響」標題。

## 變更清單

| 檔 | 變更 |
| --- | --- |
| `skills/regression-guard/PoC/setup-venv.sh` | 新增 `--yes` / `-y`、`_is_dangerous_venv_dir()`／`_reject_dangerous_venv_dir()`／`_resolve_dir()`／`_lower()`／`_assert_safe_venv_dir()`；危險清單檢查（`rm -rf` 之前，兩次）＋自訂目錄二次確認 |
| `tests/poc-venv-guard.bats` | **新檔，10 條**探針（危險清單、`--force`/`--yes` 不可繞過、fail-closed、正向對照 ×2、三種字面繞道、次序鎖） |
| `skills/regression-guard/PoC/README.md` | 目錄結構註解、三種 `--force` 用法、破壞性護欄 blockquote、探針註記 |
| `CONTRIBUTING.md` | `setup-venv.sh` 指令下補護欄說明；`v2.1-jev-poc.bats` 條數 38 → 40 |
| `docs/install-reference.md` | 套件條數與 clean-clone 紅燈數更新為實測值（586 / 589 / 543 / 43） |
| `docs/backlog.md` | TMO-049/051/052 → `done`；TMO-035/040 → `doing`→`done`；新增 TMO-053/054/055/**056**；CI 複驗註腳 |
| `docs/need-you-help.md` | orphan 對票、NYH-3 標題補回、NYH-5 標記已結案＋遺留項指向 TMO-056 |

### 護欄設計（用戶拍板的三段）

1. **危險清單**：**整條路徑完全相等**才拒（子路徑如 `$HOME/projects/x`、`/opt/venvs/x` 仍允許）。
   系統項 `/ /bin /sbin /usr /etc /var /tmp /opt /private /private/{etc,tmp,var} /dev /cores /Network
   /Library /System /Applications /Users /Volumes /home /root`；使用者項 `$HOME` 本體及
   `$HOME/{Library,.ssh,Desktop,Documents,Downloads,Music,Pictures,Public}`。
   **`--force` 與 `--yes` 都不能繞過**。
2. **二次確認**：**僅當使用者自訂 `POC_VENV_DIR` 且目錄已存在**時要求（預設 `PoC/.venv` 免確認、零摩擦）；
   需輸入目錄名（basename）；`--yes|-y` 為非互動豁免；讀不到輸入一律 **fail-closed**（不刪就退出 rc=1）。
3. **三種字面繞道**（各有反向探針）：①`HOME` 尾斜線 ②symlink 祖先（`pwd -P` 物理路徑）③**大小寫**
   （macOS case-insensitive）。

## 測試驗收證據（4 Gates）

> **依 gates.json 規範，Gate 1 (TDD) 需要：測試先紅後綠，並在對話貼出「測試執行指令 + 失敗輸出 + 通過輸出」。**
> **依 gates.json 規範，Gate 2 (lint/syntax) 需要：語言對應 linter 0 error/0 warning，並貼出完整 linter output。**
> **依 gates.json 規範，Gate 3 (regression) 需要：探針埋好 + 完整測試套件跑過，並貼出「修改前 baseline + 修改後 output + Diff 對比」。**
> **依 gates.json 規範，Gate 4 (reviewer) 需要：checker 回傳「沒找到更多問題」（UI 任務另需 playwright-cli E2E 全綠）。**
> 本任務為純 shell 腳本護欄，**無 UI → playwright-cli 不適用**（明示）。

### Gate 1（TDD：先紅後綠）

指令：`bats tests/poc-venv-guard.bats`

| 階段 | 紅 | 綠 |
| --- | --- | --- |
| 首輪（新檔 7 條） | `not ok 1..7`（腳本尚無護欄） | 加護欄後 7/7 ok |
| 自審補 2 條繞道 | `not ok 7`（symlink）、`not ok 8`（尾斜線） | 加 `_resolve_dir`/`_home_norm` 後 9/9 ok |
| Round-2 補 1 條大小寫 | 舊腳本（`b2a775b`）＋新測試 → `not ok 1`（`FAIL: 家目錄的大小寫變體未被擋（rc=2）`）、次序鎖 `not ok 1`（`找不到刪前重驗（line=）`） | 新腳本 → **10/10 ok** |

最終輸出：

```text
1..10
ok 1 POC-VENV-GUARD: danger-list paths are refused with a distinct message
ok 2 POC-VENV-GUARD: $HOME itself survives --force --yes (danger list beats both flags)
ok 3 POC-VENV-GUARD: custom dir + --force refuses to delete when stdin is closed (fail-closed)
ok 4 POC-VENV-GUARD: custom dir + --force needs the exact dir name typed
ok 5 POC-VENV-GUARD: --force --yes still works for a legitimate custom dir (no over-blocking)
ok 6 POC-VENV-GUARD: default dir + --force needs no confirmation (documented usage unchanged)
ok 7 POC-VENV-GUARD: symlink ancestor cannot smuggle a dangerous target past the list
ok 8 POC-VENV-GUARD: HOME with a trailing slash still matches the danger list
ok 9 POC-VENV-GUARD: case variants of danger-list paths are refused (macOS is case-insensitive)
ok 10 POC-VENV-GUARD: danger check and confirmation both run before the destructive rm
```

> 測試不得帶破壞風險：大小寫那條刻意用 `$BATS_TEST_TMPDIR/CASEHOME`（tmp 內、附 sentinel），**不用
> `/private/TMP`**——後者在 macOS 就是真的 `/private/tmp`，護欄一旦回歸該測試自己就會清系統目錄。

### Gate 2（lint / syntax）

```text
$ shellcheck -x -S style $(git ls-files '*.sh' '*.bash')
rc=0，零輸出
$ for f in $(git ls-files '*.sh' '*.bash'); do bash -n "$f"; done
OK: 23 shell files syntax-checked, 0 bad
$ npx markdownlint-cli2 "skills/**/*.md" "docs/**/*.md" "tests/**/*.md" "*.md"
Linting: 128 files
Summary: 0 issues in 0 files
```

### Gate 3（regression）

| 量測 | 指令 | 結果 |
| --- | --- | --- |
| baseline（改動前） | `git stash -u` → `bats tests/` | **576 ok / 0 not ok** |
| 首輪改動後 | `bats tests/` | **585 ok / 0 not ok**（plan `1..585`） |
| Round-2 改動後（最終） | `bats tests/` | **586 ok / 0 not ok**（plan `1..586`） |
| skill 自帶探針 | `SKILLS_DIR_OVERRIDE="$PWD/skills" bats skills/*/tests/*.bats` | **3 ok** |
| clean clone（暫移 `.venv`） | `bats tests/` | **543 ok / 43 not ok** |

Diff 對比（測試名集合）：585 → 586 只多一條 `POC-VENV-GUARD ... case variants`；**0 條被刪或改名**
（另一筆 M6-g 差異為測試名含隨機 tmp 路徑，非真差異）。

### Gate 4（reviewer）

- **Round-1**（artifact `/tmp/tmo040-review.diff`，547 行）：verdict `approve-with-comments`，
  **0 P0 / 0 P1 / 1 P2 / 6 P3**，「可交付用戶驗收？yes」。確認「危險清單與二次確認都在唯一的
  `rm -rf "$VENV_DIR"` 之前」、「`--force`/`--yes` 皆無法繞過清單」、「未堵的破壞性繞道：沒找到」。
- **Round-2**（artifact `/tmp/tmo040-review2.diff`，317 行）：verdict **`approve`**，
  **0 P0 / 0 P1 / 0 P2 / 1 P3（report-only）**，原文：
  > **verdict：`approve`** — 0 P0 / 0 P1 / 0 P2，附 1 條 P3（report-only）…**不阻 merge、不需再一輪**。
  > …**就程式碼層面：沒找到更多問題**——唯一殘留是上述 P3 的**證據轉錄**，非程式缺陷。
  > 4. **交付用戶驗收：可以**
  - 裁決三項：「P3-d 拒改 → **同意**」、「P3-a 延後＋TMO-056 → **可接受**」、「M-D 判無效突變 → **裁定正確**」。

### V03.6 分類與放寬申報

本輪**新增探針檔** `tests/poc-venv-guard.bats` → 依 V03 走二審（已走完兩輪）。
**無任何條件放寬**：只新增／從嚴（未刪除探針、未放寬門檻、未放寬 regex）。

## 突變驗證（探針真的會咬）

| 突變 | 結果 |
| --- | --- |
| M-A' `_assert_safe_venv_dir` 變 no-op（危險清單全關） | 紅 1 2 7 8 9 |
| M-B 兩處護欄呼叫都拿掉 | 紅 1 |
| M-C 停用二次確認 | 紅 3 4 |
| M-D' `--yes` 直接跳過整個護欄（真正讓 `--yes` 繞過） | 紅 2 7 8 9 |
| M-E 移除 `pwd -P` 物理路徑比對 | 紅 7 |
| M-G 移除大小寫正規化（只拿掉候選側 `_lower`） | 紅 2 7 8 9 |
| M-H 移除刪前重驗（TOCTOU 窗全開） | 紅 10 |
| M-I 危險清單刪掉 `/private/tmp` | 紅 1 |

全部以 `diff -q` 驗證 **byte-identical 還原**。兩個「無效突變」的判定（皆經 reviewer 覆核）：

- **M-D**（`--yes` 繞過單一檢查）→ 全綠：**冗餘的第二道檢查仍擋下**，突變沒真正改變行為，非探針漏洞。
- **M-F**（取消 `HOME` 去尾斜線）→ 全綠：`_home_resolved` 仍擋下，同屬冗餘機制。

> **P3（reviewer report-only）覆核結果：commit body 的 M-G 清單正確，reviewer 的推理有誤。**
> reviewer 推測「只移除大小寫正規化應紅 {2,7,9}」，理由是 test 8 靠字面樣式命中。實測反例：
> `$BATS_TEST_TMPDIR` 在 macOS 為 `/var/folders/T2/...`（**含大寫 `T`**），故只拿掉候選側小寫化時
> `_d`（未降）≠ `_h`（已降）→ test 8 也紅。已實跑複驗：紅 {2,7,8,9}，與 commit body 一致。

## reviewer 修正（Round-1 → Round-2）

| 項 | 處置 |
| --- | --- |
| P2-1 文件殘留舊數字 `576` | ✅ 改 586（`install-reference.md:331`；:264 為歷史量測，保留） |
| P3-a 列舉清單邊界（`/Volumes/<碟>`、`/Users/<他人>` 一層子項） | ⏸️ 延後 → **TMO-056**（reviewer 認可；附「allow 側在 CI 無可驗路徑」原因） |
| P3-b 大小寫繞道 | ✅ **實測為真洞**（`cd /private/TMP && pwd -P` → `/private/TMP`）→ 加 `_lower()` ＋第 9 條探針 |
| P3-c TOCTOU | ✅ 護欄抽成函式呼叫兩次（確認前＋`rm -rf` 前）＋次序鎖擴充 |
| P3-d `[ -t 0 ]` 硬拒非 TTY | ❌ 拒絕（會封殺 `printf 'dir\n' \| script` 正當用法，test 4 正是此法）— reviewer **同意** |
| P3-e `CONTRIBUTING` 38 vs 40 | ✅ 改 40 |
| P3-f basename 確認機制 | ➖ 維持（用戶已拍板） |

## 已知問題（不阻 merge）

1. **TMO-056**：`/Volumes/<碟>`、`/Users/<他人>` 這種「容器本體的一層子項」未入清單，目前靠二次確認擋。
2. **Unicode 正規化變體**（reviewer 提出，未實測）：`_lower` 只解大小寫；APFS 亦 normalisation-insensitive，
   非 ASCII `$HOME` ＋不同正規化拼法＋`--yes` 理論上仍可繞。觸發條件極窄 → 與 TMO-056 併記。
3. **TOCTOU 只縮窗**：`_assert_safe_venv_dir` 之後到 `rm -rf` 仍有微秒級窗口，且 `rm -rf` 用未解析路徑。
   本地開發腳本可接受。
4. **大小寫誤拒**（理論）：case-sensitive Linux 上「與清單項只差大小寫」會多拒；實務上不可能誤傷。

## 下一步建議

1. **本輪交付驗收**（TMO-040 完成）。
2. **item 3**：TMO-035（`dav-wiki/SKILL.md:94` 限制表對齊現實）＋ TMO-053（secret 遮罩通則）**合批**走 V03 二審。
3. **item 4**：TMO-055（README 加「本機開發前置」區塊）；順帶監控 `dav-skill-creater/SKILL.md`（148/150 行）。
4. **item 0**（僅用戶可做）：TMO-054 OpenRouter key 輪替。

## 反思

**做對的**：把「護欄有沒有用」從「測試綠」推進到**突變驗證**，是這輪真正的品質來源——M-A'/M-D'/M-G/M-H/M-I
全部咬住，且兩個「無效突變」（M-D/M-F）不是掩蓋而是被判定為**冗餘機制的正確表現**，並請 reviewer 覆核。

**做錯的**：第一次寫大小寫探針時用了 `/private/TMP`——在 macOS 那就是真的 `/private/tmp`，**護欄若回歸，
測試自己會清掉系統目錄**。這是「測試比被測物更危險」的典型，當下自己發現並改成 tmp 變體＋sentinel。
教訓：破壞性腳本的探針，**先問「這條測試失敗時會發生什麼」**。

**學到的**：①`pwd -P` **不**做大小寫正規化（實測推翻直覺）；②`$BATS_TEST_TMPDIR` 在 macOS 含大寫，
會讓「看似與大小寫無關」的測試其實依賴大小寫正規化；③reviewer 的推理也會錯（M-G 清單），
**用實跑反例回報比接受權威更有價值**。

**流程面的觀察（值得記）**：Round-1 reviewer 給 `approve-with-comments` 且 P2 只有「文件一行數字」時，
「先修再審一輪」的成本明顯高於收益；但本輪因為**同時**動了程式（大小寫、TOCTOU）才值得第二輪——
判準應該是「是否動到行為」，而非「是否還有意見」。
