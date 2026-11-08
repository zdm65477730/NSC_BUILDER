using System.Buffers.Binary;
using System.Security.Cryptography;
using System.Text;

namespace NscbCore.Formats;

/// <summary>A file to be placed inside an HFS0 partition.</summary>
public sealed class Hfs0File
{
    public required string Name { get; init; }
    public required long Size { get; init; }

    /// <summary>
    /// SHA-256 over the first <see cref="HashedSize"/> bytes of the file data
    /// (matching NSCB: the first 0x200 bytes, or the whole file when smaller).
    /// </summary>
    public required byte[] Hash { get; init; }

    public int HashedSize { get; init; } = 0x200;
}

/// <summary>A serialized HFS0 partition header plus the total size of the data that follows it.</summary>
public sealed class Hfs0Partition
{
    public Hfs0Partition(string name, byte[] header, long dataSize)
    {
        Name = name;
        Header = header;
        DataSize = dataSize;
    }

    public string Name { get; }
    public byte[] Header { get; }
    public long DataSize { get; }
    public long TotalSize => Header.Length + DataSize;
}

/// <summary>
/// Builds HFS0 partition and root headers, mirroring NSCB's <c>gen_rhfs0_head</c>:
/// entries carry a hashed-prefix size and SHA-256, the string table is NUL separated
/// (no trailing NUL - the sector padding provides it) and the whole header is padded
/// to a 0x200 sector boundary. Root entries hash the whole partition header.
/// </summary>
public static class Hfs0Builder
{
    public const int HeaderSize = 0x10;
    public const int EntrySize = 0x40;
    public const int SectorSize = 0x200;

    /// <summary>Computes the HFS0 entry hash for a data stream: SHA-256 of its first 0x200 bytes.</summary>
    public static byte[] ComputeFileHash(Stream data, long size)
    {
        int prefix = (int)Math.Min(0x200, size);
        byte[] buf = new byte[prefix];
        long restore = data.Position;
        data.Position = 0;
        data.ReadExactly(buf, 0, prefix);
        data.Position = restore;
        return SHA256.HashData(buf);
    }

    /// <summary>Builds one HFS0 partition header, padded to a 0x200 sector boundary.</summary>
    public static byte[] BuildPartitionHeader(IReadOnlyList<Hfs0File> files)
    {
        string[] names = files.Select(f => f.Name).ToArray();
        return BuildHeaderBuffer(names, index =>
        {
            var f = files[index];
            long offset = 0;
            for (int i = 0; i < index; i++)
                offset += files[i].Size;
            return (offset, f.Size, f.HashedSize, f.Hash);
        });
    }

    /// <summary>
    /// Builds the root HFS0 header over the given partitions in order (update, normal, secure).
    /// Each root entry treats the partition header as the hashed prefix of its "file",
    /// matching NSCB's hashed layout.
    /// </summary>
    public static byte[] BuildRootHeader(IReadOnlyList<Hfs0Partition> partitions)
    {
        string[] names = partitions.Select(p => p.Name).ToArray();
        return BuildHeaderBuffer(names, index =>
        {
            var p = partitions[index];
            long offset = 0;
            for (int i = 0; i < index; i++)
                offset += partitions[i].TotalSize;
            return (offset, p.TotalSize, p.Header.Length, SHA256.HashData(p.Header));
        });
    }

    private static byte[] BuildHeaderBuffer(string[] names,
        Func<int, (long Offset, long Size, int HashedSize, byte[] Hash)> entryAt)
    {
        int fileCount = names.Length;
        string stringTable = string.Join("\0", names);
        int nameTableBytes = Encoding.ASCII.GetByteCount(stringTable);
        int headerLength = HeaderSize + fileCount * EntrySize + nameTableBytes;
        int paddedLength = RoundUp(headerLength, SectorSize);
        int remainder = paddedLength - headerLength;

        var buffer = new byte[paddedLength];
        BinaryPrimitives.WriteUInt32LittleEndian(buffer, Hfs0.Magic);
        BinaryPrimitives.WriteInt32LittleEndian(buffer.AsSpan(4), fileCount);
        // NSCB writes the string table size including the padding remainder.
        BinaryPrimitives.WriteInt32LittleEndian(buffer.AsSpan(8), nameTableBytes + remainder);
        // bytes 0x0C..0x10 stay zero.

        int nameOffset = 0;
        int nameTableStart = HeaderSize + fileCount * EntrySize;
        for (int i = 0; i < fileCount; i++)
        {
            var (offset, size, hashedSize, hash) = entryAt(i);
            int e = HeaderSize + i * EntrySize;
            BinaryPrimitives.WriteInt64LittleEndian(buffer.AsSpan(e, 8), offset);
            BinaryPrimitives.WriteInt64LittleEndian(buffer.AsSpan(e + 8, 8), size);
            BinaryPrimitives.WriteInt32LittleEndian(buffer.AsSpan(e + 0x10, 4), nameOffset);
            BinaryPrimitives.WriteInt32LittleEndian(buffer.AsSpan(e + 0x14, 4), hashedSize);
            // e+0x18..0x20 reserved zeros.
            hash.AsSpan(0, Math.Min(0x20, hash.Length)).CopyTo(buffer.AsSpan(e + 0x20, 0x20));

            nameOffset += Encoding.ASCII.GetByteCount(names[i]) + 1;
        }

        Encoding.ASCII.GetBytes(stringTable, buffer.AsSpan(nameTableStart));
        // Padding up to the sector boundary is already zero.
        return buffer;
    }

    private static int RoundUp(int value, int alignment)
        => (value + alignment - 1) / alignment * alignment;
}
