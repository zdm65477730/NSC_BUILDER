using LibHac.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using LibHac.Tools.Ncm;
using LibHac.Ncm;
using LibHac.Tools.FsSystem;
using LibHac.Fs;
using NscbCore.Formats;
using NscbCore.Keys;
using IOPath = System.IO.Path;
using ContentType = LibHac.Ncm.ContentType;

namespace NscbCore.Xci;

public sealed record XciPartitions(
    List<Hfs0File> UpdateFiles,
    List<Hfs0File> SecureFiles,
    List<ContainerEntry> UpdateEntries,
    List<ContainerEntry> SecureEntries);

/// <summary>
/// Load an XCI's partitions into memory (headers + entry lists) and re-emit a
/// new XCI from a (possibly filtered) subset. Uses <see cref="XciBuilder"/> so
/// card header / HFS0 headers / hashes are regenerated consistently.
/// </summary>
public static class XciEditor
{
    public static XciPartitions Read(string xciPath)
    {
        ContainerKind kind = ContainerReader.DetectKind(xciPath);
        if (kind is not (ContainerKind.Xci or ContainerKind.Xcz))
            throw new InvalidDataException($"not an XCI/XCZ: {kind}");

        using var probe = File.OpenRead(xciPath);
        var all = ContainerReader.ReadEntries(probe, kind);
        var upd = all.Where(e => e.Name.StartsWith("update/", StringComparison.OrdinalIgnoreCase)).ToList();
        var sec = all.Where(e => e.Name.StartsWith("secure/", StringComparison.OrdinalIgnoreCase)).ToList();

        var updFiles = new List<Hfs0File>();
        var secFiles = new List<Hfs0File>();
        foreach (var e in upd) updFiles.Add(MakeHfs0File(xciPath, e));
        foreach (var e in sec) secFiles.Add(MakeHfs0File(xciPath, e));
        return new XciPartitions(updFiles, secFiles, upd, sec);
    }

    /// <summary>
    /// Rebuild <paramref name="srcXci"/> to <paramref name="dstXci"/>, substituting
    /// the update/secure partitions with the filtered lists. Entries not present in
    /// the new lists are omitted from the output.
    /// </summary>
    public static void Rebuild(
        string srcXci, string dstXci,
        IReadOnlyList<Hfs0File> newSecure,
        IReadOnlyList<Hfs0File> newUpdate,
        NscbKeys? keys,
        Action<long>? progress = null,
        CancellationToken ct = default)
    {
        var partitions = Read(srcXci);
        var lookup = new Dictionary<string, ContainerEntry>(StringComparer.Ordinal);
        foreach (var e in partitions.UpdateEntries) lookup[StripPrefix(e.Name)] = e;
        foreach (var e in partitions.SecureEntries) lookup[StripPrefix(e.Name)] = e;

        // Filesystem lookup for opening data by name (source path is captured per-entry).
        var srcByEntry = new Dictionary<string, ContainerEntry>(StringComparer.Ordinal);
        foreach (var e in partitions.UpdateEntries) srcByEntry[StripPrefix(e.Name)] = e;
        foreach (var e in partitions.SecureEntries) srcByEntry[StripPrefix(e.Name)] = e;

        Span<byte> xciKey = stackalloc byte[0x10];
        bool hasKey = keys?.TryCopyXciHeaderKey(xciKey) ?? false;

        using var output = File.Create(dstXci);
        XciBuilder.Build(
            output,
            newSecure,
            f =>
            {
                var entry = srcByEntry[f.Name];
                var fs = File.OpenRead(srcXci);
                fs.Position = entry.Offset;
                return fs;
            },
            hasKey,
            hasKey ? xciKey : default,
            progress,
            ct,
            newUpdate);
    }

    private static Hfs0File MakeHfs0File(string path, ContainerEntry e)
    {
        byte[] hash;
        using (var s = File.OpenRead(path))
        {
            s.Position = e.Offset;
            hash = Hfs0Builder.ComputeFileHash(s, e.Size);
        }
        return new Hfs0File { Name = StripPrefix(e.Name), Size = e.Size, Hash = hash };
    }

    private static string StripPrefix(string name)
    {
        int i = name.IndexOf('/');
        return i < 0 ? name : name[(i + 1)..];
    }
}

/// <summary>
/// NSCB-compatible XCI editing: -t trim, --xci_super_trim, erase delta fragments.
/// All variants rebuild via <see cref="XciEditor.Rebuild"/>, which regenerates
/// the root/secure HFS0 headers and the card-header hashes/lengths.
/// </summary>
public static class XciTrimmer
{
    /// <summary>Drop the entire update partition, keep secure intact (= NSCB "-t trim").</summary>
    public static void Trim(string srcXci, string dstXci, NscbKeys? keys,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        var p = XciEditor.Read(srcXci);
        XciEditor.Rebuild(srcXci, dstXci, p.SecureFiles, new List<Hfs0File>(), keys, progress, ct);
    }

    /// <summary>
    /// De-duplicate the update partition: when several versions of the same update title are
    /// present, keep only the highest <c>TitleVersion</c> (and the content NCAs its cnmt
    /// references), dropping the superseded delta/update chains (= NSCB "--xci_super_trim").
    /// </summary>
    public static void SuperTrim(string srcXci, string dstXci, NscbKeys keys,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        var p = XciEditor.Read(srcXci);

        // Parse every update partition cnmt; those we can't open are always preserved.
        var cnmts = new List<CnmtInfo>();
        var parsedNames = new HashSet<string>(StringComparer.Ordinal);
        foreach (var upd in p.UpdateFiles)
        {
            ct.ThrowIfCancellationRequested();
            if (!upd.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)) continue;
            CnmtInfo? info = ReadCnmtInfo(srcXci, upd.Name, keys);
            if (info is null) continue;
            cnmts.Add(info.Value);
            parsedNames.Add(upd.Name);
        }

        // Group by exact update title id; the winner is the highest version of that title.
        var winners = cnmts
            .GroupBy(c => c.TitleId)
            .Select(g => g.OrderByDescending(c => c.Version).First())
            .ToList();
        var winnerNames = winners.Select(w => w.Name).ToHashSet(StringComparer.Ordinal);

        // Content NCAs kept = referenced by any winner.
        var keepContent = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var w in winners)
            foreach (var id in w.ContentIds) keepContent.Add(id);

        // Content NCAs to drop = referenced only by losing cnmts (never shared with a winner).
        var dropContent = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var c in cnmts)
        {
            if (winnerNames.Contains(c.Name)) continue;
            foreach (var id in c.ContentIds)
                if (!keepContent.Contains(id)) dropContent.Add(id);
        }

        var keepUpdates = new List<Hfs0File>();
        foreach (var upd in p.UpdateFiles)
        {
            ct.ThrowIfCancellationRequested();
            bool isCnmt = upd.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase);
            if (isCnmt)
            {
                // Keep winner cnmts and any cnmt we couldn't parse; drop losing duplicates.
                if (winnerNames.Contains(upd.Name) || !parsedNames.Contains(upd.Name))
                    keepUpdates.Add(upd);
            }
            else
            {
                string id = NcaIdFromName(upd.Name);
                if (id.Length == 0 || !dropContent.Contains(id)) keepUpdates.Add(upd);
            }
        }

        XciEditor.Rebuild(srcXci, dstXci, p.SecureFiles, keepUpdates, keys, progress, ct);
    }

    /// <summary>Remove NCAs referenced as DeltaFragment in any secure cnmt (= NSCB "-ND true").</summary>
    public static void EraseDeltaFragments(string srcXci, string dstXci, NscbKeys keys,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        var p = XciEditor.Read(srcXci);
        var deltaIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var sec in p.SecureFiles)
        {
            ct.ThrowIfCancellationRequested();
            if (!sec.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)) continue;
            CnmtInfo? info = ReadCnmtInfo(srcXci, sec.Name, keys);
            if (info is null) continue;
            foreach (var id in info.Value.DeltaIds) deltaIds.Add(id);
        }
        var kept = new List<Hfs0File>();
        foreach (var f in p.SecureFiles)
        {
            ct.ThrowIfCancellationRequested();
            string id = NcaIdFromName(f.Name);
            if (id.Length != 0 && deltaIds.Contains(id)) continue;
            kept.Add(f);
        }
        XciEditor.Rebuild(srcXci, dstXci, kept, p.UpdateFiles, keys, progress, ct);
    }

    // A parsed update/secure cnmt: owning title id, version, all referenced content ids,
    // and the subset of those ids that are delta fragments.
    private readonly record struct CnmtInfo(
        string Name, ulong TitleId, uint Version,
        IReadOnlyList<string> ContentIds, IReadOnlyList<string> DeltaIds);

    private static CnmtInfo? ReadCnmtInfo(string xciPath, string cnmtNcaName, NscbKeys keys)
    {
        var cn = ReadCnmt(xciPath, cnmtNcaName, keys);
        if (cn is null) return null;
        var content = new List<string>();
        var deltas = new List<string>();
        foreach (var ce in cn.ContentEntries)
        {
            string id = NscbCore.Info.NcaIdFormatter.ToHex(ce.NcaId ?? new byte[0x10]);
            content.Add(id);
            if (ce.Type == ContentType.DeltaFragment) deltas.Add(id);
        }
        return new CnmtInfo(cnmtNcaName, (ulong)cn.TitleId, cn.TitleVersion.Version, content, deltas);
    }

    // NCA id (32 hex chars) that a partition entry name is based on, or "" when not a content NCA.
    private static string NcaIdFromName(string name)
    {
        string stem = IOPath.GetFileNameWithoutExtension(name);
        if (stem.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase))
            stem = stem[..^5];
        return stem.Length >= 32 ? stem[..32] : "";
    }

    private static Cnmt? ReadCnmt(string xciPath, string cnmtNcaName, NscbKeys keys)
    {
        try
        {
            var all = ReadEntriesSafe(xciPath);
            var entry = all.FirstOrDefault(e => XciEditorStrip(e.Name).Equals(cnmtNcaName, StringComparison.Ordinal));
            if (entry is null) return null;
            byte[] raw = new byte[entry.Size];
            using (var fs = File.OpenRead(xciPath)) { fs.Position = entry.Offset; fs.ReadExactly(raw); }
            using var ms = new MemoryStorage(raw);
            var nca = new Nca(keys.KeySet, ms);
            var fsys = nca.OpenFileSystem(0, IntegrityCheckLevel.None);
            LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IFile> h = default;
            var p = new LibHac.Fs.Path();
            foreach (var nm in Enumerate(fsys))
            {
                if (!nm.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase)) continue;
                p.Initialize(System.Text.Encoding.UTF8.GetBytes("/" + nm)).ThrowIfFailure();
                fsys.OpenFile(ref h, in p, LibHac.Fs.OpenMode.Read).ThrowIfFailure();
                h.Get.GetSize(out long sz).ThrowIfFailure();
                byte[] buf = new byte[sz];
                h.Get.Read(out _, 0, buf, LibHac.Fs.ReadOption.None).ThrowIfFailure();
                h.Destroy();
                return new Cnmt(new MemoryStream(buf));
            }
        }
        catch { }
        return null;
    }

    private static List<ContainerEntry> ReadEntriesSafe(string xci)
    {
        using var probe = File.OpenRead(xci);
        return ContainerReader.ReadEntries(probe, ContainerReader.DetectKind(xci));
    }

    private static string XciEditorStrip(string name)
    { int i = name.IndexOf('/'); return i < 0 ? name : name[(i + 1)..]; }

    private static IEnumerable<string> Enumerate(LibHac.Fs.Fsa.IFileSystem fs)
    {
        LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IDirectory> d = default;
        var p = new LibHac.Fs.Path();
        p.Initialize(System.Text.Encoding.UTF8.GetBytes("/")).ThrowIfFailure();
        fs.OpenDirectory(ref d, in p, LibHac.Fs.Fsa.OpenDirectoryMode.All).ThrowIfFailure();
        try
        {
            var buf = new LibHac.Fs.DirectoryEntry[64];
            while (true)
            {
                d.Get.Read(out long read, buf).ThrowIfFailure();
                for (int i = 0; i < read; i++)
                {
                    var nm = buf[i].Name.ItemsRo;
                    int e = nm.IndexOf((byte)0); if (e < 0) e = nm.Length;
                    yield return System.Text.Encoding.UTF8.GetString(nm[..e]);
                }
                if (read < buf.Length) break;
            }
        }
        finally { d.Destroy(); }
    }
}
