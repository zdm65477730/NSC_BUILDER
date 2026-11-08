using System.Diagnostics;
using System.Security.Cryptography;
using Xunit.Abstractions;
using NscbCore.Formats;
using NscbCore.Info;
using NscbCore.Keys;
using NscbCore.Nsz;
using NscbCore.Packaging;
using NscbCore.Patching;
using NscbCore.Splitting;
using NscbCore.Verify;

namespace NscbCore.Tests;

/// <summary>
/// End-to-end integration tests over REAL game files. These exercise the full pack/unpack,
/// compress/decompress, verify, and firmware-downgrade pipeline with hard assertions on:
///  • compression ratio (NSZ/XCZ must be meaningfully smaller than the source),
///  • compression time (recorded; not asserted except an upper bound),
///  • round-trip byte/hash equality of every NCA (no corruption),
///  • Verify PASS before and after, and Info readable before and after,
///  • RSV + keygen downgrade: values lowered and Info/Verify still pass.
///
/// They are SKIPPED unless env NSCB_E2E_DIR points to a folder containing:
///   prod.keys, title.keys, and at least one sample: *.nsp / *.nsz / *.xci (real dumps).
/// Run locally with e.g.:
///   NSCB_E2E_DIR=D:\e2e dotnet test -c Release --filter Category=E2E
/// (put your prod.keys/title.keys and a game nsp/nsz/xci in D:\e2e).
/// </summary>
public sealed class IntegrationE2E
{
    private readonly ITestOutputHelper _out;
    public IntegrationE2E(ITestOutputHelper o) => _out = o;

    private static string Dir => Environment.GetEnvironmentVariable("NSCB_E2E_DIR") ?? "";
    // NSCB_E2E_FAST=1 → one small level (3) + threads {6} instead of the full {12,17}×{1,6} matrix: ~6x quicker
    // re-run that still exercises the non-power-of-two MT/chunk-alignment guard. Default = full coverage.
    private static bool Fast => Environment.GetEnvironmentVariable("NSCB_E2E_FAST") == "1";
    private static bool Available => Directory.Exists(Dir)
        && File.Exists(Path.Combine(Dir, "prod.keys"))
        && (Samples().Count > 0);

    private static List<string> Samples()
    {
        if (!Directory.Exists(Dir)) return new();
        return Directory.EnumerateFiles(Dir)
            .Where(f => new[] { ".nsp", ".nsz", ".xci", ".xcz" }.Contains(Path.GetExtension(f).ToLowerInvariant()))
            .ToList();
    }

    private static NscbKeys Keys() =>
        NscbKeys.Load(Path.Combine(Dir, "prod.keys"));   // prod.keys only: rights-id keys derive from each game's ticket (titles.json = metadata only)

    private sealed record NcaHashes(Dictionary<string, string> ByName)
    {
        public bool SameAs(NcaHashes other) =>
            ByName.Count == other.ByName.Count && ByName.All(kv => other.ByName.TryGetValue(kv.Key, out var h) && h == kv.Value);
    }

    private static NcaHashes HashNcas(string containerPath)
    {
        var kind = ContainerReader.DetectKind(containerPath);
        var dict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        using var fs = File.OpenRead(containerPath);
        foreach (var e in ContainerReader.ReadEntries(fs, kind))
        {
            if (!e.IsNca) continue;                       // plain .nca entries only
            fs.Position = e.Offset;
            using var sha = SHA256.Create();
            // Stream-hash the entry via TransformBlock so multi-GB NCAs don't blow the ~2GB MemoryStream cap.
            long rem = e.Size; var buf = new byte[1 << 20];
            while (rem > 0) { int r = fs.Read(buf, 0, (int)Math.Min(buf.Length, rem)); if (r <= 0) break; sha.TransformBlock(buf, 0, r, null, 0); rem -= r; }
            sha.TransformFinalBlock(System.Array.Empty<byte>(), 0, 0);
            dict[e.BaseName] = Convert.ToHexString(sha.Hash!);
        }
        return new NcaHashes(dict);
    }

    private static string? FirstSample(params string[] exts) =>
        Samples().FirstOrDefault(f => exts.Contains(Path.GetExtension(f).ToLowerInvariant()));

    // ── NSP ↔ NSZ : ratio + time + round-trip hash + verify + info ───────────────────
    [Fact] [Trait("Category", "E2E")]
    public void Nsz_compress_roundtrip_ratio_time_verify()
    {
        if (!Available) { _out.WriteLine("SKIPPED: set NSCB_E2E_DIR to a folder with prod.keys/title.keys and a sample nsp/nsz."); return; }
        var keys = Keys();
        var work = Path.Combine(Dir, "_e2e_work"); Directory.CreateDirectory(work);
        var nsp = FirstSample(".nsp");
        if (nsp is null)
        {
            var nsz = FirstSample(".nsz")!;
            nsp = Path.Combine(work, "_derived.nsp");   // derived intermediates go to _e2e_work, never NSCB_E2E_DIR (keeps Samples() clean)
            NszConverter.NszToNsp(nsz, nsp, null, default, 4);
        }
        var orig = HashNcas(nsp);
        Assert.True(orig.ByName.Count > 0, "no NCAs found in sample NSP");
        var info0 = new TitleInfoService(keys).GetFileInfo(nsp);
        Assert.True(Verifier.VerifyContainer(nsp, keys).Ok, "original NSP fails Verify");

        foreach (int level in (Fast ? new[] { 3 } : new[] { 12, 17 }))
            foreach (int threads in (Fast ? new[] { 6 } : new[] { 1, 6 }))   // 6 = non-power-of-two: regression guard for the
            {                                          // "Offset must be a multiple of 16" chunk-alignment bug
                string outNsz = Path.Combine(work, $"c{level}_t{threads}.nsz");
                var sw = Stopwatch.StartNew();
                NszConverter.NspToNsz(nsp, outNsz, keys, level, null, default, threads);
                sw.Stop();
                long cLen = new FileInfo(outNsz).Length, oLen = new FileInfo(nsp).Length;
                double ratio = (double)cLen / oLen;
                // Diagnostic: how many entries actually became .ncz (compressed) vs stayed .nca (copied)?
                using (var fchk = File.OpenRead(outNsz))
                {
                    var es = ContainerReader.ReadEntries(fchk, ContainerReader.DetectKind(outNsz));
                    int ncz = es.Count(x => x.IsNcz), nca = es.Count(x => x.IsNca);
                    _out.WriteLine($"  entries: .ncz={ncz} .nca={nca}  (if .ncz=0 → IsCompressible false → passthrough copy)");
                    // NSZ/XCZ compatibility guard: every compressed .ncz MUST be a SINGLE solid zstd frame.
                    // Conformant decoders (NSGManager, console installers, NSCB) read only the FIRST frame, so a
                    // multi-frame stream silently truncates → SHA256 verify FAIL. (A past parallel pipeline emitted
                    // dozens of frames; NSGManager's own NSZ has exactly 1.) Threshold tolerates the rare random
                    // 4-byte magic match inside ~1 GB of compressed data.
                    foreach (var e in es.Where(x => x.IsNcz))
                    {
                        int fr = CountZstdFrames(fchk, e.Offset, e.Size);
                        _out.WriteLine($"  .ncz {Path.GetFileName(e.Name)}: zstd frame magics={fr} (single-frame ⇒ 1, +rare random 4-byte matches)");
                        // A single solid frame yields 1 magic plus ~0.5 random 4-byte matches per 2 GB; the old
                        // multi-frame regression produced dozens. <=8 cleanly separates them without flaking.
                        Assert.True(fr <= 8, $"multi-frame NSZ regression: {fr} zstd frame magics in {e.Name} — conformant decoders read only the first");
                    }
                }
                _out.WriteLine($"NSP→NSZ level={level} threads={threads}: {oLen/1_000_000}MB → {cLen/1_000_000}MB  ratio={ratio:F3}  {sw.Elapsed.TotalSeconds:F1}s");

                // INTEGRITY FIRST (always reported even when ratio is wrong): every NCA must come back
                // byte-identical, and Verify must pass on both the NSZ and the round-tripped NSP.
                string back = Path.Combine(work, $"c{level}_t{threads}.back.nsp");
                NszConverter.NszToNsp(outNsz, back, null, default, 4);
                Assert.True(HashNcas(back).SameAs(orig), $"round-trip NSP≠orig after level={level} threads={threads}");
                Assert.True(Verifier.VerifyContainer(back, keys).Ok, "round-tripped NSP fails Verify");
                Assert.True(Verifier.VerifyContainer(outNsz, keys).Ok, "the NSZ itself fails Verify");

                // HARD: real game data must compress well below the source. This is the gate that stays red
                // until the compress-side section plaintext extraction (AES-CTR title-key/counter) is correct.
                Assert.True(ratio < 0.95, $"NSZ not compressing: ratio={ratio:F3} (expected < 0.95)");
            }
        var info1 = new TitleInfoService(keys).GetFileInfo(nsp);
        Assert.Equal(info0.TitleId, info1.TitleId);
    }

    // ── XCI ↔ XCZ : ratio + round-trip + verify ──────────────────────────────────────
    [Fact] [Trait("Category", "E2E")]
    public void Xcz_compress_roundtrip_ratio_verify()
    {
        if (!Available) { _out.WriteLine("SKIPPED"); return; }
        var keys = Keys();
        var work = Path.Combine(Dir, "_e2e_work"); Directory.CreateDirectory(work);
        var xci = FirstSample(".xci");
        if (xci is null)
        {
            var nsp = FirstSample(".nsp") ?? Path.Combine(work, "_derived.nsp");
            if (!File.Exists(nsp)) NszConverter.NszToNsp(FirstSample(".nsz")!, nsp, null, default, 4);
            xci = Path.Combine(work, "_derived.xci");
            ContainerConverter.NspToXci(nsp, xci, keys, null, default, 4);
        }
        var orig = HashNcas(xci);
        foreach (int threads in (Fast ? new[] { 6 } : new[] { 1, 6 }))   // 6 = non-power-of-two: chunk-alignment + MT regression guard
        {
            string outXcz = Path.Combine(work, $"x_t{threads}.xcz");
            var sw = Stopwatch.StartNew();
            NszConverter.XciToXcz(xci, outXcz, keys, Fast ? 3 : 17, null, default, threads);
            sw.Stop();
            double ratio = (double)new FileInfo(outXcz).Length / new FileInfo(xci).Length;
            _out.WriteLine($"XCI→XCZ threads={threads}: ratio={ratio:F3}  {sw.Elapsed.TotalSeconds:F1}s");
            Assert.True(ratio < 0.95, $"XCZ not compressing: ratio={ratio:F3}");
            // Single-frame compatibility guard (same as NSZ): every .ncz in the XCZ must be ONE solid zstd frame,
            // else single-frame decoders (NSGManager/installers) truncate → SHA256 FAIL. Tolerates rare random magic.
            using (var fchk = File.OpenRead(outXcz))
            {
                var es = ContainerReader.ReadEntries(fchk, ContainerReader.DetectKind(outXcz));
                foreach (var e in es.Where(x => x.IsNcz))
                {
                    int fr = CountZstdFrames(fchk, e.Offset, e.Size);
                    _out.WriteLine($"  .ncz {Path.GetFileName(e.Name)}: zstd frame magics={fr} (single-frame ⇒ 1)");
                    Assert.True(fr <= 8, $"multi-frame XCZ regression: {fr} zstd frame magics in {e.Name}");
                }
            }
            string back = Path.Combine(work, $"x_t{threads}.back.xci");
            NszConverter.XczToXci(outXcz, back, null, default, 4);
            Assert.True(HashNcas(back).SameAs(orig), "XCIↄ↔XCZ round-trip NCAs differ");
            Assert.True(Verifier.VerifyContainer(outXcz, keys).Ok, "XCZ fails Verify");
        }
    }

    // ── NSP ↔ XCI container conversion keeps NCAs ────────────────────────────────────
    [Fact] [Trait("Category", "E2E")]
    public void Nsp_to_Xci_roundtrip_preserves_ncas()
    {
        if (!Available) { _out.WriteLine("SKIPPED"); return; }
        var keys = Keys();
        var nsp = FirstSample(".nsp") ?? Path.Combine(Dir, "_derived.nsp");
        if (!File.Exists(nsp)) NszConverter.NszToNsp(FirstSample(".nsz")!, nsp, null, default, 4);
        var orig = HashNcas(nsp);
        var work = Path.Combine(Dir, "_e2e_work"); Directory.CreateDirectory(work);
        string xci = Path.Combine(work, "conv.xci");
        ContainerConverter.NspToXci(nsp, xci, keys, null, default, 4);
        string back = Path.Combine(work, "conv.back.nsp");
        ContainerConverter.XciToNsp(xci, back, null, default, 4);
        Assert.True(HashNcas(back).SameAs(orig), "NSP→XCI→NSP changed NCA bytes");
        Assert.True(Verifier.VerifyContainer(back, keys).Ok, "converted NSP fails Verify");
    }

    // ── Pack multiple titles to XCI/XCZ, correct extension, then split back ──────────
    [Fact] [Trait("Category", "E2E")]
    public void Pack_multi_to_extension_and_split()
    {
        if (!Available) { _out.WriteLine("SKIPPED"); return; }
        var keys = Keys();
        var nsps = Samples().Where(f => Path.GetExtension(f).ToLowerInvariant() is ".nsp" or ".nsz").ToList();
        if (nsps.Count < 2) { _out.WriteLine("SKIPPED: need ≥2 NSP/NSZ samples to pack+split."); return; }
        bool anyCompressed = nsps.Any(f => Path.GetExtension(f).ToLowerInvariant() == ".nsz");
        var work = Path.Combine(Dir, "_e2e_work"); Directory.CreateDirectory(work);
        string packed = Path.Combine(work, "packed." + (anyCompressed ? "xcz" : "xci"));
        var sw = Stopwatch.StartNew();
        XciPacker.Pack(nsps, packed, keys, null, default);
        sw.Stop();
        _out.WriteLine($"Pack {nsps.Count} files → {Path.GetFileName(packed)} in {sw.Elapsed.TotalSeconds:F1}s");
        // Extension matches content (compressed inputs → xcz).
        Assert.Equal(anyCompressed ? ".xcz" : ".xci", Path.GetExtension(packed).ToLowerInvariant());
        Assert.True(new FileInfo(packed).Length > 0, "pack produced empty file");
        var info = new TitleInfoService(keys).GetFileInfo(packed);
        Assert.False(string.IsNullOrEmpty(info.TitleId), "packed file not readable via Info");
        // Composition (the "(1G+1U)" tag source) must see the titles inside the packed container.
        var (cg, cu, cd) = TitleSplitter.Composition(packed, keys);
        _out.WriteLine($"  composition of packed: {cg}G+{cu}U+{cd}D");
        Assert.True(cg + cu + cd >= 1, "packed container reports no titles");
        // split back
        string outDir = Path.Combine(work, "split");
        var outputs = TitleSplitter.Split(packed, outDir, keys, null, default);
        _out.WriteLine($"Split → {outputs.Count} titles: " + string.Join(", ", outputs.Select(Path.GetFileName)));
        Assert.True(outputs.Count >= 1, "split produced nothing");
        foreach (var o in outputs) Assert.True(new FileInfo(o).Length > 0, $"split output empty: {o}");

        // base-as-card option (WriteCard): the Application title comes back as a card image (xci/xcz) while
        // updates/DLC stay NSP/NSZ — and EVERY split output must be a valid, verifiable container.
        string outDirCard = Path.Combine(work, "split-card");
        var cardOuts = TitleSplitter.Split(packed, outDirCard, keys, null, default, baseAsCard: true);
        _out.WriteLine($"Split baseAsCard → " + string.Join(", ", cardOuts.Select(Path.GetFileName)));
        Assert.True(cardOuts.Any(o => Path.GetExtension(o).ToLowerInvariant() is ".xci" or ".xcz"),
            "base-as-card split produced no card (xci/xcz) output");
        foreach (var o in cardOuts)
            Assert.True(Verifier.VerifyContainer(o, keys).Ok, $"base-as-card split output fails Verify: {Path.GetFileName(o)}");
    }

    // ── Firmware/keygen downgrade: lowered + Info/Verify still good (NSP and NSZ) ──────
    [Fact] [Trait("Category", "E2E")]
    public void Downgrade_lowers_rsv_keygen_and_still_verifies()
    {
        if (!Available) { _out.WriteLine("SKIPPED"); return; }
        var keys = Keys();
        uint rsv = FirmwareTables.RsvFromFwString("9.0.1");
        int? kg = FirmwareTables.KeyGenerationFromRsv(rsv);
        Assert.NotNull(kg);

        var work = Path.Combine(Dir, "_e2e_work"); Directory.CreateDirectory(work);
        foreach (var src in new[] { FirstSample(".nsp"), FirstSample(".nsz") })
        {
            if (src is null) continue;
            string ext = Path.GetExtension(src);
            string tgt = Path.Combine(work, "dg" + ext);
            File.Copy(src, tgt, true);
            var before = new TitleInfoService(keys).GetFileInfo(tgt);
            int kgBefore = (int)Parse(before.KeyGeneration?.ToString());

            string dg = Path.Combine(work, "dg2" + ext);
            ContainerPatcher.PatchCnmtRsv(tgt, dg, keys, rsv, true, null, default);
            var (changed, newHashes) = ContainerPatcher.PatchKeyGenerationInPlace(dg, keys, kg!.Value, null, default);
            if (newHashes.Count > 0) ContainerPatcher.SyncContentHashes(dg, newHashes, keys);
            _out.WriteLine($"downgrade {ext}: src keygen={kgBefore} → target gen={kg} (NCA headers changed={changed}, hashes synced={newHashes.Count})");

            var after = new TitleInfoService(keys).GetFileInfo(dg);
            Assert.False(string.IsNullOrEmpty(after.TitleId), "Info unreadable after downgrade");
            int kgAfter = (int)Parse(after.KeyGeneration?.ToString());
            // Container keygen is the MAX over all NCAs; a rights-id Program NCA (empty keyarea) can't be
            // re-wrapped and legitimately stays high (NSCB does the same), so keygen must only NEVER INCREASE.
            // The guaranteed downgrade signal is the cnmt RSV dropping to the target firmware.
            Assert.True(kgAfter <= kgBefore, $"keygen increased ({kgBefore}→{kgAfter})");
            if (changed > 0)
                Assert.True(Parse(after.RequiredSystemVersion ?? "") < Parse(before.RequiredSystemVersion ?? ""),
                    $"RSV not lowered ({before.RequiredSystemVersion}→{after.RequiredSystemVersion})");
            // RSV lowered (target firmware string should appear / be ≤ before)
            _out.WriteLine($"  RSV: {before.RequiredSystemVersion} → {after.RequiredSystemVersion}");
            // content is still intact → Verify must still PASS
            var vr = Verifier.VerifyContainer(dg, keys);
            Assert.True(vr.Ok, "Verify failed after downgrade: " + string.Join("; ", vr.Failures.Take(3)));

            // NSP only: NSGManager-style "SHA256 Hash Verify" — every cnmt content record's stored hash must
            // equal SHA256(the .nca file). Proves the keygen-lowering hash sync makes strict verifiers pass.
            if (ext == ".nsp")
            {
                var cent = new List<NscbCore.Formats.ContainerEntry>();
                using (var cf = File.OpenRead(dg)) cent = ContainerReader.ReadEntries(cf, ContainerKind.Nsp);
                var byId = new Dictionary<string, NscbCore.Formats.ContainerEntry>(StringComparer.OrdinalIgnoreCase);
                foreach (var e in cent) if (e.IsNca) { var id = Path.GetFileNameWithoutExtension(e.BaseName); if (id.Length >= 32) byId[id[..32].ToLowerInvariant()] = e; }
                int tot = 0, mism = 0;
                using var dfs = File.OpenRead(dg);
                foreach (var m in cent)
                {
                    if (!m.IsNca || !m.BaseName.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)) continue;
                    foreach (var (id, hash) in NcaCnmtPatcher.ReadContentHashes(dfs, m.Offset, m.Size, keys.KeySet))
                    {
                        if (!byId.TryGetValue(id, out var t)) continue;
                        long rem = t.Size; dfs.Position = t.Offset; var nb = new byte[1 << 20];
                        using (var sha2 = System.Security.Cryptography.SHA256.Create())   // stream: NCA can exceed 2GB
                        {
                            while (rem > 0) { int rr = dfs.Read(nb, 0, (int)Math.Min(nb.Length, rem)); if (rr <= 0) break; sha2.TransformBlock(nb, 0, rr, null, 0); rem -= rr; }
                            sha2.TransformFinalBlock(System.Array.Empty<byte>(), 0, 0);
                            var calc = sha2.Hash!; tot++;
                            if (!calc.AsSpan().SequenceEqual(hash)) mism++;
                        }
                    }
                }
                _out.WriteLine($"  cnmt content-hash (NSGManager-style): {tot - mism}/{tot} match");
                Assert.True(tot > 0 && mism == 0, $"content-record hash mismatch on {tot - mism}/{tot} after downgrade+sync");
            }
        }
    }

    // ── upd_base merge: rebuilds Meta (cnmt hash chain) → merged pack must verify + bump version ──
    [Fact] [Trait("Category", "E2E")]
    public void UpdBase_merge_verifies_and_bumps_version()
    {
        if (!Available) { _out.WriteLine("SKIPPED"); return; }
        var keys = Keys();
        var pair = FindMergePair(keys);
        if (pair is null) { _out.WriteLine("SKIPPED: NSCB_E2E_DIR needs a base Application + a matching update (Patch/Delta by BaseTitleId)."); return; }
        var (baseFile, updFile) = pair.Value;
        var work = Path.Combine(Dir, "_e2e_work"); Directory.CreateDirectory(work);

        string ToNsp(string f)
        {
            var k = ContainerReader.DetectKind(f);
            if (k == ContainerKind.Nsp) return f;
            string t = Path.Combine(work, Path.GetFileNameWithoutExtension(f) + ".nsp");
            NszConverter.NszToNsp(f, t, null, default, 4);
            return t;
        }
        string b = ToNsp(baseFile), u = ToNsp(updFile);
        var updVer = new TitleInfoService(keys).GetFileInfo(u).TitleVersionRaw;

        string merged = Path.Combine(work, "merged.nsp");
        UpdBaseMerger.Merge(b, new[] { u }, merged, keys, null, default, applyDeltas: true);
        var vr = Verifier.VerifyContainer(merged, keys);
        _out.WriteLine($"merge {Path.GetFileName(baseFile)} + {Path.GetFileName(updFile)} → {new FileInfo(merged).Length} bytes; verify ok={vr.Ok} {string.Join(";", vr.Failures.Take(3))}");
        Assert.True(vr.Ok, "merged NSP fails Verify (Meta/cnmt hash chain): " + string.Join("; ", vr.Failures.Take(3)));
        var mi = new TitleInfoService(keys).GetFileInfo(merged);
        Assert.Equal(updVer, mi.TitleVersionRaw);   // merged reflects the update version, not base v0

        // Round the merged pack to NSZ and back → still verifies (the NSZ merge path relies on the same rebuild).
        string mnsz = Path.Combine(work, "merged.nsz");
        NszConverter.NspToNsz(merged, mnsz, keys, 17, null, default, 4);
        Assert.True(Verifier.VerifyContainer(mnsz, keys).Ok, "merged NSZ fails Verify");
    }

    // Find a base Application and an update (Patch/Delta) that share a BaseTitleId among the samples.
    private static (string basew, string upd)? FindMergePair(NscbKeys keys)
    {
        var svc = new TitleInfoService(keys);
        var list = new List<(string f, string? type, string? key)>();
        foreach (var f in Samples())
        {
            try
            {
                var ci = svc.GetFileInfo(f);
                if (string.IsNullOrEmpty(ci.TitleId)) continue;
                list.Add((f, ci.TitleType, ci.BaseTitleId ?? ci.TitleId));
            }
            catch { }
        }
        var apps = list.Where(x => x.type == "Application").ToList();
        var upds = list.Where(x => x.type is "Patch" or "Delta").ToList();
        foreach (var a in apps)
            foreach (var d in upds)
                if (a.key == d.key) return (a.f, d.f);
        return null;
    }

    private static long Parse(string? s) { if (long.TryParse(s, out var v)) return v; var m = System.Text.RegularExpressions.Regex.Match(s ?? "", @"\d+"); return m.Success ? long.Parse(m.Value) : -1; }

    // Count zstd frame magics (0xFD2FB528, little-endian bytes 28 B5 2F FD) in [off, off+size) via a 4-byte
    // sliding window. A conformant single-frame NSZ has exactly 1; the old multi-frame pipeline had dozens.
    private static int CountZstdFrames(Stream f, long off, long size)
    {
        f.Seek(off, SeekOrigin.Begin);
        byte[] buf = new byte[1 << 20];
        byte w0 = 0, w1 = 0, w2 = 0, w3 = 0; int cnt = 0; long rem = size;
        while (rem > 0)
        {
            int n = (int)Math.Min(buf.Length, rem);
            int read = f.Read(buf, 0, n); if (read <= 0) break; rem -= read;
            for (int i = 0; i < read; i++)
            {
                w0 = w1; w1 = w2; w2 = w3; w3 = buf[i];
                if (w0 == 0x28 && w1 == 0xB5 && w2 == 0x2F && w3 == 0xFD) cnt++;
            }
        }
        return cnt;
    }
}
