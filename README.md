# NSC_BUILDER

A Nintendo Switch format tool — a clean-room rewrite of NSC_BUILDER in C# / .NET 10 + LibHac, with a browser-driven UI.

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

### Manual build & publish — Windows single-file exe

```bash
dotnet publish src/NscbServer -c Release -f net10.0-windows -o dist/win-x64
# Output: dist/win-x64/NscbServer.exe — single-file, self-contained; native WinForms + WebView2 window
```

### Manual build & publish — macOS / Linux single file (browser UI)

The native window (WinForms + WebView2) is Windows-only, so on macOS/Linux the single file is the **headless
server**: it serves the embedded UI and opens your system browser (`http://127.0.0.1:54321`). Same tool and
features, just shown in a browser instead of a native window (the native OS file drag-drop is a Windows-only
nicety; the file pickers work everywhere).

```bash
# Linux x64
dotnet publish src/NscbServer -c Release -f net10.0 -r linux-x64 --self-contained -p:PublishSingleFile=true -o dist/linux-x64
#   -> dist/linux-x64/NscbServer        (chmod +x, run it; the browser opens automatically)

# macOS Apple Silicon (M1-M4)
dotnet publish src/NscbServer -c Release -f net10.0 -r osx-arm64 --self-contained -p:PublishSingleFile=true -o dist/osx-arm64

# macOS Intel
dotnet publish src/NscbServer -c Release -f net10.0 -r osx-x64 --self-contained -p:PublishSingleFile=true -o dist/osx-x64
```

Run with `--serve` / `--no-open` for headless (no browser), or `--browser` to force the browser path.
> Build the macOS targets **on a Mac** (or, when cross-compiling from another OS, allow NuGet to fetch the
> `Microsoft.*.osx-*` runtime packs — the repo's `nuget.config` clears online sources, so a first cross-build
> may need `--source https://api.nuget.org/v3/index.json`). The `-f` flag is required because the project now
> multi-targets (`net10.0-windows` desktop + `net10.0` cross-platform).

## Configure keys

Once the service starts, open `http://127.0.0.1:54321` in a browser and click the ⚙ (top-right):

- **prod.keys** (required — and the *only* key input): `header_key` + `master_key_NN` (any generation, uncapped).
- **No title.keys file is needed**: each title's rights-id title key is derived on demand from the container's own bundled ticket (`titlekek` comes from the `master_key` in prod.keys). Personal / device-bound tickets are not supported (same as NSCB / NSGManager).
- **titles.json** (optional, metadata only): supplies title name / publisher / genre / region, etc. It is **not** used for key extraction.

Settings are saved to `settings.json` (next to the program) and reloaded on the next start.

## Development

```bash
# after cloning
cd .   # you are at the repo root — the C# project lives directly here (no nscb-web/ subdir)
dotnet build          # full compile
dotnet test           # unit tests (220, synthetic data; no real samples / keys / network required)
dotnet run --project src/NscbServer -f net10.0-windows   # dev mode (Windows; use -f net10.0 on macOS/Linux)
./clean.sh            # remove build & temp artifacts (bin/obj/dist/...); Windows: clean.bat
./tools/e2e_quick.sh  # real-sample E2E: auto-picks the smallest base+update game, decompresses, runs FAST (~1 min). Env: E2E_QUICK_FAST=0 full matrix, E2E_QUICK_KEEP=1 keep scratch, E2E_QUICK_LIB/E2E_QUICK_KEYS override paths
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
# repo root (this is the NSC_BUILDER project)
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
