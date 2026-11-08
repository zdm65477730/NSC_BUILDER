using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using LibHac.Tools.Ncm;
using NscbCore.Formats;
using NscbCore.Info;
using NscbCore.Keys;
using IOPath = System.IO.Path;

namespace NscbCore.Splitting;

/// <summary>
/// Per-title splitter: reads all cnmts in a container (NSP/NSZ/XCI/XCZ), groups
/// NCA/ticket/cert/xml files by owning title id, and writes one NSP per title.
/// Mirrors NSCB's --dspl / direct_splitter behaviour.
/// </summary>
public static class TitleSplitter
{
    public sealed record TitleGroup(string TitleId, string BaseTitleId, string Kind, ulong Version,
        List<ContainerEntry> Members);

    /// <summary>
    /// Count the distinct titles (games / updates / DLC) contained in a container by scanning its cnmts.
    /// Used to build the "(1G+1U)" composition tag for combined packs.
    /// </summary>
    public static (int Games, int Updates, int DLCs) Composition(string containerPath, NscbKeys keys, CancellationToken ct = default)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz))
            return (0, 0, 0);
        List<ContainerEntry> allEntries;
        using (var probe = File.OpenRead(containerPath))
            allEntries = ContainerReader.ReadEntries(probe, kind)
                .Where(e => !e.Name.StartsWith("update/", StringComparison.OrdinalIgnoreCase)
                         || kind is ContainerKind.Xci or ContainerKind.Xcz)
                .ToList();

        var types = new List<string?>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        using var src = File.OpenRead(containerPath);
        foreach (var meta in allEntries.Where(x =>
                     x.Name.EndsWith(".cnmt.nca", StringComparison.OrdinalIgnoreCase)
                     || x.Name.EndsWith(".cnmt.ncz", StringComparison.OrdinalIgnoreCase)))
        {
            ct.ThrowIfCancellationRequested();
            Cnmt? cn = TryReadCnmt(src, meta, keys);
            if (cn is null) continue;
            if (!seen.Add(cn.TitleId.ToString("x16"))) continue;
            types.Add(cn.Type.ToString());   // tally centralized in PackComposition (unit-tested)
        }
        return NscbCore.Packaging.PackComposition.Classify(types);
    }

    /// <summary>
    /// Split <paramref name="containerPath"/> into per-title NSPs under <paramref name="outDir"/>.
    /// Returns the list of produced files.
    /// </summary>
    public static List<string> Split(
        string containerPath, string? outDir, NscbKeys keys,
        Action<long>? progress = null, CancellationToken ct = default, bool baseAsCard = false)
    {
        // outDir == null/empty → auto: write into a "[<游戏名>].<原始名>" folder next to the 整合包.

        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz or ContainerKind.Xci or ContainerKind.Xcz))
            throw new InvalidDataException($"Unsupported: {kind}");

        List<ContainerEntry> allEntries;
        using (var probe = File.OpenRead(containerPath))
            allEntries = ContainerReader.ReadEntries(probe, kind)
                .Where(e => !e.Name.StartsWith("update/", StringComparison.OrdinalIgnoreCase)
                         || kind is ContainerKind.Xci or ContainerKind.Xcz)
                .ToList();

        // Map NCA SHA-256 id (as hex) → the entry whose file name contains that id.
        // NCAs are named "<16-byte hex>.nca" where the 16-byte hex equals cnmt.ContentEntry.NcaId.
        var byNcaId = new Dictionary<string, ContainerEntry>(StringComparer.OrdinalIgnoreCase);
        foreach (var e in allEntries.Where(x => x.IsNca || x.IsNcz))
        {
            string name = IOPath.GetFileNameWithoutExtension(e.BaseName);
            // strip trailing ".cnmt" if any
            int dot = name.LastIndexOf('.');
            if (dot > 0 && name.Length - dot - 1 == 4) name = name[..dot];
            if (name.Length >= 32 && IsHex(name[..32])) byNcaId[name[..32]] = e;
        }

        // Read every cnmt to build title → members map.
        var titles = new Dictionary<string, TitleGroup>();
        using (var src = File.OpenRead(containerPath))
        {
            foreach (var metaEntry in allEntries.Where(x => x.Name.EndsWith(".cnmt.nca",
                                                                       StringComparison.OrdinalIgnoreCase)
                                                                 || x.Name.EndsWith(".cnmt.ncz",
                                                                       StringComparison.OrdinalIgnoreCase)))
            {
                ct.ThrowIfCancellationRequested();
                Cnmt? cn = TryReadCnmt(src, metaEntry, keys);
                if (cn is null) continue;

                string titleId = cn.TitleId.ToString("x16");
                ulong baseTid = (ulong)cn.TitleId & ~0x1FFFUL & ~0xE00UL; // rough base id
                baseTid = InferBase(cn);
                string kind2 = cn.Type.ToString();

                var members = new List<ContainerEntry> { metaEntry };
                foreach (var ce in cn.ContentEntries)
                {
                    string id = NcaIdFormatter.ToHex(ce.NcaId);
                    if (byNcaId.TryGetValue(id, out var match)) members.Add(match);
                }
                // Attach matching ticket / cert / xml by title-id prefix.
                string tidPrefix = titleId[..16];
                foreach (var t in allEntries.Where(x =>
                    (x.IsTicket || x.IsCert || x.IsXml) && x.BaseName.StartsWith(tidPrefix)))
                    members.Add(t);

                if (!titles.TryGetValue(titleId, out var grp))
                {
                    grp = new TitleGroup(titleId, baseTid.ToString("x16"), kind2, VersionOf(cn), new List<ContainerEntry>());
                    titles[titleId] = grp;
                }
                // Merge members (dedupe by name)
                foreach (var m in members)
                    if (!grp.Members.Any(x => x.Name == m.Name)) grp.Members.Add(m);
            }
        }

        string orig = CleanBaseName(containerPath);
        string gameName = orig;
        try { string? tn = new TitleInfoService(keys).GetFileInfo(containerPath).TitleName; if (!string.IsNullOrWhiteSpace(tn)) gameName = tn.Trim(); } catch { }
        gameName = MakeSafe(gameName); orig = MakeSafe(orig);
        // Default output: a folder "[<游戏名>].<原始名>" beside the 整合包; an explicit outDir is used as-is.
        string destDir = string.IsNullOrWhiteSpace(outDir)
            ? IOPath.Combine(IOPath.GetDirectoryName(containerPath) ?? ".", $"[{gameName}].{orig}")
            : outDir;
        Directory.CreateDirectory(destDir);

        var outputs = new List<string>();
        using (var src = File.OpenRead(containerPath))
        {
            foreach (var grp in titles.Values)
            {
                ct.ThrowIfCancellationRequested();
                bool hasNcz = grp.Members.Any(m => m.IsNcz);
                // "基座还原为卡带" 选项：把 Application(本体) 还原成 XCI/XCZ 卡带镜像；更新/DLC 仍输出 NSP/NSZ。
                bool asCard = baseAsCard && string.Equals(grp.Kind, "Application", StringComparison.OrdinalIgnoreCase);
                string ext = asCard ? (hasNcz ? ".xcz" : ".xci") : (hasNcz ? ".nsz" : ".nsp");
                string tag = KindTag(grp.Kind);
                string namePart = string.IsNullOrEmpty(gameName) ? grp.TitleId.ToUpperInvariant() : gameName;
                string outName = $"{namePart} [{grp.TitleId.ToUpperInvariant()}][v{grp.Version}][{tag}]{ext}";
                string outPath = IOPath.Combine(destDir, MakeSafe(outName));
                if (asCard) WriteCard(outPath, containerPath, grp.Members, keys, progress, ct);
                else WriteNsp(outPath, src, grp.Members, progress, ct);
                outputs.Add(outPath);
            }
        }
        return outputs;
    }

    /// <summary>Default output folder for a container's derived files: "&lt;包所在目录&gt;/[游戏名].原始名",
    /// game name from NACP (falls back to the cleaned filename). Shared by split &amp; extract.</summary>
    public static string DefaultPackageFolder(string containerPath, NscbKeys keys)
    {
        string orig = CleanBaseName(containerPath);
        string gameName = orig;
        try { string? tn = new TitleInfoService(keys).GetFileInfo(containerPath).TitleName; if (!string.IsNullOrWhiteSpace(tn)) gameName = tn.Trim(); } catch { }
        gameName = MakeSafe(gameName); orig = MakeSafe(orig);
        return IOPath.Combine(IOPath.GetDirectoryName(containerPath) ?? ".", $"[{gameName}].{orig}");
    }

    private static string KindTag(string kind) => kind switch
    {
        "Application" => "Base",
        "Patch" or "SystemUpdate" or "Delta" => "UPD",
        "AddOnContent" => "DLC",
        _ => kind,
    };

    private static ulong VersionOf(Cnmt cn) { try { return (ulong)cn.TitleVersion.Version; } catch { return 0; } }

    // Base game name from the source filename: drop the extension and any [..] tags / trailing (n).
    private static string CleanBaseName(string path)
    {
        string s = IOPath.GetFileNameWithoutExtension(path);
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\[[^\]]*\]", " ");
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\([^)]*\)", " ");
        return System.Text.RegularExpressions.Regex.Replace(s, @"\s+", " ").Trim();
    }

    private static string MakeSafe(string s)
    {
        foreach (var ch in IOPath.GetInvalidFileNameChars()) s = s.Replace(ch, ' ');
        s = System.Text.RegularExpressions.Regex.Replace(s, @"\s+", " ").Trim().TrimEnd('.');
        return s.Length > 180 ? s[..180] : s;
    }

    // Rebuild a base game's title members (cnmt + NCA/.ncz + optional ticket/cert) into a card image (XCI, or XCZ
    // when members are compressed .ncz) by placing them verbatim in the secure partition — same passthrough logic
    // as PackXci. Powers the "base → card" split option.
    private static void WriteCard(string outPath, string containerPath, List<ContainerEntry> members,
        NscbKeys keys, Action<long>? progress, CancellationToken ct)
    {
        var secureFiles = new List<Hfs0File>();
        var lookup = new Dictionary<string, (long Offset, long Size)>(StringComparer.OrdinalIgnoreCase);
        foreach (var e in members)
        {
            ct.ThrowIfCancellationRequested();
            string name = IOPath.GetFileName(e.Name);
            byte[] hash;
            using (var s = File.OpenRead(containerPath)) { s.Position = e.Offset; hash = Hfs0Builder.ComputeFileHash(s, e.Size); }
            secureFiles.Add(new Hfs0File { Name = name, Size = e.Size, Hash = hash });
            lookup[name] = (e.Offset, e.Size);
        }
        Span<byte> xciKey = stackalloc byte[0x10];
        bool hasKey = keys.TryCopyXciHeaderKey(xciKey);
        using var dst = File.Create(outPath);
        XciBuilder.Build(dst, secureFiles,
            file => { var fs = File.OpenRead(containerPath); fs.Position = lookup[file.Name].Offset; return fs; },
            hasKey, hasKey ? xciKey : default, progress, ct);
    }

    private static void WriteNsp(string path, Stream src, List<ContainerEntry> entries,
        Action<long>? progress, CancellationToken ct)
    {
        var items = entries.Select(e => (Name: IOPath.GetFileName(e.Name), Size: e.Size)).ToList();
        using var dst = File.Create(path);
        var w = new Pfs0Writer(dst);
        foreach (var it in items) w.AddFile(it.Name, it.Size);
        w.WriteHeader();
        foreach (var e in entries)
        {
            ct.ThrowIfCancellationRequested();
            src.Position = e.Offset;
            long remaining = e.Size;
            byte[] buf = new byte[0x40000];
            while (remaining > 0)
            {
                int r = src.Read(buf, 0, (int)Math.Min(buf.Length, remaining));
                if (r == 0) break;
                w.CopyFileData(new MemoryStream(buf, 0, r), r, progress, ct);
                remaining -= r;
            }
        }
    }

    private static Cnmt? TryReadCnmt(Stream src, ContainerEntry metaEntry, NscbKeys keys)
    {
        try
        {
            src.Position = metaEntry.Offset;
            byte[] raw = new byte[metaEntry.Size];
            src.ReadExactly(raw);
            using var ms = new MemoryStorage(raw);
            var nca = new Nca(keys.KeySet, ms);
            var storage = nca.OpenStorage(0, IntegrityCheckLevel.None);
            storage.GetSize(out long sz).ThrowIfFailure();
            // Enumerate PFS0 files via IFileSystem
            var fsys = nca.OpenFileSystem(0, IntegrityCheckLevel.None);
            LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IFile> h = default;
            var pth = new LibHac.Fs.Path();
            foreach (var entry in EnumerateFiles(fsys))
            {
                if (!entry.EndsWith(".cnmt", StringComparison.OrdinalIgnoreCase)) continue;
                pth.Initialize(System.Text.Encoding.UTF8.GetBytes("/" + entry)).ThrowIfFailure();
                fsys.OpenFile(ref h, in pth, LibHac.Fs.OpenMode.Read).ThrowIfFailure();
                h.Get.GetSize(out long fsz).ThrowIfFailure();
                byte[] buf = new byte[fsz];
                h.Get.Read(out _, 0, buf, LibHac.Fs.ReadOption.None).ThrowIfFailure();
                h.Destroy();
                return new Cnmt(new MemoryStream(buf));
            }
        }
        catch { return null; }
        return null;
    }

    private static IEnumerable<string> EnumerateFiles(LibHac.Fs.Fsa.IFileSystem fs)
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

    private static ulong InferBase(Cnmt cn)
    {
        try
        {
            if (cn.Type == LibHac.Ncm.ContentMetaType.Patch) return (ulong)cn.PatchTitleId;
            return (ulong)cn.TitleId & 0xFFFFFFFFFFFFF000UL;
        }
        catch { return (ulong)cn.TitleId & 0xFFFFFFFFFFFFF000UL; }
    }

    private static bool IsHex(string s)
    {
        foreach (char c in s) if (c is not (>= '0' and <= '9' or >= 'a' and <= 'f' or >= 'A' and <= 'F')) return false;
        return true;
    }
}
