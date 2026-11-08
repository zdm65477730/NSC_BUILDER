using System.Buffers.Binary;
using System.Text;
using System.Text.RegularExpressions;
using LibHac.Fs;
using LibHac.FsSystem;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Formats;
using NscbCore.Keys;
using NscbCore.Nsz;
using IOPath = System.IO.Path;

namespace NscbCore.Info;

/// <summary>
/// Fields parsed from a Program NCA's <c>main.npdm</c> (Nintendo Process Module Data):
/// the ACI0 title id, the ACID allowed-id range and flags, the filesystem/service access
/// controls, and the descriptive header (title name / product code / process category).
/// </summary>
public sealed record NpdmInfo
{
    public required string SourceFile { get; init; }
    public string? TitleName { get; init; }
    public string? ProductCode { get; init; }
    public string? ProcessCategory { get; init; }
    public string? TitleId { get; init; }
    public string? AllowedIdMin { get; init; }
    public string? AllowedIdMax { get; init; }
    public uint? AcidFlags { get; init; }
    public byte? FsAccessVersion { get; init; }
    public ulong? FsPermissions { get; init; }
    public IReadOnlyList<string> Services { get; init; } = [];
}

/// <summary>
/// Reads NPDM access-control information from a Program NCA, porting NSCB's
/// <c>pyNPDM</c> semantics (ACI0 / ACID / FsAccessControl / ServiceAccessControl).
/// </summary>
/// <remarks>
/// The ACI0/ACID blocks are located by scanning for their ASCII magic, so this works
/// whether <c>main.npdm</c> begins with the legacy "META" header or the "NPMI" module
/// header. Descriptive header fields are only surfaced for the "META" layout NSCB uses.
/// </remarks>
public static class NpdmInfoReader
{
    private static readonly string[] ProcessCategories = { "Regular title", "Kernel built-in" };

    // ServiceAccessControl entries: a length byte 0x02..0x07 followed by the ASCII name.
    private static readonly Regex ServiceRx =
        new(@"[\x02-\x07]([a-z0-9-_]+(?::[a-z0-9-_]+)*)", RegexOptions.IgnoreCase | RegexOptions.Compiled);

    // Cache by path + last-write, so re-opening the Npdm tab is instant (parsing an NSZ's Program
    // NCA can require decompressing a large section).
    private static readonly Dictionary<string, (NpdmInfo? Info, string? Reason)> _cache = new();

    /// <summary>Find and parse the NPDM of the Program NCA inside a container (handles NSZ/XCZ .ncz).</summary>
    public static NpdmInfo? ReadFromContainer(string containerPath, NscbKeys keys) => Inspect(containerPath, keys).Info;

    /// <summary>Like <see cref="ReadFromContainer"/> but also returns a reason when it fails:
    /// "no-program" (container has no Program NCA, e.g. update/DLC only) or
    /// "cannot-open" (a Program NCA exists but its ExeFS/main.npdm can't be read — usually a missing title key).</summary>
    public static (NpdmInfo? Info, string? Reason) Inspect(string containerPath, NscbKeys keys)
    {
        string ck;
        try { ck = containerPath + "|" + File.GetLastWriteTimeUtc(containerPath).Ticks; }
        catch { return InspectCore(containerPath, keys); }
        lock (_cache) if (_cache.TryGetValue(ck, out var hit)) return hit;
        NscbCore.Keys.TicketTitleKeys.RegisterFromContainer(keys, containerPath);   // derive title keys from the container's own tickets (prod.keys-only, NSGManager-style)
        var res = InspectCore(containerPath, keys);
        lock (_cache) { _cache[ck] = res; if (_cache.Count > 48) _cache.Clear(); }
        return res;
    }

    private static (NpdmInfo? Info, string? Reason) InspectCore(string containerPath, NscbKeys keys)
    {
        ContainerKind kind = ContainerReader.DetectKind(containerPath);
        List<ContainerEntry> entries;
        using (var probe = new FileStream(containerPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            entries = ContainerReader.ReadEntries(probe, kind)
                .Where(e => !e.Name.StartsWith("normal/", StringComparison.OrdinalIgnoreCase)
                         && !e.Name.StartsWith("logo/", StringComparison.OrdinalIgnoreCase))
                .ToList();

        using var storage = new LocalStorage(containerPath, FileAccess.Read);
        using var raw = new FileStream(containerPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);

        bool sawProgram = false;
        foreach (var e in entries)
        {
            if (!e.IsNca && !e.IsNcz) continue;
            try
            {
                if (e.IsNcz)
                {
                    var (t, nd) = ReadNczWithFallback(raw, e, keys);
                    if (t != NcaContentType.Program) continue;
                    sawProgram = true;
                    if (nd is not null) return (Parse(nd, IOPath.GetFileName(e.BaseName)), null);
                    continue;
                }
                var nca = new Nca(keys.KeySet, new LibHac.Fs.SubStorage(storage, e.Offset, e.Size));
                if (nca.Header.ContentType != NcaContentType.Program) continue;
                sawProgram = true;
                byte[]? npdm = ReadMainNpdm(nca);
                if (npdm is null) continue;
                return (Parse(npdm, IOPath.GetFileName(e.Name)), null);
            }
            catch { continue; }
        }
        return (null, sawProgram ? "cannot-open" : "no-program");
    }

    // Read an NCZ's main.npdm by decompressing only up to the end of the non-largest FS section
    // (usually all but the trailing RomFS), so ExeFS is reached in one pass. Falls back to a full
    // decompress if that prefix didn't contain the NPDM (e.g. unusual section order).
    private static (NcaContentType Type, byte[]? Npdm) ReadNczWithFallback(Stream raw, ContainerEntry e, NscbKeys keys)
    {
        long prefix = 0;
        try
        {
            long saved = raw.Position;
            raw.Position = e.Offset;
            prefix = NpdmPrefix(NczHeader.Parse(raw));
            raw.Position = saved;
        }
        catch { prefix = 0; }

        NcaContentType type = default;
        var caps = prefix > 0 ? new long[] { prefix, 0L } : new long[] { 0L };
        foreach (long cap in caps)
        {
            string tmp = IOPath.Combine(IOPath.GetTempPath(), "nscb-npdm-" + Guid.NewGuid().ToString("N") + ".nca");
            try
            {
                using (var tf = new FileStream(tmp, FileMode.Create, FileAccess.ReadWrite, FileShare.ReadWrite))
                using (var b = new BoundedReadStream(raw, e.Offset, e.Size))
                    NczProcessor.Decompress(b, tf, cap, null, default);
                using var ls = new LocalStorage(tmp, FileAccess.Read);
                var nca = new Nca(keys.KeySet, ls);
                type = nca.Header.ContentType;
                if (type != NcaContentType.Program) return (type, null);
                byte[]? nd = ReadMainNpdm(nca);
                if (nd is not null || cap == 0) return (type, nd);
            }
            finally { try { File.Delete(tmp); } catch { } }
        }
        return (type, null);
    }

    // Compute the leading NCA bytes needed to reach ExeFS from the NCZ section table (authoritative
    // per-section offset/size, no header-byte guessing). Skip only the LARGEST section when it trails
    // the others (the common case: ExeFS before a huge trailing RomFS). Returns 0 when there is
    // nothing to skip (e.g. ExeFS is the last section, as in some titles) → caller does a full pass.
    private static long NpdmPrefix(NczHeader ncz)
    {
        var secs = ncz.Sections;
        if (secs.Count == 0) return 0;
        long maxS = 0; foreach (var s in secs) maxS = Math.Max(maxS, s.Size);
        long end = NczHeader.NcaHeaderSize;
        foreach (var s in secs) if (s.Size != maxS) end = Math.Max(end, s.Offset + s.Size);
        if (end <= 0 || end >= NczHeader.NcaHeaderSize + ncz.DecompressedSize) return 0;
        return end;
    }

    // Locate the Program NCA cheaply: uncompressed NCA via header; .ncz via its embedded NCA header
    // (NczHeader → NcaHeaderFields.ContentTypeByte == 1) — crucially without decompressing.
    private static ContainerEntry? FindProgramEntry(List<ContainerEntry> entries, IStorage storage, Stream raw, NscbKeys keys)
    {
        foreach (var e in entries)
        {
            try
            {
                if (e.IsNca)
                {
                    var nca = new Nca(keys.KeySet, new LibHac.Fs.SubStorage(storage, e.Offset, e.Size));
                    if (nca.Header.ContentType == NcaContentType.Program) return e;
                }
                else if (e.IsNcz)
                {
                    raw.Position = e.Offset;
                    var nh = NczHeader.Parse(raw);
                    var f = NcaHeaderFields.Parse(nh.NcaHeader);
                    if (f.ContentTypeByte == 1) return e;   // Program
                }
            }
            catch { /* not openable / not a program; keep looking */ }
        }
        return null;
    }


    /// <summary>Reads the NPDM (<c>main.npdm</c>) from a Program NCA's ExeFS. Ignores the bare
    /// "main" (the NSO module) — only real <c>*.npdm</c> entries qualify — to avoid parsing garbage.</summary>
    private static byte[]? ReadMainNpdm(Nca nca)
    {
        for (int i = 0; i < 4; i++)
        {
            LibHac.Fs.Fsa.IFileSystem fs;
            try { fs = nca.OpenFileSystem(i, IntegrityCheckLevel.None); }
            catch { continue; }

            foreach (string name in ListEntries(fs))
            {
                bool candidate = name.Equals("main.npdm", StringComparison.OrdinalIgnoreCase)
                    || name.EndsWith(".npdm", StringComparison.OrdinalIgnoreCase);
                if (!candidate) continue;
                byte[] data = ReadFile(fs, "/" + name);
                // Confirm it really is an NPDM before trusting the parse.
                if (IndexOfMagic(data, "ACI0") >= 0 || IndexOfMagic(data, "ACID") >= 0
                    || (data.Length >= 0x14 && (Asciis(data, 0x0, "NPMI") || Asciis(data, 0x10, "NPMI"))))
                    return data;
            }
        }
        return null;
    }

    /// <summary>Parses an in-memory <c>main.npdm</c> blob.</summary>
    public static NpdmInfo Parse(byte[] npdm, string sourceFile)
    {
        string? titleName = null, productCode = null, processCategory = null;

        // Descriptive header (NSCB "META" layout). Only read it when the magic matches,
        // so a "NPMI"-based header simply yields nulls for these secondary fields.
        if (npdm.Length >= 0x20 && Asciis(npdm, 0, "META"))
        {
            titleName = ReadAsciiZ(npdm, 0x20, 0x10);
            productCode = ReadAsciiZ(npdm, 0x30, 0x10);
            int cat = npdm.Length >= 0x1C ? (int)BinaryPrimitives.ReadUInt32LittleEndian(npdm[0x18..]) : -1;
            processCategory = cat >= 0 && cat < ProcessCategories.Length ? ProcessCategories[cat] : cat.ToString();
        }

        string? titleId = FindAci0TitleId(npdm);
        FindAcid(npdm, out string? tidMin, out string? tidMax, out uint? flags, out byte? fsVer, out ulong? fsPerm);

        var services = new List<string>();
        foreach (Match m in ServiceRx.Matches(Encoding.ASCII.GetString(npdm)))
        {
            string s = m.Groups[1].Value;
            if (s.Length >= 2 && !services.Contains(s, StringComparer.OrdinalIgnoreCase))
                services.Add(s);
        }

        return new NpdmInfo
        {
            SourceFile = sourceFile,
            TitleName = titleName,
            ProductCode = productCode,
            ProcessCategory = processCategory,
            TitleId = titleId,
            AllowedIdMin = tidMin,
            AllowedIdMax = tidMax,
            AcidFlags = flags,
            FsAccessVersion = fsVer,
            FsPermissions = fsPerm,
            Services = services,
        };
    }

    private static string? FindAci0TitleId(byte[] npdm)
    {
        int pos = IndexOfMagic(npdm, "ACI0");
        if (pos < 0) return null;
        // ACI0: magic at block start, title id (u64) at block + 0x10.
        int tid = pos + 0x10;
        if (tid + 8 > npdm.Length) return null;
        return BinaryPrimitives.ReadUInt64LittleEndian(npdm[tid..]).ToString("x16");
    }

    private static void FindAcid(byte[] npdm, out string? tidMin, out string? tidMax,
        out uint? flags, out byte? fsVersion, out ulong? fsPerm)
    {
        tidMin = tidMax = null; flags = null; fsVersion = null; fsPerm = null;
        int magic = IndexOfMagic(npdm, "ACID");
        if (magic < 0) return;
        // The "ACID" magic sits at block + 0x200 (RSA sig 0x100 + public key 0x100 precede it).
        int block = magic - 0x200;
        if (block < 0) block = magic; // tolerate a header without the leading signatures

        if (magic + 0x0C + 4 <= npdm.Length) flags = BinaryPrimitives.ReadUInt32LittleEndian(npdm[(magic + 0x0C)..]);
        if (magic + 0x10 + 8 <= npdm.Length) tidMin = BinaryPrimitives.ReadUInt64LittleEndian(npdm[(magic + 0x10)..]).ToString("x16");
        if (magic + 0x18 + 8 <= npdm.Length) tidMax = BinaryPrimitives.ReadUInt64LittleEndian(npdm[(magic + 0x18)..]).ToString("x16");

        // FsAccessControl lives at fs_offset within the ACID block; read version/permissions.
        if (magic + 0x20 + 4 <= npdm.Length)
        {
            uint fsOffRel = BinaryPrimitives.ReadUInt32LittleEndian(npdm[(magic + 0x20)..]);
            int fsAbs = block + (int)fsOffRel;
            if (fsAbs >= 0 && fsAbs + 0xC <= npdm.Length)
            {
                fsVersion = npdm[fsAbs];
                fsPerm = BinaryPrimitives.ReadUInt64LittleEndian(npdm[(fsAbs + 4)..]);
            }
        }
    }

    private static int IndexOfMagic(byte[] data, string magic)
    {
        byte[] m = Encoding.ASCII.GetBytes(magic);
        for (int i = 0; i + m.Length <= data.Length; i++)
        {
            bool hit = true;
            for (int j = 0; j < m.Length; j++)
                if (data[i + j] != m[j]) { hit = false; break; }
            if (hit) return i;
        }
        return -1;
    }

    private static bool Asciis(byte[] data, int offset, string magic)
    {
        if (offset + magic.Length > data.Length) return false;
        for (int i = 0; i < magic.Length; i++)
            if (data[offset + i] != (byte)magic[i]) return false;
        return true;
    }

    private static string? ReadAsciiZ(byte[] data, int offset, int maxLen)
    {
        if (offset >= data.Length) return null;
        int end = Math.Min(offset + maxLen, data.Length);
        int nul = Array.IndexOf(data, (byte)0, offset, end - offset);
        if (nul >= 0) end = nul;
        string s = Encoding.UTF8.GetString(data, offset, end - offset).Trim();
        return s.Length == 0 ? null : s;
    }

    private static List<string> ListEntries(LibHac.Fs.Fsa.IFileSystem fs)
    {
        var names = new List<string>();
        LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IDirectory> d = default;
        var p = new LibHac.Fs.Path();
        p.Initialize(Encoding.UTF8.GetBytes("/")).ThrowIfFailure();
        fs.OpenDirectory(ref d, in p, LibHac.Fs.Fsa.OpenDirectoryMode.All).ThrowIfFailure();
        try
        {
            var buf = new DirectoryEntry[64];
            while (true)
            {
                d.Get.Read(out long read, buf).ThrowIfFailure();
                for (int i = 0; i < read; i++)
                {
                    ReadOnlySpan<byte> nm = buf[i].Name.ItemsRo;
                    int e = nm.IndexOf((byte)0); if (e < 0) e = nm.Length;
                    names.Add(Encoding.UTF8.GetString(nm[..e]));
                }
                if (read < buf.Length) break;
            }
        }
        finally { d.Destroy(); }
        return names;
    }

    private static byte[] ReadFile(LibHac.Fs.Fsa.IFileSystem fs, string path)
    {
        LibHac.Common.UniqueRef<LibHac.Fs.Fsa.IFile> h = default;
        var p = new LibHac.Fs.Path();
        p.Initialize(Encoding.UTF8.GetBytes(path)).ThrowIfFailure();
        fs.OpenFile(ref h, in p, LibHac.Fs.OpenMode.Read).ThrowIfFailure();
        try
        {
            h.Get.GetSize(out long size).ThrowIfFailure();
            byte[] buf = new byte[size];
            h.Get.Read(out _, 0, buf, LibHac.Fs.ReadOption.None).ThrowIfFailure();
            return buf;
        }
        finally { h.Destroy(); }
    }
}
