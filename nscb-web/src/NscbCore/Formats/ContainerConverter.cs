using NscbCore.Keys;

namespace NscbCore.Formats;

/// <summary>
/// High-level container conversions. Compression state is passed through unchanged
/// (.ncz stays .ncz), so the same routines cover nsp/xci and nsz/xcz shells;
/// decompression/compression compose orthogonally on top of these.
/// </summary>
public static class ContainerConverter
{
    /// <summary>
    /// Packs the contents of an NSP/NSZ into an XCI/XCZ secure partition.
    /// </summary>
    /// <param name="keys">Keyset for the XCI header key; null or a keyless set yields NSCB's fixed Game_info blob.</param>
    public static void NspToXci(string sourcePath, string outputPath, NscbKeys? keys,
        Action<long>? progress = null, CancellationToken ct = default, int parallelism = 1)
    {
        ContainerKind kind = ContainerReader.DetectKind(sourcePath);
        if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz))
            throw new InvalidDataException($"Expected an NSP/NSZ source, got: {sourcePath}");

        List<ContainerEntry> entries = ReadSourceEntries(sourcePath, kind);
        if (entries.Count == 0)
            throw new InvalidDataException("Source container has no content entries.");

        Span<byte> headerKey = stackalloc byte[0x10];
        bool hasXciKey = keys?.TryCopyXciHeaderKey(headerKey) ?? false;

        // Hashing reads every entry's full data (the bulk of the work) → parallel across entries,
        // each worker opens its own read stream; order preserved for the HFS0 layout.
        var files = new Hfs0File[entries.Count];
        int degree = NscbCore.Compression.Parallelizer.Clamp(parallelism, entries.Count);
        NscbCore.Compression.Parallelizer.ForIndex(entries.Count, degree, i =>
        {
            ct.ThrowIfCancellationRequested();
            var e = entries[i];
            files[i] = new Hfs0File { Name = e.BaseName, Size = e.Size, Hash = ComputeEntryHash(sourcePath, e) };
        }, ct);

        using FileStream output = File.Create(outputPath);
        XciBuilder.Build(
            output,
            files,
            file => OpenEntry(sourcePath, entries, file.Name),
            hasXciKey,
            hasXciKey ? headerKey : default,
            progress,
            ct);
    }

    /// <summary>
    /// Extracts the secure partition of an XCI/XCZ into an NSP/NSZ
    /// (NSCB semantics: update partition contents are not exported).
    /// </summary>
    public static void XciToNsp(string sourcePath, string outputPath,
        Action<long>? progress = null, CancellationToken ct = default, int parallelism = 1)
    {
        ContainerKind kind = ContainerReader.DetectKind(sourcePath);
        if (kind is not (ContainerKind.Xci or ContainerKind.Xcz))
            throw new InvalidDataException($"Expected an XCI/XCZ source, got: {sourcePath}");

        List<ContainerEntry> entries = ReadSourceEntries(sourcePath, kind)
            .Where(e => e.Name.StartsWith("secure/", StringComparison.OrdinalIgnoreCase))
            .ToList();
        if (entries.Count == 0)
            throw new InvalidDataException("XCI has no secure partition content.");

        // Write each secure entry to its own offset in the NSP concurrently (positional RandomAccess writes
        // are thread-safe). NSP data is laid out contiguously by size right after the header.
        byte[] header = Pfs0Builder.BuildHeader(entries.Select(e => (e.BaseName, e.Size)).ToList());
        long dataBase = header.Length;
        var outOff = new long[entries.Count];
        long acc = 0;
        for (int i = 0; i < entries.Count; i++) { outOff[i] = dataBase + acc; acc += entries[i].Size; }

        using var outFs = File.Create(outputPath);
        RandomAccess.Write(outFs.SafeFileHandle, header, 0);

        int degree = NscbCore.Compression.Parallelizer.Clamp(parallelism, entries.Count);
        NscbCore.Compression.Parallelizer.ForIndex(entries.Count, degree, i =>
        {
            var e = entries[i];
            ct.ThrowIfCancellationRequested();
            using var source = File.OpenRead(sourcePath);
            source.Position = e.Offset;
            byte[] buffer = new byte[0x80000];
            long done = 0;
            while (done < e.Size)
            {
                ct.ThrowIfCancellationRequested();
                int read = source.Read(buffer, 0, (int)Math.Min(buffer.Length, e.Size - done));
                if (read == 0) throw new EndOfStreamException($"Source ended early for {e.BaseName}.");
                RandomAccess.Write(outFs.SafeFileHandle, buffer.AsSpan(0, read), outOff[i] + done);
                done += read;
                progress?.Invoke(read);
            }
        }, ct);
    }

    private static List<ContainerEntry> ReadSourceEntries(string path, ContainerKind kind)
    {
        using FileStream fs = File.OpenRead(path);
        return ContainerReader.ReadEntries(fs, kind);
    }

    private static Stream OpenEntry(string sourcePath, List<ContainerEntry> entries, string name)
    {
        var entry = entries.First(e => e.BaseName.Equals(name, StringComparison.Ordinal));
        FileStream fs = File.OpenRead(sourcePath);
        fs.Position = entry.Offset;
        return fs;
    }

    private static byte[] ComputeEntryHash(string sourcePath, ContainerEntry entry)
    {
        using FileStream fs = File.OpenRead(sourcePath);
        fs.Position = entry.Offset;
        return Hfs0Builder.ComputeFileHash(fs, entry.Size);
    }
}
