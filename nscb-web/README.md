# NSC_BUILDER Web UI

Nintendo Switch 格式工具，C#/.NET 10 + LibHac 重写版，浏览器操作。

## 功能

对齐原 NSC_Builder 的本地处理功能（在线/主机类如 MTP/DBI、Google Drive、1fichier、nutdb eShop、SX autoloader 不在本项目范围）。

| 分类 | 操作 |
|------|------|
| 信息 | 查看信息（标题名/titleID/固件要求/内容清单/图标，JSON）、读取 NACP/CNMT、NPDM、数据库批量导出（CSV/TSV/JSON/TXT，可扫描文件夹） |
| 转换 / 打包 | NSP ↔ XCI、NSZ / XCZ 压缩与解压（solid+block，往返字节一致）、多文件打包为 XCI |
| 拆分 / 合并 | 多内容拆分为单包、FAT32 分卷 (.00/.01…) 与合并、分卷连接 (join) |
| 降要求 | 降固件 RSV、降密钥版本 keygen（标准加密 NCA，rights-id 保留） |
| titlekey | 去 titlekey 加密 (RTRNCA)、改回实体卡/下载分布 (setcgame/seteshop) |
| 更新处理 | 移除 delta、**upd_base**：把 update 合入 base 生成单包（`--apply-deltas` 可选物化 BKTR delta，默认关，与 NSCB 一致） |
| XCI 整理 | 去 update 分区 (trim)、超级整理 (supertrim) |
| 校验 / 提取 | verify（检测 NSCB 改动）、按类型提取内容 / 明文提取、生成 cnmt.xml |
| 命名 | 依内容重命名 + 非法字符净化（NSCB 命名 `{名} [titleID][v版本][Base/UPD/DLC]`） |
| 还原 | restore：把本工具改过的文件（分布/密钥版本/rights-id）改回原始，用 NCA 的 RSA-PSS 签名自证 |
| 其他 | CNMT 改 titleID/版本、relink account |

密钥文件由用户提供，程序不内置任何密钥。

## 快速开始

### Windows

1. 安装 [.NET 10 SDK](https://dotnet.microsoft.com/download)（仅首次构建需要）
2. 双击 `start.bat`  
   首次运行自动 publish，之后直接启动。浏览器自动打开。

### Linux / macOS

```bash
chmod +x start.sh
./start.sh
```

### 手动构建 & 发布单文件 exe（win-x64）

```bash
dotnet publish src/NscbServer -c Release -o dist/win-x64
# 输出: dist/win-x64/NscbServer.exe（单文件自包含；win-x64 / 单文件 / 自包含 等选项已在 NscbServer.csproj 中设定，无需重复传参）
```

`NscbServer.exe` 是单文件自包含可执行程序，WebUI 静态资源内嵌其中，拷贝即用。

## 配置密钥

服务启动后浏览器访问 `http://127.0.0.1:54321`，点击右上角 ⚙ 设置：

- **prod.keys**（必需，也是唯一的密钥输入）：`header_key` + `master_key_NN`（任意代，无上限）
- **无需 title.keys 文件**：各游戏的 rights-id title key 由程序在打开容器时从其自带 ticket 现场推导（`titlekek` 由 prod.keys 的 `master_key` 得出）。个人/设备绑定票券不支持（与 NSCB/NSGManager 一致）。
- **titles.json**（可选，仅元数据）：提供标题名/发行商/类型/地区等游戏信息，**不参与取密钥**。

配置保存于 `settings.json`（与程序同目录），下次启动自动加载。

## 开发

```bash
# 克隆仓库后
cd nscb-web
dotnet build          # 全量编译
dotnet test           # 运行单元测试（207 个，合成数据，不依赖真实样本/密钥/网络）
dotnet run --project src/NscbServer   # 开发模式（热重载）
```

### 真实样本集成测试

`tools/itest/run_all.py` 在本地有 Switch 样本与 prod.keys 时执行端到端验证：

```bash
# 1) 先构建 itest 工具
dotnet build tools/itest/itest.csproj
# 2) 修改 run_all.py 顶部的 PROD_KEYS / 样本路径
python3 tools/itest/run_all.py
```

覆盖 29 项：NSZ↔NSP 字节对齐 nsz 参考、NSP↔XCI 回环、NSP→NSZ→NSP 回环、FAT32 分卷/合并、真实 XCI 结构读取、Info 提取、RSV 补丁、NCA Meta 哈希链重建、去 titlekey、**delta 合并（upd_base --apply-deltas 端到端 strict 校验 + 体积增长）**、**还原往返（GameCard→Restore 得回字节相同 NSP）**、**降 keygen / 重命名 / 数据库导出**等。

### 项目结构

```
nscb-web/
├── src/
│   ├── NscbCore/       # 格式核心库（无 Web 依赖）
│   │   ├── Crypto/     # AES-XTS/CTR、IVFC 哈希树
│   │   ├── Keys/       # prod.keys 加载 + 固件/keygen 映射表
│   │   ├── Formats/    # PFS0/HFS0/XCI/NCA/CNMT/NACP/NPDM/RomFS 读写 + 转换
│   │   ├── Ncm/        # IVFC/Meta NCA 构建、多段容器重建
│   │   ├── Nsz/        # NCZ solid/block 压缩解压
│   │   ├── Delta/      # BKTR delta → 物化为独立 NCA
│   │   ├── Patching/   # RSV 降级 + keygen 修改 + 去 titlekey + restore
│   │   ├── Info/       # 标题信息提取 + 数据库批量导出
│   │   ├── Packaging/  # 多文件打包为 XCI + upd_base 合并
│   │   ├── Verify/     # 完整性校验 / 检测 NSCB 改动
│   │   ├── Splitting/  # FAT32 分卷 + 多内容拆分
│   │   ├── Joiner/     # 分卷连接
│   │   └── Renaming/   # 依内容重命名 + 净化
│   ├── NscbJobs/       # 任务引擎（队列/进度/取消）
│   └── NscbServer/     # ASP.NET Core minimal API + SSE + wwwroot/ (WebUI)
├── tests/
│   └── NscbCore.Tests/ # xUnit（合成结构，不依赖真实游戏样本）
├── tools/
│   └── itest/          # 真实样本集成测试（run_all.py + ncz_ref.py + 诊断命令）
├── start.sh / start.bat
└── README.md
```

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/browse?path=` | 服务端目录浏览（按扩展名过滤）|
| GET | `/api/info?path=` | 文件信息 JSON |
| GET | `/api/info/icon?path=` | 游戏图标 |
| POST | `/api/jobs` | 提交任务 `{type, inputs, options}` |
| GET | `/api/jobs` | 任务列表 |
| GET | `/api/jobs/{id}` | 任务详情 |
| DELETE | `/api/jobs/{id}` | 取消任务 |
| GET | `/api/events` | SSE 实时进度流 |
| GET/PUT | `/api/settings` | 密钥路径、输出目录配置 |

服务仅监听 `127.0.0.1:54321`。

## 依赖

- [LibHac 0.19](https://github.com/Thealexbarney/LibHac)（NuGet）
- [ZstdSharp.Port 0.8.8](https://github.com/Hypersect/ZstdSharp)（NuGet，纯 C# zstd）
- 前端：原生 ES Module SPA，零构建链、零 CDN

## 许可

参考原 NSC_BUILDER（MIT），本项目同样以 MIT 许可发布。  
Nintendo Switch 是任天堂的商标。本项目仅供合法的自有备份文件处理使用。
