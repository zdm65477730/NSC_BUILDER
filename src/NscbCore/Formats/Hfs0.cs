using System.Buffers.Binary;
using System.Text;

namespace NscbCore.Formats;

/// <summary>Entry of an HFS0 container (XCI partitions).</summary>
public readonly record struct Hfs0Entry(
    string Name,
    long DataOffset,
    long Size,
    int HashedSize,
    byte[] Hash);

/// <summary>
/// Read-only parser for the HFS0 container used by XCI partitions
/// (magic "HFS0", 0x40 byte entries with SHA-256 hashes, trailing string table).
/// </summary>
public static class Hfs0
{
    public const uint Magic = 0x30534648; // "HFS0"
    public const int EntrySize = 0x40;

    public static bool IsHfs0(ReadOnlySpan<byte> header)
        => header.Length >= 4 && BinaryPrimitives.ReadUInt32LittleEndian(header) == Magic;

    public static List<Hfs0Entry> ReadEntries(Stream stream, long baseOffset = 0)
    {
        Span<byte> header = stackalloc byte[0x10];
        stream.Position = baseOffset;
        if (stream.Read(header) != header.Length)
            throw new InvalidDataException("Truncated HFS0 header");

        if (BinaryPrimitives.ReadUInt32LittleEndian(header) != Magic)
            throw new InvalidDataException("Not an HFS0 container");

        int fileCount = BinaryPrimitives.ReadInt32LittleEndian(header[4..]);
        int stringTableSize = BinaryPrimitives.ReadInt32LittleEndian(header[8..]);
        if (fileCount < 0 || stringTableSize < 0 || fileCount > 4096)
            throw new InvalidDataException("Invalid HFS0 header values");

        int entriesSize = EntrySize * fileCount;
        byte[] table = new byte[entriesSize + stringTableSize];
        if (stream.Read(table) != table.Length)
            throw new InvalidDataException("Truncated HFS0 entry/string table");

        long dataStart = baseOffset + 0x10 + table.Length;

        var entries = new List<Hfs0Entry>(fileCount);
        for (int i = 0; i < fileCount; i++)
        {
            int e = i * EntrySize;
            long offset = BinaryPrimitives.ReadInt64LittleEndian(table.AsSpan(e, 8));
            long size = BinaryPrimitives.ReadInt64LittleEndian(table.AsSpan(e + 8, 8));
            int nameOffset = BinaryPrimitives.ReadInt32LittleEndian(table.AsSpan(e + 0x10, 4));
            int hashedSize = BinaryPrimitives.ReadInt32LittleEndian(table.AsSpan(e + 0x14, 4));
            byte[] hash = table[(e + 0x20)..(e + 0x40)];

            string name = ReadCString(table, entriesSize + nameOffset);
            entries.Add(new Hfs0Entry(name, dataStart + offset, size, hashedSize, hash));
        }

        return entries;
    }

    private static string ReadCString(byte[] table, int start)
    {
        if (start < 0 || start >= table.Length)
            return string.Empty;
        int end = Array.IndexOf(table, (byte)0, start);
        if (end < 0)
            end = table.Length;
        return Encoding.ASCII.GetString(table, start, end - start);
    }
}
