namespace NscbCore.Splitting;

/// <summary>
/// FAT32-compatible file splitting and merging.
/// Files larger than 4 GiB − 32 KiB (4294934528 bytes) are split into
/// sequentially-numbered parts: filename.00, filename.01, …
/// Matches NSCB's split block size exactly.
/// </summary>
public static class Fat32Splitter
{
    /// <summary>NSCB / Tinfoil maximum FAT32 part size in bytes (4 GiB − 0x8000).</summary>
    public const long BlockSize = 4294934528;

    /// <summary>
    /// Split <paramref name="inputPath"/> into <c>.00/.01/…</c> parts alongside it.
    /// Returns the number of parts written.
    /// If the file fits in one block, the original is renamed to <c>.00</c>.
    /// </summary>
    public static int Split(string inputPath, Action<long>? progress = null, CancellationToken ct = default)
    {
        long fileSize = new FileInfo(inputPath).Length;
        int partCount = (int)Math.Ceiling((double)fileSize / BlockSize);
        if (partCount == 0) partCount = 1;

        using var src = File.OpenRead(inputPath);
        byte[] buf = new byte[Math.Min(0x80000, BlockSize)];

        for (int i = 0; i < partCount; i++)
        {
            ct.ThrowIfCancellationRequested();
            string partPath = PartPath(inputPath, i);
            using var dst = File.Create(partPath);
            long remaining = Math.Min(BlockSize, fileSize - (long)i * BlockSize);
            while (remaining > 0)
            {
                int read = src.Read(buf, 0, (int)Math.Min(buf.Length, remaining));
                if (read == 0) break;
                dst.Write(buf, 0, read);
                remaining -= read;
                progress?.Invoke(read);
            }
        }
        return partCount;
    }

    /// <summary>
    /// Merge parts of <paramref name="basePath"/> (detected by <c>.00/.01/…</c>)
    /// into a single output file. Returns true when at least one part was found.
    /// </summary>
    public static bool Merge(string basePath, string outputPath,
        Action<long>? progress = null, CancellationToken ct = default)
    {
        // If basePath itself IS the .00 part, derive base from it.
        string probe = basePath.EndsWith(".00") ? basePath[..^3] : basePath;

        int i = 0;
        using var outFs = File.Create(outputPath);
        byte[] buf = new byte[0x80000];

        while (true)
        {
            ct.ThrowIfCancellationRequested();
            string partPath = i == 0 ? probe + ".00" : PartPath(probe, i);
            if (!File.Exists(partPath)) break;

            using var part = File.OpenRead(partPath);
            int read;
            while ((read = part.Read(buf, 0, buf.Length)) > 0)
            {
                outFs.Write(buf, 0, read);
                progress?.Invoke(read);
            }
            i++;
        }

        return i > 0;
    }

    /// <summary>Returns true when <paramref name="path"/> looks like a FAT32 split part (ends with .00/.01/…).</summary>
    public static bool IsSplitPart(string path)
    {
        string ext = Path.GetExtension(path);
        return ext.Length == 3 && ext[1] is >= '0' and <= '9' && ext[2] is >= '0' and <= '9';
    }

    /// <summary>Reconstruct the merged file path from a .00 part path.</summary>
    public static string MergedPathFromPart(string partPath)
        => partPath.EndsWith(".00") ? partPath[..^3] : partPath;

    private static string PartPath(string basePath, int index)
        => $"{basePath}.{index:D2}";
}
