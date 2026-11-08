using System.Buffers.Binary;

namespace NscbCore.Formats;

public enum ContainerKind
{
    Unknown,
    Nsp,
    Nsz,
    Xci,
    Xcz,
    Nca,
    Ncz,
}

/// <summary>A content entry inside a container, with its absolute offset in the backing file.</summary>
public sealed record ContainerEntry(
    string Name,
    long Offset,
    long Size,
    bool IsCompressed)
{
    public string BaseName => Path.GetFileName(Name);
    public bool IsNca => !IsCompressed && BaseName.EndsWith(".nca", StringComparison.OrdinalIgnoreCase);
    public bool IsNcz => IsCompressed && BaseName.EndsWith(".ncz", StringComparison.OrdinalIgnoreCase);
    public bool IsTicket => BaseName.EndsWith(".tik", StringComparison.OrdinalIgnoreCase);
    public bool IsCert => BaseName.EndsWith(".cert", StringComparison.OrdinalIgnoreCase);
    public bool IsXml => BaseName.EndsWith(".xml", StringComparison.OrdinalIgnoreCase);
    public bool IsHtml => BaseName.EndsWith(".html", StringComparison.OrdinalIgnoreCase);
    public bool IsJpg => BaseName.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase);
}

/// <summary>
/// Unified read-only view over NSP/NSZ/XCI/XCZ containers:
/// enumerates content entries (NCA/NCZ/tik/...) with absolute offsets.
/// </summary>
public static class ContainerReader
{
    public static ContainerKind DetectKind(string path)
    {
        string ext = Path.GetExtension(path).ToLowerInvariant();
        return ext switch
        {
            ".nsp" => ContainerKind.Nsp,
            ".nsz" => ContainerKind.Nsz,
            ".xci" => ContainerKind.Xci,
            ".xcz" => ContainerKind.Xcz,
            ".nca" => ContainerKind.Nca,
            ".ncz" => ContainerKind.Ncz,
            _ => ContainerKind.Unknown,
        };
    }

    /// <summary>Lists content entries of a container file. Throws for unknown formats.</summary>
    public static List<ContainerEntry> ReadEntries(Stream stream, ContainerKind kind)
    {
        switch (kind)
        {
            case ContainerKind.Nsp or ContainerKind.Nsz:
            {
                return Pfs0.ReadEntries(stream)
                    .Select(e => new ContainerEntry(e.Name, e.DataOffset, e.Size, e.IsNcz))
                    .ToList();
            }
            case ContainerKind.Xci or ContainerKind.Xcz:
            {
                var result = new List<ContainerEntry>();
                long rootDataStart = GetRootDataStart(stream);

                foreach (var part in Hfs0.ReadEntries(stream, XciLayout.RootHfs0Offset))
                {
                    // Only the secure partition carries installable content; the
                    // update partition may hold system update NCAs - include both.
                    if (part.Name.Equals("normal", StringComparison.OrdinalIgnoreCase)
                        || part.Name.Equals("logo", StringComparison.OrdinalIgnoreCase))
                        continue;
                    if (part.Size == 0)
                        continue;

                    foreach (var e in Hfs0.ReadEntries(stream, part.DataOffset))
                    {
                        result.Add(new ContainerEntry(
                            $"{part.Name}/{e.Name}",
                            e.DataOffset,
                            e.Size,
                            e.Name.EndsWith(".ncz", StringComparison.OrdinalIgnoreCase)));
                    }
                }

                _ = rootDataStart;
                return result;
            }
            case ContainerKind.Nca or ContainerKind.Ncz:
            {
                return
                [
                    new ContainerEntry(Path.GetFileName("file.nca"), 0, stream.Length,
                        kind == ContainerKind.Ncz),
                ];
            }
            default:
                throw new InvalidDataException($"Unsupported container kind: {kind}");
        }
    }

    /// <summary>Offset where the root HFS0 string/data starts (for partition offset resolution).</summary>
    private static long GetRootDataStart(Stream stream)
    {
        stream.Position = XciLayout.RootHfs0Offset;
        Span<byte> header = stackalloc byte[0x10];
        stream.ReadExactly(header);
        int fileCount = BinaryPrimitives.ReadInt32LittleEndian(header[4..]);
        int stringTableSize = BinaryPrimitives.ReadInt32LittleEndian(header[8..]);
        return XciLayout.RootHfs0Offset + 0x10 + Hfs0.EntrySize * fileCount + stringTableSize;
    }
}
