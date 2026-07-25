# Multi-Arch Image Build — Decision Matrix

2026-06-09 PM-System 客戶交付時嘅 decision matrix。**下次有同類「客戶唔可以 build
但要行多個 arch」嘅 case 直接用呢個 matrix**。

---

## 場景描述

客戶機:
- **唔可以畀 source code**(可能係 IP 保護、合約、或者客戶根本唔識睇 code)
- **CPU arch 唔定**(有時 x86 server,有時 arm 機,有時唔知)
- **會有更新**(唔係一次性 ship 就算)

呢個 case 嘅標準答案 = **multi-arch image + tarball handoff**。

---

## Decision 1:Image package 結構

| 選項 | 描述 | 優 | 缺 | 揀? |
|------|------|---|----|-----|
| **A) Multi-arch single tarball** | 1 個 tar 包含 manifest list,客戶 `docker load` 後自動揀 arch | 客戶 1 行搞掂、唔使揀 | tar 大(backend 兩份 binary 打包) | ✅ **2026-06-09 揀** |
| B) 兩個獨立 tarball | `frontend-amd64.tar` + `frontend-arm64.tar` | 細啲檔案 | 客戶要識揀自己機 arch、容易撈錯 | ❌ |
| C) Per-arch compose | `docker-compose.amd64.yml` + `docker-compose.arm64.yml` | 客戶直接睇 arch 揀 compose | 維護兩份 compose、容易唔同步 | ❌ |

**A 揀嘅原因**:客戶機 admin 唔一定有 Docker 經驗,1 個 file 1 行 command = 零出錯。

---

## Decision 2:Build 邊度跑

| 選項 | 描述 | 優 | 缺 | 揀? |
|------|------|---|----|-----|
| **A) 我 pre-build,客戶只 load** | 你 build 好 tarball 寄畀客戶 | 客戶唔識 build、image 100% 一致 | 你要起 build farm / 接受 QEMU 慢 | ✅ **2026-06-09 揀** |
| B) Dockerfile 寄客戶 build | 客戶 buildx build | Linux native build 快 | Dockerfile 算 source、違反「唔畀 source」 | ❌ |
| C) GH Action / CodeBuild | 自動 build + publish release page | 一 push tag 就出 | 要起 workflow,setup 成本 | ⏳ 將來 scale 時考慮 |
| D) Docker Hub 公開 registry | push 上去,客戶 pull | 客戶標準 `docker pull` | 客戶要裝 Docker Hub login、IP 風險 | ❌ |

**A 揀嘅原因**:符合「唔畀 source」最強(客戶冇 Dockerfile、冇 registry credentials)。
Mac M-series 跑 QEMU 慢 5-10x 但 release 唔算熱點,可以接受。

**將來 scale 條件**:如果 > 5 個客戶 / 每週 release > 1 次,改去 C 方案(GH Action)。

---

## Decision 3:Seed 點處理(2026-06-09 unique 問題)

客戶機用 Prisma,但 **seed 屬 source code 不外流**。

| 選項 | 描述 | 優 | 缺 | 揾? |
|------|------|---|----|-----|
| **A) `.dockerignore` 排走 `prisma/seed*`** | image 入面冇 seed file | 即使反組譯都見唔到 seed 內容 | seed file 喺 dev 仍可跑 | ✅ |
| B) 接受 seed 入 image | 唔做特別嘢 | 簡單 | 客戶反組譯會見到 demo data | ❌ |
| C) Seed 搬去 `prisma/seed.dev.ts` | .dockerignore 排 `seed.dev*` | 結構更清楚 | 改 file 命名、可能 break script | ⚠️ 改得起但唔需要 |

**A 揀嘅原因**:零改動,加 1 行 `.dockerignore` 就搞掂。

**注意**:`.dockerignore` 嘅 `!` negation rules 有 pitfall — **唔好用** `!prisma/seed*` 嘅
`!` syntax,直接用 standard 排除 pattern。Elysia/Bun image 嘅 `.dockerignore` 通常已經有
`node_modules` `.git` 等,加多一行 `prisma/seed*` 就夠。

---

## 3 條約束 × 4 個 standard 做法的對照

| 約束 | 推薦做法 | 反例(常見錯誤) |
|------|---------|---------------|
| **唔畀 source** | 客戶機只有 image + install script | 寄 Dockerfile 叫客戶 build |
| **多 arch** | buildx + manifest list + `docker save` | 兩份 compose、客戶揀 |
| **可更新** | named volume(保留 data) + install script idempotent | `docker compose down -v` 喺 update script 內 |

---

## 「做 vs 唔做」checklist(下次 release 必跑)

### 必做
- [ ] Build 兩份 platform tag(amd64 + arm64)
- [ ] `docker manifest create` 整 manifest list
- [ ] `docker save` 出 tar + `shasum -a 256` 出 CHECKSUMS
- [ ] `deploy/docker-compose.client.yml` 冇 `build:`、冇 seed command
- [ ] `deploy/.env.client.example` 必填 field 用 `PLACEHOLDER` 字眼
- [ ] `deploy/install.sh` 有 regex 驗必填
- [ ] backend Dockerfile 冇 `bun build`(`ReferenceError: vn is not defined` pitfall)
- [ ] Prisma 7 嘅 `prisma.config.ts` Dockerfile COPY 咗
- [ ] `prisma/seed*` 落 `.dockerignore`

### QA Gate
- [ ] load 入第二個目錄,`docker compose -p pm-system up -d`
- [ ] `curl http://localhost/api/projects` = 200
- [ ] `curl http://localhost/` = HTML
- [ ] 確認冇 seed 跑
- [ ] `docker compose -p pm-system down` 唔刪 data volume

### Anti-patterns(遇過即 reject)
- ❌ 寄 Dockerfile 叫客戶 build(違反「唔畀 source」)
- ❌ 客戶 compose 有 `prisma db seed`(seed 屬 source 不外流)
- ❌ 客戶 compose `db.password: pmpassword` hard-coded(security hole)
- ❌ backend port 公開 bind host(改用 internal `expose:`)
- ❌ install.sh 唔驗 CHECKSUMS(tarball 可能傳輸中壞咗)
- ❌ bun build minify 撞 Elysia(沿用 source run)
- ❌ Compose 唔用 named volume(客戶 update 會 data loss)
