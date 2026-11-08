using System.IO.Compression;
using NscbCore.Splitting;
using IOPath = System.IO.Path;

namespace NscbCore.Joiner;

/// <summary>
/// Re-joins files that were split or archived for transport:
/// FAT32 <c>.00/.01/…</c> parts (via <see cref="Fat32Splitter"/>) and
/// <c>.zip</c> archives holding a single game container.
/// Corresponds to NSCB's JOINER ("--joiner") mode.
/// </summary>
public static class FileJoiner
{
    /// <summary>
    /// Join <paramref name="inputPath"/> (a <c>.00</c> split part or a <c>.zip</c>).
    /// When <paramref name="outputPath"/> is null a sensible default next to the input is used.
    /// Returns the produced file (or directory) path.
    /// </summary>
    public static string Join(string inputPath, string? outputPath = null, CancellationToken ct = default)
    {
        if (!File.Exists(inputPath))
            throw new FileNotFoundException("Input not found.", inputPath);

        string ext = IOPath.GetExtension(inputPath).ToLowerInvariant();

        if (ext == ".zip")
            return Unzip(inputPath, outputPath, ct);

        if (Fat32Splitter.IsSplitPart(inputPath))
        {
            string merged = outputPath ?? Fat32Splitter.MergedPathFromPart(inputPath);
            if (!Fat32Splitter.Merge(inputPath, merged, null, ct))
                throw new InvalidDataException($"No FAT32 parts found for: {inputPath}");
            return merged;
        }

        throw new InvalidDataException($"Not a joinable input (.zip or .00/.01… parts): {inputPath}");
    }

    /// <summary>
    /// Extract a <c>.zip</c>. If <paramref name="outputPath"/> names a file, the archive's
    /// single entry is written there; otherwise everything is unpacked into a directory
    /// (named after <paramref name="outputPath"/> or the zip). Returns the output path.
    /// </summary>
    private static string Unzip(string zipPath, string? outputPath, CancellationToken ct)
    {
        using var archive = ZipFile.OpenRead(zipPath);

        // A single-entry archive joins directly to a file (typical NSC_BUILDER ".xcz.zip" split transport).
        if (archive.Entries.Count == 1 && outputPath is not null && !Directory.Exists(outputPath))
        {
            ZipFile.ExtractToDirectory(zipPath, EnsureTempDir(out string tmp));
            string extracted = IOPath.Combine(tmp, archive.Entries[0].Name);
            Directory.CreateDirectory(IOPath.GetDirectoryName(outputPath)!);
            File.Move(extracted, outputPath, overwrite: true);
            TryDeleteDir(tmp);
            return outputPath;
        }

        string outDir = outputPath ?? (IOPath.Combine(IOPath.GetDirectoryName(zipPath) ?? ".",
            IOPath.GetFileNameWithoutExtension(zipPath)));
        if (File.Exists(outDir))
            throw new InvalidDataException($"Output path is an existing file: {outDir}");

        Directory.CreateDirectory(outDir);
        foreach (var entry in archive.Entries)
        {
            ct.ThrowIfCancellationRequested();
            // Skip directory placeholder entries; flatten to the archive root names.
            if (entry.Name.Length == 0) continue;
            string dst = IOPath.Combine(outDir, entry.Name);
            entry.ExtractToFile(dst, overwrite: true);
        }
        return outDir;
    }

    private static string EnsureTempDir(out string dir)
    {
        dir = IOPath.Combine(IOPath.GetTempPath(), $"nscb-join-{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        return dir;
    }

    private static void TryDeleteDir(string dir)
    {
        try { Directory.Delete(dir, recursive: true); } catch { /* best effort */ }
    }
}
