# NSC_BUILDER Web UI

A Nintendo Switch format tool — a clean-room rewrite in C# / .NET 10 + LibHac, driven from a browser UI.

Language: **English** | [简体中文](README.zh-CN.md)

## Features

Mirrors the local processing features of the original NSC_Builder. Online / host-integration features — MTP/DBI, Google Drive, 1fichier, nutdb eShop, SX autoloader — are out of scope for this project.

| Category | Operations |
|---|---|
| Info | View info (title name / titleID / firmware requirement / content manifest / icon, as JSON), read NACP / CNMT / NPDM, batch database export (CSV/TSV/JSON/TXT, can scan a folder) |
| Convert / Pack | NSP ↔ XCI, NSZ / XCZ compress & decompress (solid + block, byte-exact round-trip), pack multiple files into an XCI |
| Split / Join | Split a multi-content pack into single packages, FAT32 split (.00/.01…) and merge, split-file join |
| Lower requirements | Lower firmware RSV, lower key generation (keygen) on standard-crypto NCAs (rights-id kept) |
| Title key | Remove title-key encryption (RTRNCA), flip cartridge / download distribution flag (setcgame / seteshop) |
| Update handling | Remove deltas; **upd_base**: merge an update into the base to build an all-in-one package (`--apply-deltas` optionally materializes BKTR deltas, off by default, matching NSCB) |
| XCI tidy | Drop the update partition (trim), super-trim (keep the latest update) |
| Verify / Extract | Verify (detects NSCB modifications), extract contents by type / extract plaintext, generate cnmt.xml |
| Rename | Rename from content + sanitize illegal characters (NSCB naming `{name} [titleID][vVersion][Base/UPD/DLC]`) |
| Restore | Restore files modified by this tool (distribution / keygen / rights-id) back to original, self-proven via the NCA RSA-PSS signature |
| Other | Change CNMT titleID / version, re-link account |

Key files are provided by the user; the program bundles no keys.

## Quick start

### Windows

1. Install the [.NET 10 SDK](https://dotnet.microsoft.com/download) (needed only for the first build).
2. Double-click `start.bat` — it auto-publishes on first run and then launches; the browser opens automatically.

### Linux / macOS

```bash
chmod +x start.sh
./start.sh
```

### Manual build & publish the single-file exe (win-x64)

```bash
dotnet publish src/NscbServer -c Release -o dist/win-x64
# Output: dist/win-x64/NscbServer.exe (single file, self-contained;
#         win-x64 / PublishSingleFile / SelfContained etc. are already set in NscbServer.csproj — no flags needed)
```

`NscbServer.exe` is a single-file, self-contained executable with the Web UI embedded — copy it anywhere and run.

## Configure keys

Once the service starts, open `http://127.0.0.1:54321` in a browser and click the ⚙ (top-right):

- **prod.keys** (required — and the *only* key input): `header_key` + `master_key_NN` (any generation, uncapped).
- **No title.keys file is needed**: each title's rights-id title key is derived on demand from the container's own bundled ticket (`titlekek` comes from the `master_key` in prod.keys). Personal / device-bound tickets are not supported (same as NSCB / NSGManager).
- **titles.json** (optional, metadata only): supplies title name / publisher / genre / region, etc. It is **not** used for key extraction.

Settings are saved to `settings.json` (next to the program) and reloaded on the next start.

## Development

```bash
# after cloning
cd nscb-web
dotnet build          # full compile
dotnet test           # unit tests (207, synthetic data; no real samples / keys / network required)
dotnet run --project src/NscbServer   # dev mode (hot reload)
./clean.sh            # remove build & temp artifacts (bin/obj/dist/...); Windows: clean.bat
```

### Real-sample integration tests

`tools/itest/run_all.py` runs end-to-end verification against real Switch samples and prod.keys when they are present locally:

```bash
# 1) build the itest tool first
dotnet build tools/itest/itest.csproj
# 2) edit PROD_KEYS / sample paths at the top of run_all.py
python3 tools/itest/run_all.py
```

Covers 29 checks: NSZ↔NSP byte-alignment against the `nsz` reference, NSP↔XCI round-trip, NSP→NSZ→NSP round-trip, FAT32 split/merge, real XCI structure reads, Info extraction, RSV patching, NCA Meta hash-chain rebuild, title-key removal, **delta merge (upd_base `--apply-deltas` end-to-end strict verification + size growth)**, **restore round-trip (GameCard → Restore yields a byte-identical NSP)**, **keygen lowering / rename / database export**, and more.

### Project structure

```
nscb-web/
├── src/
│   ├── NscbCore/       # format core library (no web dependency)
│   │   ├── Crypto/     # AES-XTS/CTR, IVFC hash trees
│   │   ├── Keys/       # prod.keys loading + ticket-derived title keys + firmware/keygen tables
│   │   ├── Formats/    # PFS0/HFS0/XCI/NCA/CNMT/NACP/NPDM/RomFS read-write + conversion
│   │   ├── Ncm/        # IVFC / Meta NCA builders, multi-segment container rebuild
│   │   ├── Nsz/        # NCZ solid/block compress-decompress
│   │   ├── Delta/      # BKTR delta → materialized standalone NCA
│   │   ├── Patching/   # RSV lowering + keygen rewrite + cnmt hash sync + title-key removal + restore
│   │   ├── Info/       # title info extraction + batch database export
│   │   ├── Packaging/  # pack multiple files into XCI + upd_base merge
│   │   ├── Verify/     # integrity verification / NSCB-modification detection
│   │   ├── Splitting/  # FAT32 split + multi-content split
│   │   ├── Joiner/     # split-file join
│   │   └── Renaming/   # rename from content + filename sanitization
│   ├── NscbJobs/       # job engine (queue / progress / cancel)
│   └── NscbServer/     # ASP.NET Core minimal API + SSE + wwwroot/ (Web UI) + App.ico
├── tests/
│   └── NscbCore.Tests/ # xUnit (synthetic structures; no real game samples required)
├── tools/
│   └── itest/          # real-sample integration tests (run_all.py + ncz_ref.py + diagnostic commands)
├── start.sh / start.bat
└── README.md
```

## API endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/api/browse?path=` | server-side folder browse (filtered by extension) |
| GET | `/api/info?path=` | file info (JSON) |
| GET | `/api/info/icon?path=` | game icon |
| POST | `/api/jobs` | submit a job `{type, inputs, options}` |
| GET | `/api/jobs` | job list |
| GET | `/api/jobs/{id}` | job detail |
| DELETE | `/api/jobs/{id}` | cancel a job |
| GET | `/api/events` | SSE live progress stream |
| GET/PUT | `/api/settings` | key paths and output-directory settings |

The service listens on `127.0.0.1:54321` only.

## Dependencies

- [LibHac 0.19](https://github.com/Thealexbarney/LibHac) (NuGet)
- [ZstdSharp.Port 0.8.8](https://github.com/Hypersect/ZstdSharp) (NuGet, pure-C# zstd)
- Frontend: native ES Module SPA — zero build chain, zero CDN.

## License

Based on the original NSC_BUILDER (MIT); this project is likewise released under the MIT license.
Nintendo Switch is a trademark of Nintendo. This project is intended solely for processing your own legitimate backup files.
