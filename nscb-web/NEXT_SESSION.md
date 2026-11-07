# 下一轮会话起点：Wave 3b

**当前状态**：NSCB 本地功能/UI **已全部对齐**（含 #8 keygen、#12/18 重命名净化、MODE0 配置、MODE5 数据库、#23 还原、以及 **delta 合并端到端打通**）。在线/主机类（MTP/DBI/Drive/1fichier/nutdb/autoloader）用户明确不需。全量 run_all：**29 pass / 0 fail / 1 skip**；单测 **126**。

**全量 run_all 回归**：29 pass / 0 fail / 1 skip（skip 是 NPDM 用例10，因本机 title.keys 缺那个小样本的 program key，属环境依赖非失败）。case 20 覆盖 Database/Rename/Restore/PatchKeygen；case 21 覆盖 delta 合并端到端。

## ⭐ NSCB 全功能对齐（进行中，2026-11）
目标：UI + 功能完整对应原 NSCB，逻辑正确。以 `py/README.md` §3（1–31）+ 各 MODE 为准。
- **已完成新增**：**MODE5 Database 批量信息导出**（`NscbCore/Info/DatabaseExporter.cs`：文件/文件夹递归扫描 .nsp/.nsz/.xci/.xcz/.nca/.ncz → CSV/TSV/JSON/TXT，含电子表格公式注入中和；`JobType.Database`+服务端 case+UI 动作+i18n×4+4 单测）。单测 **114→118**。
- **已修逻辑 bug**：`upd_base` **必须替换 Control**（NSCManager/主机显示的“版本”是 Control NACP 的 `DisplayVersion`，不是 cnmt TitleVersion）→ `SwappableTypes` 加入 `Control`。另 NCA 头 0x208 整档大小必须随重建更新（DBI 会查）。**PackXci（NSCB 多打包）正确行为＝把所有源的内容全部放进单一 `secure` 分区（原样拷贝不改→签名不变）；安装器（DBI/Tinfoil）从 secure 里枚举所有 content meta → …2000 App 与 …800 Patch 作为两个独立标题各自安装（可分开查）**。“update 分区”是零售卡带的 SystemUpdate 区（trim 会删），**不是**放 app-update 的地方——之前把它拆到 update 分区是错的，已回退（并删除临时的 `IsApplicationContainer`）。
- **待做（本仓库本地可做）**：`PatchKeygen`（#8 降低 master-key/keygen：keyarea 用低代 kak 重包裹 + 头 0x206/0x220 字段 + rights-id fail-loud；枚举有 stub 但**无后端无 UI**）；`Restore`（#23 把改过的 nsp/xci 还原为原始 NCA）；`Rename/sanitize/romanize`（#12/#18，romanize 需词表数据）；`Config/Settings UI`（MODE0）；`upd_base` UI 暴露 apply-deltas（后端已就绪）。
- **需用户环境（无法本地验证）**：#22 Drive GUI、#24–31 MTP/DBI/Drive/1fichier/nutdb eShop/autoloader —— 依赖主机或在线凭据。
- 每片完成后过闸门：build / 118+ 单测 / run_all / publish。

## ⭐ delta 现状（2026-11，权威，覆盖下方所有旧的 delta 说法）
- **✅ 大 delta 合并端到端已打通并真机验证（LibHac 重开 ErrorOnInvalid）**：`updbase <base> <out> <upd> --apply-deltas` 对 Obakeidoro2 真 Program delta（`2bb91a0b`→base `ffb6bec3`，压缩 RomFS）→ 物化为独立 NCA（2,211,167,744 B，新 id `752eb39d`）→ 合并 NSP 从 1.01GB 增长到 2.21GB（含物化 Program）→ strict hash verify PASS + content-id 一致。**仍 `applyDeltas=false` 默认关**，待用户实机安装验证后可考虑转默认开。
- **配对已解决**：update cnmt `LibHac.Tools.Ncm.Cnmt(stream).ExtendedData.FragmentSets[]` → `NcaIdNew`(delta)/`NcaIdOld`(base)/`DeltaType`(仅 `ApplyAsDelta` 是真 delta)。真机 `itest deltapair` 在 Mario+Rabbids / Obakeidoro / PAC-MAN 均确认；真实配对以 `OpenStorageWithPatch(base,delta,idx)`+`ErrorOnInvalid` 为准（`NcaIdOld` 可能与 base 文件名 id 不同，版本差异）。
- **多段容器重建 `IvfcNcaBuilder.RebuildMultiStreaming` 已实现并已接入 upd_base 的 delta 路径**（`TryMaterializeDeltas` 用它）：未改段原位逐字节复制密文、被移段用 `CreateCounter(fsHeader.Counter,newStart)` 逐块种子变换流式重加密、flat/IVFC 段重建；**关键：Aes128CtrTransform 不跨 TransformBlock 保留计数器→必须每块按绝对偏移重新 seed（之前的 chunk 边界 bug 已修）**。已修 4 个关键 bug：段体 CTR 高 8=fsHeader.Counter；段长>2GiB 用 long；`LevelCount=active+1`；逐块种子变换（修好了 sec1/sec0 的 Hash error）。`ncaembld <c> <nca> 1` identity-rebuild 自检 → reopenAll PASS。
- **已完成**：压缩 RomFS → 未压缩 IVFC 重建的 sec1 reopen `Hash error!` 根因是上述两处（chunk 边界不连续计数器 + 旧强转未压缩的布局），现均修复。真实 Obakeidoro 2.2GB 压缩 Program delta 物化+重开校验全部 PASS。
- **生产安全**：`upd_base` 的 delta 自动合入 `Merge(..., applyDeltas:false)` **默认关闭**；`TryMaterializeDeltas` 逐段 `ErrorOnInvalid` 重开校验，任何不通过即回退**保留 base**→ 绝不产出坏 NCA。已验证的 program-swap 合并不受影响。快迭代样本：IGS `0100BA001821A000`(297MB) `itest ncaembld`。命令：`deltapair/deltamulti/ncaembld/deltainfo/deltascan`。

## Wave 4：多语言 UI（已完成）
- 新增 `wwwroot/i18n.js`：**zh-CN / en-US / ja-JP / ko-KR** 四语字典（123 key，经 node 校验四语 key 完全一致）+ `t()/setLang/getLang/applyI18n/initLang`，未知 key 回退 en-US 再回退 key 本身。
- `index.html`：所有静态文案挂 `data-i18n`/`data-i18n-title`/`data-i18n-placeholder`，头部新增 `<select id="sel-lang">`，引入 i18n.js（先于 app.js）。
- `app.js`：动态文案（actionOptDefs、jobLabel、信息字段、提示、徒章）全改 `t()`；语言切换即时重渲染 + 通过 `PUT /api/settings {language}` 持久化（服务端 AppSettings.Language 早已支持）。加载顺序 initLang（localStorage 优先，否则按 navigator/服务端）。
- 验证：node 逐 locale key parity OK + act.* 齐全 + t() 各语言正确解析；无硬编码 CJK 残留；publish 后 wwwroot 含 i18n.js。

## Wave 5：区域格式化 + 产品化（日志/统一错误）+ delta 引擎原语（已完成）
- **区域化格式（Intl）**：`i18n.js` 新增 `localeTag()/fmtNum/fmtBytesFmt/fmtNumWith/fmtDateTime/fmtDate`，按当前语言用 `Intl.NumberFormat/DateTimeFormat`。`app.js`：`fmtSize`→`fmtBytesFmt`（en `1,234,567 B`、分组随 locale）、文件数 `fmtNum`、任务行新增 `fmtDateTime(finishedAt/createdAt)`、状态标签本地化（`st.Queued/Running/Done/Failed/Cancelled`）；切语言时 `refreshI18n` 连信息面板一起重渲染。node 实测数字/日期分格正确。
- **服务端结构化日志**：新增 `NscbServer/Logging.cs` 的 `NSLog`（无依赖，级别 + 控制台彩色 + 日滚文件 `{base}/logs/nscb-YYYY-MM-DD.log` + 内存 recent 环形）。接入：启动/停止、任务 submit/START/DONE/FAILED/CANCELLED（`JobRunner.Run` 包 try/catch）、API 异常。新端点 `GET /api/logs?limit=`。✅ 已接 WebUI 日志面板：头部 📄 开 `#log-overlay`，列最近日志 + 手动刷新/自动(2s)/复制（app.js openLogs/fetchLogs/toggleLogAuto/copyLogs；i18n logs/logRefresh/logAuto/logEmpty/logCopied 四语）。
- **错误提示统一**：所有端点异常统一走 `ApiError(ex)`（返回 `{error}` 信封，不再 `Results.Problem` 混形）；客户端 `readErr()` 统一抽 `{error|detail}`，`mapError()` 按正则归类为 `errKeys/errFormat/errNoInput/errGeneric`（四语齐全）+ 保留原始详情（job.error 显示归类文案、title 存原文）。
- **delta 引擎（原语）**：新增 `Delta/DeltaApplier`——`OpenPatchedStorage(baseNca, deltaNca, keySet, index, level)` 走 LibHac `Nca.OpenStorageWithPatch`（内部解析 relocation/encryption 树），`Apply()` 返回 patched 逻辑内容（小 NCA byte[] 版）；流式版避开大 NCA 全载入。真机：对 Obakeidoro2 一个 delta fragment 应用 → patchedSize=0xC9988、首 4KB 读取无异常（`itest deltaapply`）。**未做**：把 delta 结果**物化回独立 NCA**（需重建目标 section 的 IVFC 树，Program/Data RomFS 属此）+ 从 update cnmt DeltaContents 精确映射 delta→base 内容 id。

### d4 delta→完整 NCA — **物化原语已实现 + 真机验证**（itest deltatomca）
- `Delta/DeltaToNca`：`Apply(baseNca,deltaNca,keySet,index)` = `OpenStorageWithPatch(...,ErrorOnInvalid)` **整段读**→既是配对又是正确性 oracle（错 base 会抛）；`Materialize` = 对 patch 后内容用 `IvfcNcaBuilder.RebuildWithContent` 写回 base 的 IVFC section → **独立完整 NCA**；`SectionIsIvfc` 判可物化。
- 真机：Obakeidoro2 update 的两个 delta fragment → 对 base control NCA(sec0 IVFC) 物化出独立 NCA，重开 `ErrorOnInvalid` 全读 == patched 内容 → **reopenVerify=True PASS**（legal PFS0 不可物化→跳过）。即 “DeltaFragment 合成完整 NCA” 已成立。
- **upd_base 自动合入的难点**（故未接）：物化后的 NCA 改了 header（section-info/hblock/master）→ **content-id(SHA256(header)) 会变**→需重命名文件 + 同步 cnmt ContentEntry 的 **id + size + 0x20 hash**（不只是 RewriteContentEntryIds 的 id/size），再重建 meta 链；且 Program delta 多为压缩/超大（需 d5 + 流式）。风险高，单独一步做。

## Wave 6：delta → 完整 NCA 物化 — **IVFC 已破解 + IvfcNcaBuilder 已验证**（剩 delta 接入 + 压缩 section）
取证结论：LibHac **无 NCA 写入器**（只有 PartitionFileSystemBuilder/RomFsBuilder/ConcatenationStorageBuilder）。所以 delta→独立 NCA = 自己重建多级 IVFC+ACFS 并在**现有真实 NCA 内就地改尺寸**（类 MetaNcaBuilder，但多 section）。
- 已建：`Crypto/IvfcTree.cs`（多级 IVFC：level i 的 salt=`HMACSHA256(ASCII("HierarchicalIntegrityVerificationStorage::"+{Master,L1..L5}[i-1]), saltSource)`，bs=1<<step[i-1]，块数=ceil(size[i-1]/bs)，末块零填充）+ itest `ivfcselftest <container> <entry|auto> [idx]`：读真实 NCA 的 IVFC 头（LevelCount/steps/offsets/sizes/saltSource）并用**存储的各 level 字节**逐级重算对比。
- 真机取证到的 IVFC 头形状（例：Hyrule DLC data NCA sec0）：`levels=7, level0Size=0x4000, steps=[14×6,0], sizes=[0x4000,0x4000,0x4000,0x4000,0x4000,0x264,0x0]`——各级 region 固定填充到 0x4000（不是紧算），顶层 size=0x264。
- **✅ IVFC 已破解**：只读 NCA 的哈希 = **纯 SHA-256、无 salt**（关键：`IntegrityVerificationStorage.CalcBlockHash` 只读走 `GenerateHash(block)`；salt 仅可写路径且会置 validation bit，故非真机存的格式）。之前 80 组合猜 salt 均错——因为就不该加 salt，且 region 顺序也猜反。真实布局：`Nca.InitIvfcForRomFs` → region index 0=top(最低偏移)、content=最高非零偏移区；region[i]=SHA256-blocks(region[i+1], 块=1<<step[i])；header MasterHash=SHA256-blocks(region0, 1<<step0)。header IVFC 字段基址=FsHeader+8：LevelCount@+12、MasterHashSize@+8、saltSource@+160、masterHash@+192、level[i]@+16+i*24(off i64,size i64,blockStep i32)。
- **✅ 已实现 + 真机验证**：`Crypto/IvfcTree`（Build：content+step[]+activeCount → regions top..content + master；HashRegion 纯 SHA 末块零填充）+ `Ncm/IvfcNcaBuilder.RebuildWithContent(ncaBytes,keySet,idx,newContent)`（重排 region、改 level off/size、写 master、section-info end block、hblock[idx]、重加密 header XTS + section AES-CTR，保留 0xC00..secStart 低 section）。itest：`ivfcselftest`（边发现→真机 chainComplete=True）、`ivfcrebuild`（unchanged+grown 全读 ErrorOnInvalid；Hyrule 0x264 与 Mario+Rabbids **2.5MB 多块** 均 PASS）。
- **✅ 流式重建（大数据量能力）**：`IvfcNcaBuilder.RebuildStreaming(IStorage src,int idx,IStorage content,long contentLen,KeySet,Stream dst)`——不把 NCA/内容全载入内，仅留小 level 区 + 逐块 per-absolute-offset AES-CTR（`itest ivfcstream`：与内存版**长度相同、reopenVerify=True**，差异仅在未读 padding）。`Delta/DeltaToNca.MaterializeStreaming(base,delta,idx,keys,dst)`（OpenStorageWithPatch → RebuildStreaming）——`itest deltastream` 对真机 base 存储流式物化 reopenVerify=True。→ 多 GB / 压缩 section 现可流式处理。
- **未做（大 Program delta 自动入 upd_base）**：`TryMaterializeDeltas` 仍用内存版且限 <64MB base（防暴力配对在 GB 级逐对全读太慢）。要接大 Program：需从 update cnmt 的 DeltaContents **精确映射 delta→base 内容 id**（而非暴力）+ 流式物化到临时文件 + 用 newId/size/hash(SHA256(NCA)) 重指 cnmt，最后**真机安装验证**（用户有设备）。
- **剩余**：①**受支持范围已加硬护栏（宁失败不产出坏 NCA）**：`IvfcNcaBuilder` 现在拒绝非 NCA3 magic 与 `ExistsCompressionLayer()` 的 section（抛 NotSupportedException）。`ivfcrebuild` 的 `IvfcContent` 改为走 OpenStorage（取逻辑/解压内容，压缩源物化为未压缩 RomFS）。非压缩 NCA3 样本 Hyrule(0x264)/Mario(2.5MB)/Obakeidoro control 均 OK。
  - **未解异例**：Smash DLC 某 NCA（`ivfcgeom` 已排限）——与能过的 Hyrule **几何完全一致**：compressed=False、单 section(0x18000)、LevelCount=7、masterHashSize=32、各级 off/sz/bs 全同，唯一差异是 content 字节 0x26C vs 0x264。Hyrule 同代码 unchanged+grown 均 PASS，Smash 却 `ResultFsNonRealDataVerificationFailed(Hash error!)`。**几何/压缩/NCA版本均不是原因**——属数据相关的 ivfcrebuild 测试路径异例（生产路径 `deltatomca` 已验证可用，不受影响）。下一步若要查：逐 region 字节 diff“重建后 vs 原存”定位首个分歧 level。真实 Program delta = 超大(2GB)+压缩 → 仍需流式重建 + 真机验证。②**✅ d4 已接入 upd_base（受护栏、子集）**：`UpdBaseMerger.TryMaterializeDeltas` 对每个小 base NCA（非 cnmt、<64MB→不会命中超大 Program）×小 update NCA×section0/1，`DeltaToNca.Materialize` 成功且重建后 ErrorOnInvalid 重开读回通过→物化；新 content-id=SHA256(NCA)[0:16]，`ApplyMaterialized` 重写 cnmt record 的 hash/id/size。Obakeidoro2 真机 updbase：strict hash PASS + content-id consistency PASS，输出变小→已真实替换 base control。失败配对自动回退。待完：超大/压缩 Program delta（d5）。
  - **⚠️ 更正（重要）**：`deltainfo` 实测——Obakeidoro 里早先被“物化”的 `a7ce2cec`(type=3=Manual)、`4de7eb8f`(type=5) 根本**不是 delta**（真 delta 是 8 个 type=DeltaFragment 条目）。`OpenStorageWithPatch` **不校验配对**，对错误 base 也能产出自洽 NCA → 之前的“deltatomca/✅ d4 PASS”是**误配对假象**（reopen 只验自洽）。且真 delta NCA 的 `Header.ContentType` 不等于被替换 base 的类型 → 按类型配对命中 0（安全，但也说明无法自动定目标）。因此 **upd_base 的 delta 自动合并默认关闭**（`Merge(..., applyDeltas:false)`）：不拿不可靠配对产错文件；保留已验证的 program-swap 合并。要真正打通需先解析 delta applied-info 的 base-target 哈希（需 delta 格式规范）或用 cnmt DeltaContents 权威映射。
- **已穷举排除（别再重跑）**：对 Hyrule bonus DLC data NCA (fmt=Romfs enc=AesCtr hash=Ivfc, saltSource=**全 0**) 的 level1 首块，试过 {6 个 salt 字串 Master/L1..L5}×{HMAC(key=str,msg=src) 与 (key=src,msg=str)}×{salt前置、后置、无 salt}×{level0 取 OpenRawStorage(false) 解密、OpenRawStorage(true) 加密、OpenStorage 验证后明文} ≈ 80 组合，均不等于存储值 expected 78D4591C00F1ABF1。=> 不是 salt 字符串/顺序/拼接问题，而是**我参与哈希的 level0 字节/区间划分本身不对**（很可能 ACFS 把 control-area/filesystem-header 区域也算进了 level0 起始，或 OpenRawStorage 的解密视图与建树时的字节不一致）。
- **下一步用确定性方法（不靠猜）**：运行时用反射从 LibHac 已构造的 `HierarchicalIntegrityVerificationStorage` 里拿到每级真实的 `IntegrityVerificationStorage._hashSalt` 字节，或用 `nca.OpenStorage(idx, ErrorOnInvalid)` 的底层 Levels 切片，反推它到底拿哪段字节+哪个 salt 去 SHA256——一次就能定锤。`itest ivfcselftest` 已留可编译、故意 FAIL 的脚手架供此用。
- 验证环境：用户**有真机/模拟器可安装验证**（故目标不止 LibHac 重开，最终要能装）。小 IVFC NCA 需其 title key 在 keyset（旧 title.keys 缺许多新 DLC）；可用样本：Smash/Hyrule/FireEmblem 的 bonus DLC data NCA、Obakeidoro 的 delta（patchedSize 0xC9988）。
- 下一步：用 `ivfcselftest` dump level0/level1 首块字节 + 手算 SHA256 变体定位 salt/preimage 约定；通过后接 d3 NCA 组装 → d4 delta 配对/接入 → d5 严格重开 + 真机装验。



## Wave 2 交付物（已完成，均已对真实样本验证）

| 项 | 文件 | 验证 |
|---|---|---|
| XciEditor / XciTrimmer（trim/supertrim/eraseDeltas）| `Xci/XciEditor.cs` | WarioWare(v0) 三操作输出均可 probe 读回；Ring Fit(含 update)supertrim 去重后 3.99→3.88 GB 结构可读 |
| UpdBaseMerger（upd_base，-dc 语义）| `Packaging/UpdBaseMerger.cs` | STEINS;GATE REBOOT base+upd 合并：program NCA 换成 update 内容、控制/票务/元数据保留、NSP 结构可读 |
| NpdmInfoReader（NPDM 访问控制）| `Info/NpdmInfoReader.cs` | 对真实 Program NCA 解析出 title id / allowed-id 范围 / ACID flags / service 列表 |
| FileJoiner（FAT32 分卷 + zip）| `Joiner/FileJoiner.cs` | split→join 往返一致；单条目 zip 解出字节一致 |
| TicketAccountPatcher（remlinkacc）| `Patching/TicketAccountPatcher.cs` | 真实 common ticket 0x198 处 8 字节清零（common 本就为 0，no-op 安全）|
| Parallelizer（并行 NSZ）| `Compression/Parallelizer.cs` + `Nsz/NszConverter.cs` | `NspToNsz(..., parallelism)` 并行输出与串行**逐字节一致** |

全部已接入：`NscbJobs.JobType`（UpdBase/ReadNpdm/JoinFile/RelinkAccount）、`NscbServer/Program.cs` 的 `JobRunner`、`wwwroot/index.html`+`app.js`、`tools/itest/Program.cs`（`updbase/readnpdm/remlinkacc/joinfile/nszpar/trimxci/supertrim/erasedeltas`）、`tools/itest/run_all.py`（用例 9–12）。文件浏览器现已显示 `.zip` 与 `.00/.01` 分卷。

## 本轮修复的关键 bug（务必知悉）

- **`XciBuilder.Build` 分区布局错误**：旧代码把 update/normal/secure 三个 header **连续写完**，再依次写 update data、secure data。当 update 分区**非空**时，update data 落在 secure header 之后，导致 root header 记录的分区偏移全部错位 → 输出 XCI 报 “Not an HFS0 container”。正确布局是每个分区 header 紧跟其 data：`rootHdr, updateHdr, updateData, normalHdr, secureHdr, secureData`。已修正并加回归单测 `BuiltXci_WithNonEmptyUpdatePartition_IsReadable`。Wave 0/1 从未走过“非空 update 分区”路径，所以此前没暴露。
- **SuperTrim 语义**：改为按 update cnmt 的**精确 TitleId** 分组保留最高 TitleVersion，并按各 cnmt 的 `ContentEntries` NCA-id 保留被引用内容（不再错误地只留 cnmt 自身或按 base 掩码误删同游戏多个 update）。读不到的 cnmt 一律保留，避免丢数据。

## 本轮取证到的新事实（Wave 3 直接可用，勿再猜）

- **main.npdm 位置**：在 **Program NCA 的 ExeFS（section 0）**，文件名就是 `main.npdm`（同级还有 main/rtld/sdk/subsdk0）。NPDM 头以 ASCII `META`@0x0 开头（NSCB `pyNPDM` 的布局属实，不是 `NPMI`）；`ACI0`/`ACID` 子块用 magic 扫描定位最稳。
- **ticket account id @ 0x198（8 字节）**：对真实 common ticket 验证该区域本就全 0，清零安全。要彻底确认可对一张**个人票**（account id 非 0）再跑一次 remlinkacc 比对；目前实现按此偏移纯字节清零，不重签（Tinfoil 安装不校验该签名）。
- **UpdBase 的 cnmt 版本**：合并后 Meta/cnmt 仍是 base 的（TitleVersion 不变），只有 program NCA 换成了 update 内容、且保留 base 的文件名（content-id）。这是**刻意绕过 hash-chain 重建**（依赖 Wave 3 的 header XTS 写回）。Tinfoil 可装；严格校验器会报 cnmt 内容 hash 不符。Wave 3 打通 header 写回后，应改为：把 update 的 cnmt ContentEntries（新 program id + TitleVersion）写进 base Meta NCA 并重建 section0 哈希链 → 才是完全正确的 upd_base。

## Wave 3 ✅ 已完成：NCA header XTS 破解

**已攻克**（本轮，反编译 LibHac 0.19.0 得出，非猜测）：`XtsHelper` 之前 sector 1+ 与 LibHac 不符的唯一根因是 **扇区号字节序**——LibHac `Aes128XtsTransform.FillArrayFromSector` 把 sector 以 **16 字节大端**（byte[15]=LSB）写入 tweak 输入，旧代码用的是「低 8 字节小端 u64」。扇区 0 全 0 时两种编码相同（所以以前只有 sector 0 对得上），扇区 ≥1 立刻错位。

验证：itest 命令 `xtsverify <container> <entry>` 用 LibHac 公开类 `LibHac.Tools.FsSystem.Aes128XtsTransform`（同一套 header 解密原语）当 oracle，对真实 GameCard NCA 的整个 0x400 header 比对——**逐字节相等**，且 0x200 处解出 ASCII `4E-43-41-33` = **“NCA3”** magic（上一轮死活解不出的就是这个）。已入 run_all 用例 13。

关键事实（LibHac 反编译确认，勿再猜）：
- **XTS 覆盖整个 0xC00（3072字节）header**（`NcaHeader.HeaderSize=0xC00`、`HeaderSectorSize=0x200`），按版本 digit（ASCII '3'/'2'/'0' 在 **0x203**）决定后段 data-unit：sector 0/1 恒为 0/1；**Nca3**→块 2..5 用 data-unit=2..5；**Nca2**→块 2..5 全用 data-unit **0**；Nca0→只处理前 2 个扇区。`XtsHelper.TransformNcaHeader` 已复刻。
- `HeaderKey`(AesXtsKey,0x20)：key1=[0..0x10]、key2=[0x10..0x20]；`T=AES-ECB(key2, 16字节大端 sector)`；每 16B 块 GF **左移+0x87**。
- 字段偏移：0x0..0xFF=Signature1、0x100..0x1FF=Signature2（均非 ASCII）、0x200="NCAx" magic、**0x204=DistributionType**、0x205=ContentType、0x206/0x207=keyGen/keyAreaIdx、0x210=TitleId、0x300=KeyArea(0x100)、**FsHeader 4×0x200 在 0x400..0xBF**（LibHac `GetFsHeader` 会校验其 SHA256）。**DistributionType 枚举：0=Download、1=GameCard**（LibHac/hactool 权威值，勿反过来）。

## Wave 3b（header 写回 + 哈希链重建）

✅ **setcgame / seteshop 已完成**：`XtsHelper.TransformNcaHeader`（0xC00 全区加解密）+ `NcaPatcher.SetDistribution`（解 0xC00 → 改 0x204 → 重加密写回）+ `ContainerPatcher.SetDistribution`。只动 sector1 的 0x204，不碰 FsHeader SHA 链。验证：itest `setdist` 改后 LibHac 重开 + `GetFsHeader(0)`（校验 FsHeader SHA）→ PASS（run_all 用例 14）。已接 JobType `SetCgame`/`SetEshop` + WebUI。
> 踩过的坑：encrypt 路径必须**在加密任何扇区之前**先读版本 digit（0x203 在 sector1，先加密 sector1 再读就是乱码→后段用错 data-unit→FsHeader SHA 失败）；decrypt 相反。

✅ **hash-chain 重建 + set_cnmt_titleid / set_cnmt_version 已完成**（本轮）：新类 `Patching/NcaCnmtPatcher`（`PatchCnmt` + `SetCnmtTitleId`/`SetCnmtTitleVersion`）+ `ContainerPatcher.SetCnmtTitleId/Version`（整容器，拷到输出后改首个 .cnmt.nca）。链路：解 0xC00 header + 解 section（AES-CTR）→ 改 cnmt 字节 → 重建 Flat 哈希表（每 content block 一个 SHA256，PartitionFs 风格：末块只 hash 真实字节不补零）→ master=SHA256(整表) 写进 FsHeader(integrity info 在 FsHeader块+8) → hblock=SHA256(FsHeader块0x200) 写进 header[0x280+idx*0x20] → section 重加密 + header 重加密（`TransformNcaHeader`）写回。
> PartitionFs(Sha256) 方案已由 itest `hashcheck` （对**未修改** section 重算 master == 存储值）先行锁定；content=GetLevelOffset(1)/Size(1)、table=GetLevelOffset(0)/Size(0)、block=info.BlockSize（均为 section 内相对偏移，因样本而异，运行时读）。已接 JobType `SetCnmtTitleId`/`SetCnmtVersion` + WebUI。验证：itest `setcnmt ... ver/tid/rsv` 改后用 `IntegrityCheckLevel.ErrorOnInvalid` 重开并**完整读回 cnmt**（逐块验 hash）→ PASS（run_all 用例 15/16）。

✅ **RSV 严格化已完成**（本轮）：`NcaCnmtPatcher.SetCnmtRequiredSystemVersion`（RSV 在 cnmt+0x28）；`ContainerPatcher.PatchCnmtRsv` 已改走严格链重建（仅处理 .cnmt.nca，PFS0/Sha256），不再只改明文。itest `setcnmt ... rsv 268435456` → RSV 读回 4.0.0 且严格验 hash PASS（run_all 用例 17）。

✅ **RTRNCA 已完成并验证**（本轮）：重写 `NcaPatcher.RemoveTitleKey`——**只改 0xC00 header**（不再整段载入，修好了 >2GB program 的 int overflow 与旧代码误把 0x204 当加密标志、对密文 FsHeader 求 hash 的 bug）。算法照抄 NSCB `removeTitleRightsnca`：不动内容，只把 KeyArea(0x300..0x340)=`AES-ECB(areaKey, titleKey*4)`、清 RightsID(0x230)，再 `TransformNcaHeader` 重加密 header。**关键坑**：areaKey = `KeySet.KeyAreaKeys[GetMasterKeyRevision(Header.KeyGeneration)][Header.KeyAreaKeyIndex]`，其中 `Header.KeyGeneration = max(hdr[0x206], hdr[0x220])`（不是只取 0x206！）、`GetMasterKeyRevision(k)=k==0?0:k-1`、`KeyAreaKeyIndex=hdr[0x207]`。用错 keyGen 会导致 reader 派生出错的 key（实测已修正）。验证：itest `rtrnca` 用**不含 title.keys 的 prod-only keyset** 重开转换后的 NCA，`GetDecryptedKey(0)==原始 titleKey` 且 HasRightsId=False → PASS（run_all 用例 18）。`ContainerPatcher.RemoveTitleKeyCrypto` 也去掉了旧的 raw-0x230 密文嗅探。已接 JobType `RemoveTitleKey`（enum 早有，补了 server case + WebUI）。

## ✅ 可变尺寸 Meta NCA 重建 + upd_base 统一重构（已完成并验证）

- 新类 `Ncm/MetaNcaBuilder.RebuildWithCnmt(ncaBytes, keySet, cnmtFileName, newCnmt)`：把 section 0 的 PFS0 重建（换入新 cnmt、保留其它文件）→ 重生 Flat 哈希表（PartitionFs 风格）→ master/hblock → 改 section-info end block（表在 **0x240**+idx*16，start@+0 end@+4）→ section 重加密(AES-CTR) + header 重加密(XTS) → 返回变长新 NCA。关键常量：SectionEntries@0x240、FsHeaderHash@0x280、FsHeaders@0x400、BlockSize@0x200；Sha256 integrity（FsHeader+8）：master@+0、blockSize i32@+0x20、level[0]@+0x28(table off/size)、level[1]@+0x38(content off/size)。cnmt 内容记录 0x38：hash@+0、ncaId@+0x20、size(u48)@+0x30、**type@+0x36**、idOff@+0x37；内容表起始 = (flag@0x1C?24:32)+TableOffset(u16@0xE)，count u16@0x10。
- `UpdBaseMerger` 重写为**统一路径**：解析 base/update cnmt → 合并内容记录（swappable 类型用 update 整条记录替换，base 没有的 update 可安装类型 append）→ RebuildCnmt（带新版/RSV）→ MetaNcaBuilder 重建 Meta NCA → 写 NSP（swappable 文件按 update id 命名，新增类型文件也加）。条目数变多也能处理（尺寸自动变）。
- 自检：itest `metarebuild`——(a) 不换内容重建 → 严格重开后读回 cnmt **字节相同**；(b) 多一条内容重建 → 严格重开 count+1 且 hash 链过验 → PASS（run_all 用例 19）。
- 真机：Obakeidoro2 delta update 走新统一路径 updbase → version=262144、strict hash PASS、content-id 全一致 → PASS。

> 局限：仍不做 **delta 应用**（把 DeltaFragment 合入 base NCA）——当前策略是保留 base 非可交换内容 + 换入 update program（与 -dc 一致但已无 id 不一致）；若 update 新增 base 没有的 Program/Data 会自动 append 条目（可变尺寸已支持）。带大量 delta 且需应用为完整 NCA 的极端情况仍待 delta 引擎。

剩余待做（均为大特性，非阻塞）：
1. **delta 应用引擎**（DeltaFragment → 完整 NCA）。
2. 多语言界面文案的进一步本地化（日期/数字格式、更多区域）。

> 注：**NAX0** 的 AES-128-XTS 是另一套（`Crypto/Nax0Xts.cs`：sector=0x4000、GF **右移+0xE1**，含 CTS，已对 Python 参考逐字节验证），与 NCA header（sector=0x200、GF 左移+0x87）**互不相通**，别混用。

## 项目状态快查

```bash
cd /repo/NS/NSC_BUILDER/nscb-web
dotnet build -c Release -v q && dotnet test -c Release -v q   # 109 单测
# 51 MB 单文件：src/NscbServer/bin/Release/net10.0/win-x64/publish/NscbServer.exe
# 集成测试：python3 tools/itest/run_all.py  （需 /mnt/E 游戏样本 + /mnt/D prod.keys + title.keys）
```

## 关键 API 备忘

| 需求 | 已有实现 |
|---|---|
| HFS0/分区/XCI header 读写、**含非空 update 分区布局** | `Formats/Hfs0Builder.cs`、`Formats/Hfs0.cs`、`Formats/XciBuilder.cs` |
| XCI 分区读入内存 + 按过滤列表重建 | `Xci/XciEditor.cs`（`Read` / `Rebuild` / `XciTrimmer`）|
| XCI header AES-CBC | `Patching/NcaPatcher.PatchXciGameInfoFwVersion` |
| cnmt 读（Meta@section0）| `Xml/CnmtXml.ReadFirstCnmt(Nca)`、`Info/TitleInfoService.TryReadCnmt` |
| 按内容类型从容器抽 NCA | `Extraction/ContentExtractor.cs` |
| NSP/NSZ/XCI/XCZ 统一条目视图 | `Formats/ContainerReader.ReadEntries` |
| upd_base（-dc 语义，绕过 hash chain）| `Packaging/UpdBaseMerger.cs` |
| NPDM 访问控制读 | `Info/NpdmInfoReader.cs` |
| 分卷/zip 合并 | `Joiner/FileJoiner.cs` + `Splitting/Fat32Splitter.cs` |
| remlinkacc | `Patching/TicketAccountPatcher.cs` |
| NAX0 AES-128-XTS（sector=0x4000, GF 右移+0xE1, 含 CTS）| `Crypto/Nax0Xts.cs`（与 `XtsHelper` 的 NCA-header 约定相互独立）|
| **NCA header AES-128-XTS（sector=0x200, GF 左移+0x87, 已对齐 LibHac）**| `Crypto/XtsHelper.cs`（`TransformNcaHeader` 走整个 0xC00；验证 `itest xtsverify`）|
| setcgame / seteshop（改 header 0x204 分布类型）| `Patching/NcaPatcher.SetDistribution` + `ContainerPatcher.SetDistribution`（验证 `itest setdist`）|
| hash-chain 重建 + set_cnmt_titleid/version + cnmt content-id 重写 | `Patching/NcaCnmtPatcher`（`PatchCnmt`/`RewriteContentEntryIds`）+ `ContainerPatcher.SetCnmt*`（验证 `itest hashcheck`/`setcnmt`/`updbase`）|
| 可变尺寸 Meta NCA 重建 + upd_base(1:1/grow) | `Ncm/MetaNcaBuilder` + `Packaging/UpdBaseMerger`（`itest metarebuild`/`updbase`）|
| RTRNCA（title-key→null-crypto，只改 0xC00 header）| `Patching/NcaPatcher.RemoveTitleKey` + `ContainerPatcher.RemoveTitleKeyCrypto`（验证 `itest rtrnca`）|
| 并行 NSZ | `Compression/Parallelizer.cs`（`NszConverter.NspToNsz(..., parallelism)`）|
| 单文件发布 | `dotnet publish src/NscbServer -c Release -r win-x64 --self-contained true` |

## 已知的坑

1. `LibHac.Fs.DirectoryEntry.Name` 是 `FixedArrays.Array769<byte>`，用 `.ItemsRo` + NUL-scan。
2. LibHac 枚举从 1 开始：`NcaFormatType.Pfs0=1` / `NcaHashType.None=1` / `NcaEncryptionType.None=1`。
3. Meta NCA 的 cnmt 在 **section 0**（PFS0），不是 Data=1。
4. Control NCA 的 NACP 文件名是 `control.dat`（也接收 `.nacp`）。
5. NCZ 的 cryptoKey = title key（有 rights）或 `GetDecryptedKey(2)`（无 rights），**不是** `GetDecryptedKey(fsIdx)`。
6. NCZ 覆盖整个 raw FS section（含 IVFC 表）。
7. `AesXtsStorage`（部分 LibHac 版本类型）是 stub 抛 not implemented；但 `Aes128XtsStorage` / `Aes128XtsTransform`（public，`LibHac.Tools.FsSystem`）**可用**，header 解密就走后者，可当 oracle。
8. **（已解决）** `XtsHelper` 之前 sector 1+ 不匹配的唯一根因是扇区号字节序：必须 **16 字节大端**（byte[15]=LSB），不是低 8 字节小端 u64。现已逐字节对齐 LibHac（`itest xtsverify`），可安全写回 header。
9. Program NCA 的 ExeFS/RomFS 打开需要 **rights-id 对应的 title key**；缺失时 `OpenFileSystem` 抛 `MissingKeyException`（NPDM/upd 读会安全跳过）。大 program NCA（数 GB）**必须**用 `LocalStorage+SubStorage` 流式打开，别 `new byte[size]` 整块读（会 OOM/overflow）。
10. **XCI 每个 HFS0 分区的数据必须紧跟其 header**；root header 的分区偏移据此计算（见上文关键 bug）。
