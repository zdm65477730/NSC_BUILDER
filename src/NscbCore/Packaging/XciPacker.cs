using NscbCore.Formats;
using NscbCore.Keys;

namespace NscbCore.Packaging;

/// <summary>
/// Combine multiple NSP/XCI (or NSZ/XCZ) files into a single multi-content XCI.
/// All content entries are placed into the secure partition; existing update
/// partitions are ignored (NSCB behaviour for multi-pack).
/// </summary>
public static class XciPacker
{
    /// <summary>
    /// Pack all <paramref name="sourcePaths"/> into one XCI at <paramref name="outputPath"/>.
    /// Files may be NSP, XCI, NSZ, or XCZ; entries are copied without decompression.
    /// </summary>
    public static void Pack(
        IReadOnlyList<string> sourcePaths, string outputPath, NscbKeys? keys,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        if (sourcePaths.Count == 0)
            throw new ArgumentException("At least one source file is required.", nameof(sourcePaths));

        // NSCB multi-pack: ALL content entries from every source go into the SINGLE secure partition
        // (this is NSCB behaviour; the gamecard "update partition" is the retail SystemUpdate area, used
        // by trim, NOT where an app-update is packed). Installers (DBI/Tinfoil) read the secure partition
        // and enumerate every content meta present → base …2000 App + …800 Patch install as separate,
        // queryable titles. NCAs are copied verbatim → signatures stay valid (unlike the NSP upd_base fold).
        var secureFiles = new List<Hfs0File>();
        var sources  = new List<(string Path, ContainerEntry Entry)>();

        foreach (string src in sourcePaths)
        {
            ct.ThrowIfCancellationRequested();
            ContainerKind kind = ContainerReader.DetectKind(src);
            if (kind is not (ContainerKind.Nsp or ContainerKind.Nsz
                                  or ContainerKind.Xci  or ContainerKind.Xcz))
                throw new InvalidDataException($"Unsupported source format: {src}");

            List<ContainerEntry> entries;
            using (var probe = File.OpenRead(src))
                entries = ContainerReader.ReadEntries(probe, kind)
                    // XCI: take secure only; NSP: take all (no partition prefix)
                    .Where(e => e.Name.StartsWith("secure/", StringComparison.OrdinalIgnoreCase)
                             || kind is ContainerKind.Nsp or ContainerKind.Nsz)
                    .ToList();

            foreach (var e in entries)
            {
                string baseName = Path.GetFileName(e.Name); // strip "secure/" for XCI entries
                byte[] hash;
                using (var s = File.OpenRead(src))
                {
                    s.Position = e.Offset;
                    hash = Hfs0Builder.ComputeFileHash(s, e.Size);
                }
                secureFiles.Add(new Hfs0File { Name = baseName, Size = e.Size, Hash = hash });
                sources.Add((src, e with { Name = baseName }));
            }
        }

        if (secureFiles.Count == 0)
            throw new InvalidOperationException("No content entries found in the provided sources.");

        // Build lookup: baseName → (sourcePath, offset, size).
        var lookup = new Dictionary<string, (string Path, long Offset, long Size)>();
        foreach (var (path, entry) in sources)
        {
            // Later entries override (duplicate names from different sources: last wins).
            lookup[entry.BaseName] = (path, entry.Offset, entry.Size);
        }

        Span<byte> xciKey = stackalloc byte[0x10];
        bool hasKey = keys?.TryCopyXciHeaderKey(xciKey) ?? false;

        using var output = File.Create(outputPath);
        XciBuilder.Build(
            output,
            secureFiles,
            file =>
            {
                var (srcPath, offset, size) = lookup[file.Name];
                var fs = File.OpenRead(srcPath);
                fs.Position = offset;
                return fs;
            },
            hasKey,
            hasKey ? xciKey : default,
            progress,
            ct);
    }

    /// <summary>
    /// Pack all files in a folder into one XCI.
    /// </summary>
    public static void PackFolder(
        string folderPath, string outputPath, NscbKeys? keys,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        string[] files;
        try { files = Directory.GetFiles(folderPath, "*", System.IO.SearchOption.AllDirectories); }   // include subfolders
        catch { files = Directory.GetFiles(folderPath); }                                              // inaccessible dir → top-level
        string[] supported = files
            .Where(f =>
            {
                string ext = Path.GetExtension(f).ToLowerInvariant();
                return ext is ".nsp" or ".nsz" or ".xci" or ".xcz";
            })
            .OrderBy(f => f)
            .ToArray();

        if (supported.Length == 0)
            throw new InvalidOperationException($"No NSP/NSZ/XCI/XCZ files found in: {folderPath}");

        Pack(supported, outputPath, keys, progress, ct);
    }
}
