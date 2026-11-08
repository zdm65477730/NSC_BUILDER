using System.Buffers.Binary;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Ncm;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using LibHac.Tools.Ncm;
using NscbCore.Formats;
using NscbCore.Keys;
using NscbCore.Ncm;
using NscbCore.Xml;
using IOPath = System.IO.Path;
using ContentType = LibHac.Ncm.ContentType;

namespace NscbCore.Packaging;

/// <summary>
/// Merge an update onto a base title ("upd_base"): produce a single NSP whose installable
/// content is the update's (Program/Data), everything else from the base, and whose Meta
/// cnmt content list, TitleVersion and RSV reflect the update. The merged Meta NCA is
/// rebuilt (section resized + hash chain + header re-encrypted), so the result passes a
/// strict cnmt-hash verifier, not just Tinfoil.
/// </summary>
public static class UpdBaseMerger
{
    /// <summary>Content types an update can supersede (1:1) in the base.</summary>
    // Content types an update legitimately overwrites on the base app. Includes Control so the merged
    // app takes the update's Control NCA → its NACP DisplayVersion (the "版本" NSCManager/console shows)
    // updates too, not just the cnmt TitleVersion.
    private static readonly ContentType[] SwappableTypes = [ContentType.Program, ContentType.Data, ContentType.Control];

    // A cnmt content record is a fixed 0x38-byte entry: hash(0x20)+ncaId(0x10)+size(u48)+type+idOff.
    private const int ContentRecordSize = 0x38;

    /// <param name="applyDeltas">
    /// Opt-in delta materialization. Because a delta fragment does <b>not</b> self-declare the base
    /// content it patches (matching would need the delta applied-info format, not yet implemented),
    /// auto-applying risks silently substituting the wrong content. Defaults off → the proven
    /// base+update-program merge is used and base content is left intact.
    /// </param>
    public static void Merge(string baseContainer, IReadOnlyList<string> updateContainers,
        string outputNsp, NscbKeys keys, Action<long>? progress = null, CancellationToken ct = default,
        bool applyDeltas = false, Action<string>? diag = null)
    {
        if (updateContainers is null || updateContainers.Count == 0)
            throw new ArgumentException("At least one update container is required.", nameof(updateContainers));
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("prod.keys with header_key is required to rebuild the Meta NCA.");

        // Rights-id base/update NCAs need title keys; with title.keys removed, derive them from the containers' own tickets.
        TicketTitleKeys.RegisterFromContainer(keys, baseContainer);
        foreach (var u in updateContainers) TicketTitleKeys.RegisterFromContainer(keys, u);

        ContainerKind baseKind = ContainerReader.DetectKind(baseContainer);
        if (baseKind is not (ContainerKind.Nsp or ContainerKind.Nsz))
            throw new InvalidDataException($"UpdBase needs an NSP/NSZ base; got {baseKind}.");

        var baseCtx = ReadMetaContext(baseContainer, keys);
        var baseRecords = ParseContentRecords(baseCtx.Cnmt);

        // Pick the highest-version readable update.
        UpdateContext? best = null;
        foreach (string upd in updateContainers)
        {
            ct.ThrowIfCancellationRequested();
            UpdateContext? c = TryReadUpdateContext(upd, keys);
            if (c is not null && (best is null || c.Version > best.Version)) best = c;
        }
        if (best is null)
            throw new InvalidOperationException("No readable update container was found to merge.");

        var tempFiles = new List<string>();

        // Delta materialization FIRST so it can take precedence over the update's program-swap for the
        // same content (a delta update ships no full Program NCA; the base Program is patched instead).
        var materialized = applyDeltas ? TryMaterializeDeltas(baseCtx, best, keys, tempFiles, ct, diag)
                                       : new Dictionary<string, Materialized>();

        var updRecords = ParseContentRecords(best.Cnmt);
        var updByType = new Dictionary<ContentType, byte[]>();
        foreach (var r in updRecords)
            if (SwappableTypes.Contains(r.Type) && !updByType.ContainsKey(r.Type))
                updByType[r.Type] = r.Raw;

        // Merged content records = base records with swappable ones replaced by the update's
        // (correct id/size/hash) — EXCEPT base contents that were delta-materialized (kept + repointed),
        // then update swappable types the base lacks are appended.
        var baseTypes = baseRecords.Select(r => r.Type).ToHashSet();
        var merged = new List<byte[]>();
        var renamedBaseIds = new Dictionary<ContentType, string>();   // base type → update NCA id (file to source)
        var appendedIds = new List<string>();                          // update-only content ids to add
        foreach (var r in baseRecords)
        {
            if (!materialized.ContainsKey(r.NcaId) && SwappableTypes.Contains(r.Type) && updByType.TryGetValue(r.Type, out var ur))
            {
                merged.Add(ur);
                renamedBaseIds[r.Type] = IdOfRecord(ur);
            }
            else merged.Add(r.Raw);
        }
        foreach (var r in updRecords)
        {
            if (SwappableTypes.Contains(r.Type) && !baseTypes.Contains(r.Type))
            {
                merged.Add(r.Raw);
                appendedIds.Add(IdOfRecord(r.Raw));
            }
        }
        if (renamedBaseIds.Count == 0 && appendedIds.Count == 0 && materialized.Count == 0)
            throw new InvalidOperationException("Update supplied no Program/Data content to merge.");

        // Repoint base cnmt records of delta-materialized NCAs to the patched id/size/hash.
        if (materialized.Count > 0)
            for (int i = 0; i < merged.Count; i++)
                merged[i] = ApplyMaterialized(merged[i], materialized);

        byte[] newCnmt = RebuildCnmt(baseCtx.Cnmt, merged, (uint)best.Version, best.Rsv);
        byte[] newMetaNca = MetaNcaBuilder.RebuildWithCnmt(baseCtx.MetaNca, keys.KeySet, baseCtx.CnmtName, newCnmt);

        // Assemble output files. The base Meta NCA is replaced by the rebuilt one; each
        // swappable base NCA is replaced by the update's NCA (named by its real id).
        var items = new List<(string Name, long Size, Func<Stream> Open)>();
        items.Add((IOPath.GetFileName(baseCtx.MetaEntryName), newMetaNca.Length, () => new MemoryStream(newMetaNca)));

        foreach (var be in baseCtx.Entries)
        {
            ct.ThrowIfCancellationRequested();
            string name = IOPath.GetFileName(be.Name);
            if (name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)) continue; // replaced above

            ContentType? t = RecordTypeById(baseRecords, IdOf(name));
            if (t is { } st && renamedBaseIds.TryGetValue(st, out string? updId))
            {
                ContainerEntry? ue = best.Entries.FirstOrDefault(e => IdOf(e.Name).Equals(updId, StringComparison.OrdinalIgnoreCase));
                if (ue is not null) { items.Add((updId + ".nca", ue.Size, OpenAt(best.Path, ue.Offset))); continue; }
            }

            // Delta-materialized base NCA → emit the full patched NCA under its new content id.
            string baseId = IdOf(name);
            if (materialized.TryGetValue(baseId, out var mat))
            {
                items.Add((mat.NewId + ".nca", mat.Size, () => File.OpenRead(mat.TempPath)));
                continue;
            }
            items.Add((name, be.Size, OpenAt(baseContainer, be.Offset)));
        }

        foreach (string id in appendedIds)
        {
            ContainerEntry? ue = best.Entries.FirstOrDefault(e => IdOf(e.Name).Equals(id, StringComparison.OrdinalIgnoreCase));
            if (ue is not null) items.Add((id + ".nca", ue.Size, OpenAt(best.Path, ue.Offset)));
        }

        try { WriteNsp(outputNsp, items, progress, ct); }
        finally { foreach (var t in tempFiles) { try { File.Delete(t); } catch { } } }
    }

    private static Func<Stream> OpenAt(string path, long offset)
        => () => { var s = File.OpenRead(path); s.Position = offset; return s; };

    private sealed record Materialized(string NewId, long Size, string TempPath);

    /// <summary>
    /// Pair each update delta to its base NCA authoritatively via the update cnmt's
    /// <c>ExtendedData.FragmentSets</c> (only <c>DeltaType == ApplyAsDelta</c> are true deltas;
    /// Overwrite/Create are full contents). Each fragment gives the delta NCA id (NcaIdNew, in the
    /// update) and its base NCA id (NcaIdOld, in the base). Stream-materialize a standalone updated
    /// NCA to a temp file (so multi-GB sections are fine). Accepted only if the rebuilt NCA re-opens
    /// under <c>ErrorOnInvalid</c>; anything else (e.g. a compressed section, which cannot yet be
    /// rebuilt) leaves the base intact.
    /// </summary>
    private static Dictionary<string, Materialized> TryMaterializeDeltas(
        MetaContext baseCtx, UpdateContext best, NscbKeys keys, List<string> tempFiles, CancellationToken ct, Action<string>? diag = null)
    {
        var result = new Dictionary<string, Materialized>(StringComparer.OrdinalIgnoreCase);
        if (!keys.HasHeaderKey) return result;
        using var updFile = new LibHac.FsSystem.LocalStorage(best.Path, FileAccess.Read);
        using var baseFile = new LibHac.FsSystem.LocalStorage(baseCtx.Path, FileAccess.Read);

        LibHac.Tools.Ncm.CnmtFragmentSetInfo[] frags;
        try { frags = new LibHac.Tools.Ncm.Cnmt(new MemoryStream(best.Cnmt)).ExtendedData?.FragmentSets ?? Array.Empty<LibHac.Tools.Ncm.CnmtFragmentSetInfo>(); }
        catch { return result; }
        diag?.Invoke($"frags={frags.Length} applyDeltas");

        foreach (var fr in frags)
        {
            ct.ThrowIfCancellationRequested();
            if (fr.DeltaType != LibHac.Ncm.UpdateType.ApplyAsDelta) continue;
            string deltaId = Hex(fr.NcaIdNew), baseId = Hex(fr.NcaIdOld);
            ContainerEntry? ud = best.Entries.FirstOrDefault(e => IsPlainNca(e) && IdOf(e.Name) == deltaId);
            // The delta's NcaIdOld is the source id it was BUILT against, which can differ from our
            // base's content id for the same slot (version drift). Resolve the base NCA by content TYPE
            // (from the fragment) in the base cnmt, falling back to NcaIdOld; OpenStorageWithPatch then
            // confirms the pairing (wrong base → throws → base kept).
            ContainerEntry? bb = baseCtx.Entries.FirstOrDefault(e => IsPlainNca(e) && IdOf(e.Name) == baseId);
            if (bb is null)
            {
                var baseRecs = ParseContentRecords(baseCtx.Cnmt).Where(r => r.Type == fr.Type).ToList();
                foreach (var r in baseRecs)
                {
                    var cand = baseCtx.Entries.FirstOrDefault(e => IsPlainNca(e) && IdOf(e.Name) == r.NcaId);
                    if (cand is not null && !result.ContainsKey(r.NcaId)) { bb = cand; baseId = r.NcaId; break; }
                }
            }
            if (ud is null || bb is null || result.ContainsKey(baseId)) { diag?.Invoke($"skip delta {deltaId[..Math.Min(12, deltaId.Length)]}: ud={ud is not null} bb({baseId[..Math.Min(12, baseId.Length)]})={bb is not null}"); continue; }
            var udSub = new LibHac.Fs.SubStorage(updFile, ud.Offset, ud.Size);
            var bbSub = new LibHac.Fs.SubStorage(baseFile, bb.Offset, bb.Size);

            // Collect every section this delta patches: base.OpenStorageWithPatch(delta, idx) succeeding
            // (under ErrorOnInvalid) is the pairing + correctness oracle. Then rebuild the WHOLE NCA
            // in one pass so multi-section Program deltas (ExeFS + RomFS) stay consistent.
            string tmp = IOPath.Combine(IOPath.GetTempPath(), "nscb_delta_" + Guid.NewGuid().ToString("N") + ".nca");
            try
            {
                var baseNca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, bbSub);
                var deltaNca = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, udSub);
                var patched = new Dictionary<int, (LibHac.Fs.IStorage Content, long Len)>();
                for (int idx = 0; idx < 4; idx++)
                {
                    try
                    {
                        var ps = baseNca.OpenStorageWithPatch(deltaNca, idx, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
                        ps.GetSize(out long plen).ThrowIfFailure();
                        if (plen > 0) patched[idx] = (ps, plen);
                    }
                    catch { /* section idx not patched by this delta */ }
                }
                if (patched.Count == 0) { File.Delete(tmp); diag?.Invoke($"{deltaId[..Math.Min(12, deltaId.Length)]}: 0 patched sections"); continue; }
                diag?.Invoke($"{deltaId[..Math.Min(12, deltaId.Length)]}→{bb.Name[..Math.Min(12, bb.Name.Length)]}: {patched.Count} sections, rebuilding");

                using (var fs = File.Create(tmp))
                    Ncm.IvfcNcaBuilder.RebuildMultiStreaming(bbSub, keys.KeySet, fs, patched);

                // Re-open + fully verify EVERY rebuilt section (rejects anything we can't rebuild → base kept).
                using (var vst = new LibHac.FsSystem.LocalStorage(tmp, FileAccess.Read))
                {
                    var vn = new LibHac.Tools.FsSystem.NcaUtils.Nca(keys.KeySet, vst);
                    for (int idx = 0; idx < 4; idx++)
                    {
                        try
                        {
                            var st = vn.OpenStorage(idx, LibHac.Tools.FsSystem.IntegrityCheckLevel.ErrorOnInvalid);
                            st.GetSize(out long cl).ThrowIfFailure();
                            byte[] buf = new byte[0x100000]; long done = 0;
                            while (done < cl) { int n2 = (int)Math.Min(buf.Length, cl - done); st.Read(done, buf.AsSpan(0, n2)).ThrowIfFailure(); done += n2; }
                        }
                        catch (Exception ex) when (ex.Message.Contains("not exist", StringComparison.OrdinalIgnoreCase) || ex.Message.Contains("NotFound", StringComparison.OrdinalIgnoreCase)) { }
                    }
                }
                byte[] fileHash;
                using (var fs2 = File.OpenRead(tmp)) fileHash = System.Security.Cryptography.SHA256.HashData(fs2);
                tempFiles.Add(tmp);
                result[baseId] = new Materialized(Convert.ToHexString(fileHash[..16]).ToLowerInvariant(), new FileInfo(tmp).Length, tmp);
                diag?.Invoke($"  materialized {baseId[..Math.Min(12, baseId.Length)]} → {result[baseId].NewId[..12]} ({new FileInfo(tmp).Length} B)");
            }
            catch (Exception ex) { try { File.Delete(tmp); } catch { } diag?.Invoke($"  rebuild failed: {ex.GetType().Name}: {ex.Message}"); }
        }
        return result;
    }

    private static string Hex(byte[] id) => Convert.ToHexString(id).ToLowerInvariant();

    private static bool IsPlainNca(ContainerEntry e) =>
        e.Name.EndsWith(".nca", StringComparison.OrdinalIgnoreCase) && !e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase);

    // Rewrite a base cnmt content record to point at a materialized NCA (id + size + hash).
    private static byte[] ApplyMaterialized(byte[] record, Dictionary<string, Materialized> mat)
    {
        string id = NscbCore.Info.NcaIdFormatter.ToHex(record.AsSpan(0x20, 0x10));
        if (!mat.TryGetValue(id, out var m)) return record;
        byte[] nr = (byte[])record.Clone();
        byte[] fileHash;
        using (var fs = File.OpenRead(m.TempPath)) fileHash = System.Security.Cryptography.SHA256.HashData(fs);
        fileHash.CopyTo(nr.AsSpan(0, 0x20));
        Convert.FromHexString(m.NewId).CopyTo(nr.AsSpan(0x20, 0x10));
        var sz = nr.AsSpan(0x30, 6);
        for (int i = 0; i < 6; i++) sz[i] = (byte)(m.Size >> (8 * i));
        return nr;
    }

    // ── cnmt parsing / building ────────────────────────────────────────────────────
    private readonly record struct ContentRecord(ContentType Type, string NcaId, byte[] Raw);

    private static List<ContentRecord> ParseContentRecords(byte[] cnmt)
    {
        int tableOff = ContentTableStart(cnmt);
        int count = BinaryPrimitives.ReadUInt16LittleEndian(cnmt.AsSpan(0x10, 2));
        var list = new List<ContentRecord>(count);
        for (int i = 0; i < count; i++)
        {
            int b = tableOff + i * ContentRecordSize;
            if (b + ContentRecordSize > cnmt.Length) break;
            byte[] raw = cnmt[b..(b + ContentRecordSize)];
            string id = NscbCore.Info.NcaIdFormatter.ToHex(raw.AsSpan(0x20, 0x10));
            var type = (ContentType)raw[0x36]; // hash(0x20)+ncaId(0x10)+size(6)+type(1)+idOff(1)
            list.Add(new ContentRecord(type, id, raw));
        }
        return list;
    }

    // content-table start = (flag@0x1C ? 24 : 32) + TableOffset(u16@0xE), per LibHac Cnmt.
    private static int ContentTableStart(byte[] cnmt)
    {
        bool flag = BinaryPrimitives.ReadInt32LittleEndian(cnmt.AsSpan(0x1C, 4)) != 0;
        int num = flag ? 24 : 32;
        int tableOffset = BinaryPrimitives.ReadUInt16LittleEndian(cnmt.AsSpan(0xE, 2));
        return num + tableOffset;
    }

    private static byte[] RebuildCnmt(byte[] baseCnmt, List<byte[]> records, uint version, uint rsv)
    {
        int tableStart = ContentTableStart(baseCnmt);
        int oldCount = BinaryPrimitives.ReadUInt16LittleEndian(baseCnmt.AsSpan(0x10, 2));
        int tailStart = tableStart + oldCount * ContentRecordSize;

        int len = tableStart + records.Count * ContentRecordSize + (baseCnmt.Length - tailStart);
        byte[] outBuf = new byte[len];
        baseCnmt[..tableStart].CopyTo(outBuf, 0);
        int pos = tableStart;
        foreach (var r in records) { r.CopyTo(outBuf, pos); pos += ContentRecordSize; }
        baseCnmt[tailStart..].CopyTo(outBuf, pos);

        BinaryPrimitives.WriteUInt16LittleEndian(outBuf.AsSpan(0x10, 2), (ushort)records.Count);
        BinaryPrimitives.WriteUInt32LittleEndian(outBuf.AsSpan(8, 4), version); // TitleVersion
        if (rsv != 0) BinaryPrimitives.WriteUInt32LittleEndian(outBuf.AsSpan(0x28, 4), rsv); // MinimumSystemVersion
        return outBuf;
    }

    private static ContentType? RecordTypeById(List<ContentRecord> records, string id)
    {
        foreach (var r in records)
            if (r.NcaId.Equals(id, StringComparison.OrdinalIgnoreCase)) return r.Type;
        return null;
    }

    private static string IdOfRecord(byte[] raw)
        => NscbCore.Info.NcaIdFormatter.ToHex(raw.AsSpan(0x20, 0x10));

    private static string IdOf(string name)
    {
        string stem = IOPath.GetFileNameWithoutExtension(name);
        if (stem.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase)) stem = stem[..^5];
        return stem.Length >= 32 ? stem[..32].ToLowerInvariant() : stem.ToLowerInvariant();
    }

    // ── container/meta reading ──────────────────────────────────────────────────────
    private sealed record MetaContext(string Path, List<ContainerEntry> Entries, string MetaEntryName,
        byte[] MetaNca, string CnmtName, byte[] Cnmt);
    private sealed record UpdateContext(string Path, ulong Version, uint Rsv,
        List<ContainerEntry> Entries, byte[] Cnmt);

    private static MetaContext ReadMetaContext(string container, NscbKeys keys)
    {
        ContainerKind kind = ContainerReader.DetectKind(container);
        List<ContainerEntry> entries;
        using (var probe = File.OpenRead(container))
            entries = ContainerReader.ReadEntries(probe, kind);
        var meta = entries.FirstOrDefault(e => e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidDataException($"No cnmt NCA in {container}.");

        byte[] ncaBytes = new byte[meta.Size];
        using (var fs = File.OpenRead(container)) { fs.Position = meta.Offset; fs.ReadExactly(ncaBytes); }
        var (cnName, cnBytes) = ReadCnmtFile(ncaBytes, keys);
        return new MetaContext(container, entries, IOPath.GetFileName(meta.Name), ncaBytes, cnName, cnBytes);
    }

    private static UpdateContext? TryReadUpdateContext(string path, NscbKeys keys)
    {
        try
        {
            ContainerKind kind = ContainerReader.DetectKind(path);
            List<ContainerEntry> entries;
            using (var probe = File.OpenRead(path))
                entries = ContainerReader.ReadEntries(probe, kind);
            var meta = entries.FirstOrDefault(e => e.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase));
            if (meta is null) return null;

            byte[] ncaBytes = new byte[meta.Size];
            using (var fs = File.OpenRead(path)) { fs.Position = meta.Offset; fs.ReadExactly(ncaBytes); }
            var (_, cnBytes) = ReadCnmtFile(ncaBytes, keys);
            var cnmt = new Cnmt(new MemoryStream(cnBytes));
            ulong version = cnmt.TitleVersion.Version;
            uint rsv = 0;
            try { rsv = cnmt.MinimumSystemVersion.Version; } catch { }
            return new UpdateContext(path, version, rsv, entries, cnBytes);
        }
        catch { return null; }
    }

    private static (string Name, byte[] Data) ReadCnmtFile(byte[] ncaBytes, NscbKeys keys)
    {
        var nca = new Nca(keys.KeySet, new MemoryStorage((byte[])ncaBytes.Clone()));
        var fs = nca.OpenFileSystem(0, IntegrityCheckLevel.None);
        var dirPath = new LibHac.Fs.Path();
        dirPath.Initialize(System.Text.Encoding.UTF8.GetBytes("/")).ThrowIfFailure();
        var d = default(LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IDirectory>);
        fs.OpenDirectory(ref d, in dirPath, LibHac.Fs.Fsa.OpenDirectoryMode.All).ThrowIfFailure();
        string? name = null;
        try
        {
            var buf = new DirectoryEntry[64];
            while (true)
            {
                d.Get.Read(out long read, buf).ThrowIfFailure();
                for (int i = 0; i < read; i++)
                {
                    var nm = buf[i].Name.ItemsRo;
                    int nul = nm.IndexOf((byte)0); if (nul < 0) nul = nm.Length;
                    string s = System.Text.Encoding.UTF8.GetString(nm[..nul]);
                    if (s.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase)) { name = s; break; }
                }
                if (name is not null || read < buf.Length) break;
            }
        }
        finally { d.Destroy(); }
        if (name is null) throw new InvalidDataException("no .cnmt file in Meta NCA section 0");

        var fp = new LibHac.Fs.Path();
        fp.Initialize(System.Text.Encoding.UTF8.GetBytes("/" + name)).ThrowIfFailure();
        var h = default(LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IFile>);
        fs.OpenFile(ref h, in fp, OpenMode.Read).ThrowIfFailure();
        try
        {
            h.Get.GetSize(out long sz).ThrowIfFailure();
            byte[] data = new byte[sz];
            h.Get.Read(out _, 0, data, ReadOption.None).ThrowIfFailure();
            return (name, data);
        }
        finally { h.Destroy(); }
    }

    private static void WriteNsp(string outputNsp,
        IReadOnlyList<(string Name, long Size, Func<Stream> Open)> items,
        Action<long>? progress, CancellationToken ct)
    {
        using var outFs = File.Create(outputNsp);
        var header = Pfs0Builder.BuildHeader(items.Select(i => (i.Name, i.Size)).ToList());
        outFs.Write(header);
        progress?.Invoke(header.Length);

        byte[] buf = new byte[0x80000];
        foreach (var (name, size, open) in items)
        {
            ct.ThrowIfCancellationRequested();
            using var src = open();
            long remaining = size;
            while (remaining > 0)
            {
                int r = src.Read(buf, 0, (int)Math.Min(buf.Length, remaining));
                if (r == 0) throw new EndOfStreamException($"Short read for '{name}'.");
                outFs.Write(buf, 0, r);
                remaining -= r;
                progress?.Invoke(r);
            }
        }
    }
}
