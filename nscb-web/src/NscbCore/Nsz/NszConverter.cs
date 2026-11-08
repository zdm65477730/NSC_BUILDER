using LibHac.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using NscbCore.Formats;
using NscbCore.Keys;

namespace NscbCore.Nsz;

/// <summary>
/// Container-level NSZ ↔ NSP and XCZ → XCI conversions.
/// Two-pass: per-file processing goes to temp files first, then the final PFS0/HFS0
/// container is written with correct sizes in a single sequential pass.
/// </summary>
public static class NszConverter
{
    // Windows enforces file sharing; open inputs with FileShare.ReadWrite (as LibHac's LocalStorage does)
    // so an antivirus/indexer handle — or our own second open — never causes a sharing violation.
    static FileStream OpenReadShared(string path) => new(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);

    // ── NSZ → NSP ────────────────────────────────────────────────────────────────

    /// <summary>
    /// Decompress an NSZ to a plain NSP. Every .ncz entry is expanded back to .nca;
    /// all other entries (tik, cert, xml, uncompressed .nca) are copied unchanged.
    /// No prod.keys required (NCZ headers are self-contained).
    /// </summary>
    public static void NszToNsp(string nszPath, string nspPath,
        Action<long>? progress = null, CancellationToken ct = default, int parallelism = 1)
    {
        if (ContainerReader.DetectKind(nszPath) != ContainerKind.Nsz)
            throw new InvalidDataException($"Expected an NSZ source: {nszPath}");

        List<ContainerEntry> entries;
        using (var probe = OpenReadShared(nszPath))
            entries = ContainerReader.ReadEntries(probe, ContainerKind.Nsz);

        var tempFiles = new List<(string FinalName, string TempPath)>();
        string tempDir = NewTempDir("nscb-nsz");
        var results = new (string FinalName, string TempPath)[entries.Count];

        try
        {
            // Decompress each entry (NCA/.ncz) into its own temp file; parallel across entries while
            // preserving order. Each worker opens its own read stream to the source.
            int degree = NscbCore.Compression.Parallelizer.Clamp(parallelism, entries.Count);
            NscbCore.Compression.Parallelizer.ForIndex(entries.Count, degree, i =>
            {
                var e = entries[i];
                ct.ThrowIfCancellationRequested();
                string outName = e.IsNcz ? Path.ChangeExtension(e.BaseName, ".nca") : e.BaseName;
                string tempPath = Path.Combine(tempDir, Guid.NewGuid().ToString("N"));

                using (var src = OpenReadShared(nszPath))
                using (var dest = new FileStream(tempPath, FileMode.Create, FileAccess.ReadWrite))
                {
                    if (e.IsNcz)
                    {
                        using var bounded = new BoundedReadStream(src, e.Offset, e.Size);
                        NczProcessor.Decompress(bounded, dest, progress, ct);
                    }
                    else
                    {
                        src.Position = e.Offset;
                        StreamCopy(src, dest, e.Size, progress, ct);
                    }
                }
                results[i] = (outName, tempPath);
            });
            tempFiles.AddRange(results);

            WritePfs0FromTemps(nspPath, tempFiles, progress, ct);
        }
        finally { TryDeleteDir(tempDir); }
    }

    // ── NSP → NSZ ────────────────────────────────────────────────────────────────

    /// <summary>
    /// Compress an NSP to NSZ. Program and PublicData NCAs are compressed to .ncz;
    /// all other entries are copied unchanged.
    /// Requires the header key from prod.keys to read NCA section plaintext.
    /// </summary>
    public static void NspToNsz(string nspPath, string nszPath, NscbKeys keys, int zstdLevel = 17,
        Action<long>? progress = null, CancellationToken ct = default, int parallelism = 1, Action<string>? onStep = null)
    {
        if (ContainerReader.DetectKind(nspPath) != ContainerKind.Nsp)
            throw new InvalidDataException($"Expected an NSP source: {nspPath}");
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("NCA compression requires the header key in prod.keys.");

        // Recover rights-id title keys from the source's own tickets so the Program NCA decrypts with prod.keys
        // alone (no title.keys file — that input was removed; titles.json is metadata only). Best-effort per container.
        NscbCore.Keys.TicketTitleKeys.RegisterFromContainer(keys, nspPath);

        List<ContainerEntry> entries;
        using (var probe = OpenReadShared(nspPath))
            entries = ContainerReader.ReadEntries(probe, ContainerKind.Nsp);

        var tempFiles = new (string FinalName, string TempPath)[entries.Count];
        string tempDir = NewTempDir("nscb-nsp");
        // Iterate NCAs sequentially; the thread budget is spent as per-NCA zstd MT workers (parallelism),
        // so files-in-batch parallelism × per-file MT never over-subscribes the cores.
        int degree = 1;

        try
        {
            // NCAs are handled one after another (degree=1); each heavy NCA's zstd runs multi-threaded
            // (see NczProcessor.Compress `parallelism` = MT workers). Results are written back by index so
            // the PFS0 entry order stays deterministic. The copy branch keeps the file order for the batch.
            NscbCore.Compression.Parallelizer.ForIndex(entries.Count, degree, i =>
            {
                var e = entries[i];
                ct.ThrowIfCancellationRequested();
                string tempPath = Path.Combine(tempDir, Guid.NewGuid().ToString("N"));
                using var taskStorage = new LocalStorage(nspPath, FileAccess.Read);

                if (e.IsNca && IsCompressible(taskStorage, e, keys))
                {
                    onStep?.Invoke($"压缩 {e.BaseName}（{e.Size / 1_048_576} MB）");
                    string nczName = Path.ChangeExtension(e.BaseName, ".ncz");
                    using (var nczOut = File.Create(tempPath))
                    {
                        var sub = new LibHac.Fs.SubStorage(taskStorage, e.Offset, e.Size);
                        NczProcessor.Compress(sub, e.Size, nczOut, keys.KeySet, zstdLevel, progress, ct, parallelism);
                    }
                    tempFiles[i] = (nczName, tempPath);
                }
                else
                {
                    onStep?.Invoke($"直通复制 {e.BaseName}");
                    using (var dest = File.Create(tempPath))
                    using (var srcFs = OpenReadShared(nspPath))
                    {
                        srcFs.Position = e.Offset;
                        StreamCopy(srcFs, dest, e.Size, progress, ct);
                    }
                    tempFiles[i] = (e.BaseName, tempPath);
                }
            }, ct);

            onStep?.Invoke("写出 NSZ 容器");
            WritePfs0FromTemps(nszPath, tempFiles, progress, ct);
        }
        finally { TryDeleteDir(tempDir); }
    }

    // ── XCZ → XCI ────────────────────────────────────────────────────────────────

    /// <summary>
    /// Decompress an XCZ's secure partition entries back to plain NCA, rebuild the XCI.
    /// No prod.keys required. The update partition is dropped (empty in NSZ-built XCZs).
    /// </summary>
    public static void XczToXci(string xczPath, string xciPath,
        Action<long>? progress = null, CancellationToken ct = default, int parallelism = 1)
    {
        if (ContainerReader.DetectKind(xczPath) != ContainerKind.Xcz)
            throw new InvalidDataException($"Expected an XCZ source: {xczPath}");

        List<ContainerEntry> entries;
        using (var probe = OpenReadShared(xczPath))
            entries = ContainerReader.ReadEntries(probe, ContainerKind.Xcz)
                .Where(e => e.Name.StartsWith("secure/", StringComparison.OrdinalIgnoreCase))
                .ToList();

        // Pass 1: decompress NCZ → NCA into temp files; record path map.
        var tempMap = new Dictionary<string, string>(); // finalName → tempPath
        string tempDir = NewTempDir("nscb-xcz");

        try
        {
            // Pass 1: decompress each secure/ entry in parallel (own read stream per worker), preserving order.
            var results = new (string OutName, string TempPath)[entries.Count];
            int degree = NscbCore.Compression.Parallelizer.Clamp(parallelism, entries.Count);
            NscbCore.Compression.Parallelizer.ForIndex(entries.Count, degree, i =>
            {
                var e = entries[i];
                ct.ThrowIfCancellationRequested();
                string outName = e.IsNcz ? Path.ChangeExtension(e.BaseName, ".nca") : e.BaseName;
                string tempPath = Path.Combine(tempDir, Guid.NewGuid().ToString("N"));

                using (var src = OpenReadShared(xczPath))
                using (var dest = new FileStream(tempPath, FileMode.Create, FileAccess.ReadWrite))
                {
                    if (e.IsNcz)
                    {
                        using var bounded = new BoundedReadStream(src, e.Offset, e.Size);
                        NczProcessor.Decompress(bounded, dest, progress, ct);
                    }
                    else
                    {
                        src.Position = e.Offset;
                        StreamCopy(src, dest, e.Size, progress, ct);
                    }
                }
                results[i] = (outName, tempPath);
            });
            foreach (var r in results) tempMap[r.OutName] = r.TempPath;

            // Pass 2: build Hfs0File list (size + hash from temp files).
            var hfsFiles = new List<Hfs0File>();
            foreach (var (name, tempPath) in tempMap)
            {
                long size = new FileInfo(tempPath).Length;
                byte[] hash;
                using (var s = OpenReadShared(tempPath))
                    hash = Hfs0Builder.ComputeFileHash(s, size);
                hfsFiles.Add(new Hfs0File { Name = name, Size = size, Hash = hash });
            }

            // Build XCI with decompressed entries.
            Span<byte> xciKey = stackalloc byte[0x10];
            using var xciOut = File.Create(xciPath);
            XciBuilder.Build(xciOut, hfsFiles,
                file => OpenReadShared(tempMap[file.Name]),
                hasXciHeaderKey: false, xciKey,
                progress, ct);
        }
        finally { TryDeleteDir(tempDir); }
    }

    // ── XCI → XCZ ───────────────────────────────────────────────────────────────

    /// <summary>
    /// Compress the Program/PublicData NCAs in an XCI's secure partition to NCZ,
    /// then rebuild the XCI (which becomes an XCZ). Requires prod.keys for NCA decryption.
    /// </summary>
    public static void XciToXcz(string xciPath, string xczPath, NscbKeys keys, int zstdLevel = 17,
        Action<long>? progress = null, CancellationToken ct = default, int parallelism = 1, Action<string>? onStep = null)
    {
        if (ContainerReader.DetectKind(xciPath) != ContainerKind.Xci)
            throw new InvalidDataException($"Expected an XCI source: {xciPath}");
        if (!keys.HasHeaderKey)
            throw new InvalidOperationException("XCI→XCZ requires the header key in prod.keys.");

        // Recover rights-id title keys from the card's own tickets so the Program NCA decrypts with prod.keys alone.
        NscbCore.Keys.TicketTitleKeys.RegisterFromContainer(keys, xciPath);

        List<ContainerEntry> entries;
        using (var probe = OpenReadShared(xciPath))
            entries = ContainerReader.ReadEntries(probe, ContainerKind.Xci)
                .Where(e => e.Name.StartsWith("secure/", StringComparison.OrdinalIgnoreCase))
                .ToList();

        var tempMap = new Dictionary<string, string>();
        string tempDir = NewTempDir("nscb-xcz-pack");
        // Sequential NCAs; parallelism = per-NCA zstd MT workers (see NspToNsz).
        try
        {
            // Sequential NCAs; parallelism = per-NCA zstd MT workers (batch file-parallel is handled above,
            // so file-parallelism × this never over-subscribes). Each worker opens its own read storage.
            var results = new (string OutName, string TempPath)[entries.Count];
            int degree = 1;
            NscbCore.Compression.Parallelizer.ForIndex(entries.Count, degree, i =>
            {
                var e = entries[i];
                ct.ThrowIfCancellationRequested();
                string outName = e.BaseName;
                string tempPath = Path.Combine(tempDir, Guid.NewGuid().ToString("N"));
                using var fileStorage = new LocalStorage(xciPath, FileAccess.Read);

                if (e.IsNca && IsCompressible(fileStorage, e, keys))
                {
                    onStep?.Invoke($"压缩 {e.BaseName}（{e.Size / 1_048_576} MB）");
                    outName = Path.ChangeExtension(outName, ".ncz");
                    using var nczOut = File.Create(tempPath);
                    var sub = new LibHac.Fs.SubStorage(fileStorage, e.Offset, e.Size);
                    NczProcessor.Compress(sub, e.Size, nczOut, keys.KeySet, zstdLevel, progress, ct, parallelism);
                }
                else
                {
                    onStep?.Invoke($"直通复制 {e.BaseName}");
                    using var dest = File.Create(tempPath);
                    using var srcFs = OpenReadShared(xciPath);
                    srcFs.Position = e.Offset;
                    StreamCopy(srcFs, dest, e.Size, progress, ct);
                }
                results[i] = (outName, tempPath);
            });
            foreach (var r in results) tempMap[r.OutName] = r.TempPath;

            // Build Hfs0File list.
            var hfsFiles = new List<Hfs0File>();
            foreach (var (name, tp) in tempMap)
            {
                long size = new FileInfo(tp).Length;
                byte[] hash;
                using (var s = OpenReadShared(tp))
                    hash = Hfs0Builder.ComputeFileHash(s, size);
                hfsFiles.Add(new Hfs0File { Name = name, Size = size, Hash = hash });
            }

            Span<byte> xciKey = stackalloc byte[0x10];
            bool hasXciKey = keys.TryCopyXciHeaderKey(xciKey);
            onStep?.Invoke("写出 XCZ 容器");
            using var xczOutFs = File.Create(xczPath);
            XciBuilder.Build(xczOutFs, hfsFiles,
                file => OpenReadShared(tempMap[file.Name]),
                hasXciKey, hasXciKey ? xciKey : default,
                progress, ct);
        }
        finally { TryDeleteDir(tempDir); }
    }

    // ── Helpers ──────────────────────────────────────────────────────────────────

    private static bool IsCompressible(LocalStorage storage, ContainerEntry entry, NscbKeys keys)
    {
        try
        {
            var sub = new LibHac.Fs.SubStorage(storage, entry.Offset, entry.Size);
            var nca = new Nca(keys.KeySet, sub);
            if (nca.Header.ContentType is not (NcaContentType.Program or NcaContentType.PublicData))
                return false;
            // Requires title key to actually decrypt the sections; skip (copy as .nca)
            // when the ticket's key isn't available locally.
            if (nca.Header.HasRightsId)
            {
                try { _ = nca.GetDecryptedTitleKey(); }
                catch { return false; }
            }
            return true;
        }
        catch { return false; }
    }

    private static void WritePfs0FromTemps(string outputPath,
        IReadOnlyList<(string FinalName, string TempPath)> tempFiles,
        Action<long>? progress, CancellationToken ct)
    {
        var items = tempFiles
            .Select(t => (t.FinalName, size: new FileInfo(t.TempPath).Length))
            .ToList();

        using var outFs = File.Create(outputPath);
        var writer = new Pfs0Writer(outFs);
        foreach (var (name, size) in items)
            writer.AddFile(name, size);
        writer.WriteHeader();

        foreach (var (_, tempPath) in tempFiles)
        {
            ct.ThrowIfCancellationRequested();
            using var tfs = OpenReadShared(tempPath);
            writer.CopyFileData(tfs, tfs.Length, progress, ct);
        }
    }

    private static void StreamCopy(Stream source, Stream dest, long limit,
        Action<long>? progress, CancellationToken ct)
    {
        byte[] buf = new byte[0x80000];
        long remaining = limit;
        while (remaining > 0)
        {
            ct.ThrowIfCancellationRequested();
            int read = source.Read(buf, 0, (int)Math.Min(buf.Length, remaining));
            if (read == 0) throw new EndOfStreamException($"Source ended early; {remaining} bytes remaining.");
            dest.Write(buf, 0, read);
            remaining -= read;
            progress?.Invoke(read);
        }
    }

    private static string NewTempDir(string prefix)
    {
        string dir = Path.Combine(Path.GetTempPath(), $"{prefix}-{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        return dir;
    }

    private static void TryDeleteDir(string dir)
    {
        try { Directory.Delete(dir, recursive: true); } catch { /* best effort */ }
    }
}

/// <summary>Read-only window over a region of a <see cref="Stream"/>; does not own the underlying stream.</summary>
internal sealed class BoundedReadStream(Stream baseStream, long offset, long length) : Stream
{
    private long _pos;

    public override bool CanRead => true;
    public override bool CanSeek => true;
    public override bool CanWrite => false;
    public override long Length => length;
    public override long Position { get => _pos; set => _pos = Math.Clamp(value, 0, length); }

    public override void Flush() { }

    public override int Read(byte[] buffer, int index, int count)
    {
        long remaining = length - _pos;
        if (remaining <= 0) return 0;
        baseStream.Position = offset + _pos;
        int r = baseStream.Read(buffer, index, (int)Math.Min(count, remaining));
        _pos += r;
        return r;
    }

    public override long Seek(long o, SeekOrigin origin) => origin switch
    {
        SeekOrigin.Begin   => Position = o,
        SeekOrigin.Current => Position += o,
        _                  => Position = length + o,
    };

    public override void SetLength(long v) => throw new NotSupportedException();
    public override void Write(byte[] b, int i, int c) => throw new NotSupportedException();
    protected override void Dispose(bool disposing) { /* don't close baseStream */ }
}
